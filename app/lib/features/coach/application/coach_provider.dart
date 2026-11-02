import 'package:app_flutter/core/network/ai_error.dart';
import 'package:app_flutter/core/network/api_exception.dart';
import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/features/coach/data/coach_agent.dart';
import 'package:app_flutter/features/coach/data/coach_repository.dart';
import 'package:app_flutter/features/coach/data/coach_rest.dart';
import 'package:app_flutter/features/coach/data/next_exercise_recommender.dart';
import 'package:app_flutter/features/coach/domain/coach_proposal.dart';
import 'package:app_flutter/features/coach/domain/coach_thought.dart';
import 'package:app_flutter/features/coach/domain/coach_thread.dart';
import 'package:app_flutter/features/profile/data/repositories/profile_repository.dart';
import 'package:app_flutter/features/settings/application/providers/ai_settings_provider.dart';
import 'package:app_flutter/features/settings/domain/entities/ai_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final coachRepositoryProvider = Provider<CoachRepository>((ref) => CoachRepository(ref.watch(dioProvider)));

/// 工具请求走全局 Dio（App JWT），与 AI 请求的独立客户端分开。
final coachRestProvider = Provider<CoachRestApi>((ref) => CoachRest(ref.watch(dioProvider)));

/// 训练页「建议」：按本场肌群和最近训练选下一个动作。
final nextExerciseRecommenderProvider = Provider<NextExerciseRecommender>(
  (ref) => NextExerciseRecommender(ref.watch(dioProvider)),
);

/// 未配置 Key 时抛 [AiNotConfiguredException]，由页面引导去设置。
final coachAgentProvider = FutureProvider<CoachAgent>((ref) async {
  final settings = await ref.watch(aiSettingsProvider.future);
  final apiKey = await ref.watch(aiSettingsRepositoryProvider).readApiKey();
  if (apiKey == null) throw const AiNotConfiguredException();
  final agent = CoachAgent(
    settings: settings,
    apiKey: apiKey,
    rest: ref.watch(coachRestProvider),
  );
  ref.onDispose(agent.close);
  return agent;
});

enum CoachSpeaker { user, assistant }

class CoachChatMessage {
  const CoachChatMessage({
    required this.speaker,
    required this.text,
    this.thoughts = const [],
    this.proposal,
  });

  final CoachSpeaker speaker;
  final String text;
  final List<CoachThoughtStep> thoughts;
  final CoachProposal? proposal;
}

class CoachState {
  const CoachState({
    this.threadId,
    this.threads = const [],
    this.messages = const [],
    this.liveThoughts = const [],
    this.liveReply = '',
    this.status = '',
    this.proposal,
    this.sending = false,
    this.loadingHistory = false,
    this.needsProfile = false,
    this.error,
  });

  final int? threadId;
  final List<CoachThreadSummary> threads;
  final List<CoachChatMessage> messages;
  final List<CoachThoughtStep> liveThoughts;

  /// 正在生成的回复。模型每吐出一段就变长，结束后清空。
  final String liveReply;
  final String status;
  final CoachProposal? proposal;
  final bool sending;
  final bool loadingHistory;
  final bool needsProfile;
  final String? error;

