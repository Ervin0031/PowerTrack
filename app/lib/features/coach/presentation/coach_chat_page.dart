import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/features/coach/application/coach_provider.dart';
import 'package:app_flutter/features/coach/domain/coach_intent.dart';
import 'package:app_flutter/features/coach/domain/coach_proposal.dart';
import 'package:app_flutter/features/coach/presentation/widgets/coach_assistant_turn.dart';
import 'package:app_flutter/features/coach/presentation/widgets/coach_chat_status.dart';
import 'package:app_flutter/features/coach/presentation/widgets/coach_composer.dart';
import 'package:app_flutter/features/coach/presentation/widgets/coach_history_drawer.dart';
import 'package:app_flutter/features/coach/presentation/widgets/coach_user_message.dart';
import 'package:app_flutter/features/settings/application/providers/ai_settings_provider.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/entities/training_set_kind.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 底部导航进入的教练聊天页。
///
/// 消息、输入条和历史抽屉都在 `presentation/widgets/`。这一页只负责滚动、发送和开练。
class CoachChatPage extends ConsumerStatefulWidget {
  const CoachChatPage({super.key});

  @override
  ConsumerState<CoachChatPage> createState() => _CoachChatPageState();
}

class _CoachChatPageState extends ConsumerState<CoachChatPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _composerKey = GlobalKey();
  final _typingKey = GlobalKey();
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  var _starting = false;
  var _hasText = false;
  var _holdTyping = false;
  var _composerHeight = 128.0;

  @override
  void initState() {
    super.initState();
    _draft.addListener(() {
      final next = _draft.text.trim().isNotEmpty;
      if (next != _hasText) setState(() => _hasText = next);
    });
    Future.microtask(() => ref.read(coachControllerProvider.notifier).open());
  }

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coach = ref.watch(coachControllerProvider);
    final aiConfigured = ref.watch(aiSettingsProvider).valueOrNull?.hasKey ?? true;

    ref.listen(coachControllerProvider, (previous, next) {
      final finished =
          previous?.sending == true && !next.sending && next.messages.length > (previous?.messages.length ?? 0);
      if (finished) _holdTyping = true;
      if (next.messages.isEmpty || previous?.threadId != next.threadId) _holdTyping = false;
      final replyGrew = next.liveReply != previous?.liveReply;
      if (previous?.messages.length == next.messages.length &&
          previous?.proposal == next.proposal &&
          previous?.liveThoughts.length == next.liveThoughts.length &&
          !replyGrew &&
          !finished) {
        return;
      }
      if (replyGrew && next.sending) {
        _stickToEnd();
      } else {
        _scrollToEnd();
      }
    });

    final isEmpty = coach.messages.isEmpty && !coach.sending && !coach.loadingHistory;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncComposerHeight());

    return Scaffold(
      key: _scaffoldKey,
      drawer: CoachHistoryDrawer(
        threads: coach.threads,
        selectedId: coach.threadId,
        onNew: () {
          Navigator.of(context).pop();
          ref.read(coachControllerProvider.notifier).newChat();
        },
        onSelect: (id) {
          Navigator.of(context).pop();
          ref.read(coachControllerProvider.notifier).selectThread(id);
        },
      ),
      appBar: GlassAppBar(
        automaticallyImplyLeading: false,
        leading: M3EButton(
          tooltip: '对话',
          style: M3EButtonStyle.text,
          size: .sm,
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          child: const Icon(Symbols.menu_rounded),
        ),
        title: Text('教练', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: true,
        actions: [
          if (coach.messages.isNotEmpty)
            M3EButton(
              tooltip: '新对话',
              style: M3EButtonStyle.text,
              size: .sm,
              onPressed: () => ref.read(coachControllerProvider.notifier).newChat(),
              child: const Icon(Symbols.edit_square_rounded),
            ),
          M3EButton(
            tooltip: '关闭',
            style: M3EButtonStyle.text,
            size: .sm,
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(Symbols.close_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(20, 8, 20, _composerHeight + 12),
              children: [
                if (!aiConfigured) CoachAiSetupPrompt(onSetup: () => context.push(AppRoutes.aiSettings)),
                if (coach.needsProfile) CoachProfilePrompt(onFill: () => context.push(AppRoutes.fitnessProfile)),
                if (isEmpty && aiConfigured)
                  CoachEmptyHint(
                    onSuggest: !coach.needsProfile
                        ? (text) => ref.read(coachControllerProvider.notifier).send(text)
                        : null,
                  ),
                for (var i = 0; i < coach.messages.length; i++)
                  if (coach.messages[i].speaker == CoachSpeaker.user)
                    CoachUserMessage(text: coach.messages[i].text)
                  else
                    CoachAssistantTurn(
                      text: coach.messages[i].text,
                      thoughts: coach.messages[i].thoughts,
                      intent: _intentBefore(coach.messages, i),
                      proposal: coach.messages[i].proposal,
                      startingProposal: _starting,
                      markdownKey: _holdTyping && i == coach.messages.length - 1 ? _typingKey : null,
                      onReveal: _holdTyping && i == coach.messages.length - 1 ? _stickToEnd : null,
                      onRevealSettled: _holdTyping && i == coach.messages.length - 1 ? _releaseTyping : null,
                      onStartProposal: coach.messages[i].proposal == null
                          ? null
                          : () => _start(coach.messages[i].proposal!),
                    ),
                if (coach.sending)
                  CoachAssistantTurn(
                    text: coach.liveReply,
                    thoughts: coach.liveThoughts,
                    intent: _intentBefore(coach.messages, coach.messages.length),
                    live: true,
                    markdownKey: _typingKey,
                    onReveal: _stickToEnd,
                  ),
                if (coach.error != null && !coach.sending) CoachErrorLine(message: coach.error!),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CoachComposer(
              key: _composerKey,
              controller: _draft,
              enabled: aiConfigured && !coach.sending && !coach.needsProfile,
              canSend: _hasText && aiConfigured && !coach.sending,
              onSend: () => _send(_draft.text),
            ),
          ),
        ],
      ),
    );
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _draft.clear();
    FocusScope.of(context).unfocus();
    ref.read(coachControllerProvider.notifier).send(trimmed);
    _scrollToEnd();
  }

  void _syncComposerHeight() {
    final box = _composerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    final next = box.size.height;
    if ((next - _composerHeight).abs() < 1) return;
    setState(() => _composerHeight = next);
  }

  void _releaseTyping() {
    if (!_holdTyping || !mounted) return;
    setState(() => _holdTyping = false);
  }

  /// 人还停在底部时跟着新打出来的字走。已经往上翻过就不动。
  void _stickToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.maxScrollExtent - position.pixels > 120) return;
      if ((position.maxScrollExtent - position.pixels).abs() < 1) return;
      position.jumpTo(position.maxScrollExtent);
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _start(CoachProposal proposal) async {
    setState(() => _starting = true);
    final ok = await ref.read(trainingSessionProvider.notifier).startWithPlan(_exercises(proposal));
    if (!mounted) return;
    setState(() => _starting = false);
    if (!ok) {
      final err = ref.read(trainingSessionProvider).error;
      showExpressiveSnack(
        context: context,
        message: err == null ? '没能开始这场训练' : userFacingErrorMessage(err),
        icon: Symbols.error_outline_rounded,
      );
      return;
    }
    context.push(AppRoutes.trainingSession);
  }

  List<TrainingExercise> _exercises(CoachProposal proposal) {
    return [
      for (final exercise in proposal.exercises)
        TrainingExercise(
          exerciseId: exercise.exerciseId,
          name: exercise.name,
          exerciseType: exercise.exerciseType,
          notes: exercise.notes,
          restTargetSeconds: exercise.restTargetSeconds,
          sets: [
            for (final set in exercise.sets)
              TrainingSet(
                setNumber: set.setNumber,
                reps: set.reps,
                weightKg: set.weightKg,
                setKind: _kind(set.setKind),
                clientUuid: 'pending',
              ),
          ],
        ),
    ];
  }

  CoachIntentRead _intentBefore(List<CoachChatMessage> messages, int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (messages[i].speaker == CoachSpeaker.user) return readCoachIntent(messages[i].text);
    }
    return readCoachIntent('');
  }

  TrainingSetKind _kind(String raw) {
    for (final kind in TrainingSetKind.values) {
      if (kind.name == raw) return kind;
    }
    return TrainingSetKind.working;
  }
}