  CoachState copyWith({
    int? threadId,
    bool clearThread = false,
    List<CoachThreadSummary>? threads,
    List<CoachChatMessage>? messages,
    List<CoachThoughtStep>? liveThoughts,
    String? liveReply,
    String? status,
    CoachProposal? proposal,
    bool clearProposal = false,
    bool? sending,
    bool? loadingHistory,
    bool? needsProfile,
    String? error,
    bool clearError = false,
  }) {
    return CoachState(
      threadId: clearThread ? null : threadId ?? this.threadId,
      threads: threads ?? this.threads,
      messages: messages ?? this.messages,
      liveThoughts: liveThoughts ?? this.liveThoughts,
      liveReply: liveReply ?? this.liveReply,
      status: status ?? this.status,
      proposal: clearProposal ? null : proposal ?? this.proposal,
      sending: sending ?? this.sending,
      loadingHistory: loadingHistory ?? this.loadingHistory,
      needsProfile: needsProfile ?? this.needsProfile,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class CoachController extends Notifier<CoachState> {
  @override
  CoachState build() => const CoachState();

  /// 打开页面时只恢复最近一段对话，不自动向模型发请求。
  Future<void> open() async {
    if (state.loadingHistory || state.threadId != null || state.messages.isNotEmpty) return;
    state = state.copyWith(loadingHistory: true, clearError: true);
    try {
      final threads = await ref.read(coachRepositoryProvider).listThreads();
      state = state.copyWith(threads: threads, loadingHistory: false);
      if (threads.isNotEmpty) await selectThread(threads.first.id);
    } catch (error) {
      state = state.copyWith(loadingHistory: false, error: _message(error));
    }
  }

  Future<void> refreshThreads() async {
    final threads = await ref.read(coachRepositoryProvider).listThreads();
    state = state.copyWith(threads: threads);
  }

  Future<void> newChat() async {
    state = state.copyWith(
      clearThread: true,
      messages: const [],
      clearProposal: true,
      status: '',
      liveReply: '',
      needsProfile: false,
      clearError: true,
    );
  }

  Future<void> selectThread(int id) async {
    state = state.copyWith(loadingHistory: true, clearError: true, needsProfile: false);
    try {
      final detail = await ref.read(coachRepositoryProvider).fetchThread(id);
      state = state.copyWith(
        threadId: detail.id,
        messages: [
          for (final message in detail.messages)
            if (message.text.isNotEmpty)
              CoachChatMessage(
                speaker: message.role == 'user' ? CoachSpeaker.user : CoachSpeaker.assistant,
                text: message.text,
                thoughts: message.trace,
                proposal: message.proposal,
              ),
        ],
        proposal: detail.proposal,
        clearProposal: detail.proposal == null,
        loadingHistory: false,
        status: '',
      );
    } catch (error) {
      state = state.copyWith(loadingHistory: false, error: _message(error));
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;
    final CoachAgent agent;
    try {
      agent = await ref.read(coachAgentProvider.future);
    } on AiNotConfiguredException {
      state = state.copyWith(error: '请先在设置里填写 AI API Key');
      return;
    } catch (error) {
      state = state.copyWith(error: _message(error));
      return;
    }

    try {
      final profile = await ref.read(fitnessProfileRepositoryProvider).fetch();
      if (profile == null) {
        state = state.copyWith(needsProfile: true, clearError: true);
        return;
      }
    } catch (error) {
      state = state.copyWith(error: _message(error));
      return;
    }

    final history = [
      for (final message in state.messages)
        if (message.text.trim().isNotEmpty)
          {
            'role': message.speaker == CoachSpeaker.user ? 'user' : 'assistant',
            'content': message.text,
          },
    ];
    state = state.copyWith(
      messages: [...state.messages, CoachChatMessage(speaker: CoachSpeaker.user, text: trimmed)],
      sending: true,
      status: '思考中',
      liveThoughts: const [],
      liveReply: '',
      needsProfile: false,
      clearError: true,
    );

    try {
      final repo = ref.read(coachRepositoryProvider);
      var threadId = state.threadId;
      if (threadId == null) {
        threadId = await repo.createThread();
        state = state.copyWith(threadId: threadId);
      }
      final turn = await agent.run(
        history: history,
        userText: trimmed,
        onThought: (step) {
          state = state.copyWith(liveThoughts: mergeThought(state.liveThoughts, step), status: step.title);
        },
        onText: (text) {
          state = state.copyWith(liveReply: text);
        },
      );
      final thoughts = turn.thoughts.isEmpty ? state.liveThoughts : turn.thoughts;
      final replyText = turn.messages.isEmpty ? (turn.error ?? '这次没排出来，稍后再试') : turn.messages.first;
      state = state.copyWith(
        sending: false,
        status: '',
        liveThoughts: const [],
        liveReply: '',
        messages: [
          ...state.messages,
          CoachChatMessage(
            speaker: CoachSpeaker.assistant,
            text: replyText,
            thoughts: thoughts,
            proposal: turn.proposal,
          ),
        ],
        proposal: turn.proposal,
        clearProposal: turn.proposal == null,
        clearError: turn.error == null,
        error: turn.error,
      );
      try {
        await repo.importTurn(
          threadId: threadId,
          userContent: trimmed,
          assistantContent: replyText,
          proposal: turn.proposal,
          trace: thoughts,
        );
      } catch (_) {
        // 导入失败只影响服务端历史，不打断当前对话；不重试，避免重复消息。
      }
      try {
        await refreshThreads();
      } catch (_) {}
    } on ConflictException {
      state = state.copyWith(sending: false, needsProfile: true, status: '', liveThoughts: const [], liveReply: '');
    } catch (error) {
      state = state.copyWith(sending: false, status: '', liveThoughts: const [], liveReply: '', error: _message(error));
    }
  }

  String _message(Object error) {
    if (error is AiNotConfiguredException) return '请先在设置里填写 AI API Key';
    if (error is ApiException && error.message.isNotEmpty) return error.message;
    return aiErrorMessage(error);
  }
}

final coachControllerProvider = NotifierProvider<CoachController, CoachState>(CoachController.new);
