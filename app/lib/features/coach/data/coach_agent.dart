import 'dart:convert';

import 'package:app_flutter/features/coach/data/coach_prompts.dart';
import 'package:app_flutter/features/coach/domain/coach_intent.dart';
import 'package:app_flutter/features/coach/data/coach_rest.dart';
import 'package:app_flutter/features/coach/data/coach_tools.dart';
import 'package:app_flutter/features/coach/skills/coach_skills.dart';
import 'package:app_flutter/features/coach/domain/coach_proposal.dart';
import 'package:app_flutter/features/coach/domain/coach_thought.dart';
import 'package:app_flutter/features/settings/domain/entities/ai_settings.dart';
import 'package:openai_dart/openai_dart.dart';

/// 客户端 Agent：模型决定调用哪个工具，工具通过 App REST 取数据。
///
/// AI 请求只带用户自己的 Key；工具请求走另一个 Dio（App JWT），两者不共用客户端。
class CoachAgent {
  CoachAgent({
    required AiSettings settings,
    required String apiKey,
    required CoachRestApi rest,
    OpenAIClient? client,
  }) : _rest = rest, // ignore: prefer_initializing_formals — 私有字段不能作为命名参数。
       _model = settings.model,
       _client =
           client ??
           OpenAIClient(
             config: OpenAIConfig(
               authProvider: ApiKeyProvider(apiKey),
               baseUrl: settings.baseUrl,
               timeout: const Duration(seconds: 90),
               // 包的 retry wrapper 对 429 的 POST 也会重试，必须关掉避免重复计费。
               retryPolicy: const RetryPolicy(maxRetries: 0),
             ),
           );

  static const _maxRounds = 8;
  static const _maxToolsPerRound = 8;

  final CoachRestApi _rest;
  final String _model;
  final OpenAIClient _client;

  Future<CoachTurn> run({
    required List<Map<String, String>> history,
    required String userText,
    Set<int> blockedIds = const {},
    void Function(CoachThoughtStep step)? onThought,
    void Function(String text)? onText,
  }) async {
    final asked = userText.trim().isEmpty ? defaultUserPrompt : userText.trim();
    final intent = readCoachIntent(asked);
    final context = CoachToolContext(rest: _rest, blockedIds: blockedIds)
      ..allowPlan = intent.kind == CoachIntent.plan;
    final recent = history.length > 20
        ? history.sublist(history.length - 20)
        : history;
    final messages = <ChatMessage>[
      ChatMessage.system(coachSystemPrompt),
      ChatMessage.system(coachIntentPrompt(asked)),
      for (final item in recent)
        if (_historyText(item) != null)
          item['role'] == 'user'
              ? ChatMessage.user(_historyText(item)!)
              : ChatMessage.assistant(content: _historyText(item)),
      ChatMessage.user(asked),
    ];
    final steps = <CoachThoughtStep>[];
    void emit(CoachThoughtStep step) {
      steps.add(step);
      onThought?.call(step);
    }

    final reply = await _loop(
      messages: messages,
      tools: coachTools,
      context: context,
      emit: emit,
      onText: onText,
      understoodTitle: '理解为「${intent.label}」',
      understoodDetail: intent.hint,
    );
    final text = reply.isNotEmpty
        ? reply
        : context.proposal?['summary']?.toString().trim() ?? '';
    return CoachTurn(
      messages: [if (text.isNotEmpty) text else '这次没整理出内容。可以换个说法再试。'],
      thoughts: _collapse(steps),
      proposal: context.proposal == null
          ? null
          : CoachProposal.fromJson(context.proposal!),
    );
  }

  Future<CoachTurn> suggestNext({
    required List<Map<String, dynamic>> exercises,
    void Function(CoachThoughtStep step)? onThought,
  }) async {
    final blocked = <int>{
      for (final item in exercises)
        if (item['exercise_id'] is num) (item['exercise_id'] as num).toInt(),
    };
    final context = CoachToolContext(rest: _rest, blockedIds: blocked);
    final messages = <ChatMessage>[
      ChatMessage.system(nextSystemPrompt),
      ChatMessage.user(sessionPrompt(exercises)),
    ];
    final steps = <CoachThoughtStep>[];
    void emit(CoachThoughtStep step) {
      steps.add(step);
      onThought?.call(step);
    }

    final reply = await _loop(
      messages: messages,
      tools: nextTools,
      context: context,
      emit: emit,
    );
    final suggestion = context.suggestion == null
        ? null
        : CoachSuggestion.fromJson(context.suggestion!);
    return CoachTurn(
      messages: [if (reply.isNotEmpty) reply],
      thoughts: _collapse(steps),
      suggestion: suggestion,
      error: suggestion == null ? '这次没选出动作，稍后再试' : null,
    );
  }

  /// 会话还没有动作时，按档案、恢复和最近历史排出一整堂。
  Future<CoachTurn> fillEmptySession({
    void Function(CoachThoughtStep step)? onThought,
  }) async {
    final context = CoachToolContext(rest: _rest)..allowPlan = true;
    final messages = <ChatMessage>[
      ChatMessage.system(fillSessionPrompt),
      ChatMessage.user(fillSessionUserPrompt),
    ];
    final steps = <CoachThoughtStep>[];
    void emit(CoachThoughtStep step) {
      steps.add(step);
      onThought?.call(step);
    }

    final reply = await _loop(
      messages: messages,
      tools: fillSessionTools,
      context: context,
      emit: emit,
      understoodTitle: '这场还是空的',
      understoodDetail: '按恢复和最近训练打分',
    );
    final proposal = context.proposal == null
        ? null
        : CoachProposal.fromJson(context.proposal!);
    final summary = proposal?.summary.trim() ?? '';
    final empty = proposal == null || proposal.exercises.isEmpty;
    return CoachTurn(
      messages: [
        if (reply.isNotEmpty) reply else if (summary.isNotEmpty) summary,
      ],
      thoughts: _collapse(steps),
      proposal: proposal,
      error: empty ? '这次没排出动作，稍后再试' : null,
    );
  }

  Future<String> _loop({
    required List<ChatMessage> messages,
    required List<Tool> tools,
    required CoachToolContext context,
    required void Function(CoachThoughtStep step) emit,
    void Function(String text)? onText,
    String understoodTitle = '理解问题',
    String understoodDetail = '',
  }) async {
    emit(
      CoachThoughtStep(
        kind: 'thinking',
        title: understoodTitle,
        detail: understoodDetail,
        state: 'running',
      ),
    );
    var understood = false;
    for (var round = 0; round < _maxRounds; round++) {
      final accumulator = ChatStreamAccumulator();
      var showedText = false;
      await for (final event in _client.chat.completions.createStream(
        ChatCompletionCreateRequest(
          model: _model,
          messages: messages,
          tools: tools,
          temperature: 0.3,
        ),
      )) {
        accumulator.add(event);
        if (onText == null) continue;
        if (accumulator.hasToolCalls) {
          if (showedText) {
            showedText = false;
            onText('');
          }
          continue;
        }
        final partial = accumulator.content;
        if (partial.isEmpty) continue;
        showedText = true;
        onText(partial);
      }
      if (!understood) {
        emit(
          CoachThoughtStep(
            kind: 'thinking',
            title: understoodTitle,
            detail: understoodDetail,
          ),
        );
        understood = true;
      }
      final reasoning = (accumulator.reasoningContent.isNotEmpty
              ? accumulator.reasoningContent
              : accumulator.reasoning)
          .trim();
      if (reasoning.isNotEmpty) {
        emit(
          CoachThoughtStep(
            kind: 'reasoning',
            title: '推理',
            detail: _clip(reasoning, 360),
          ),
        );
      }
      final calls = accumulator.toolCalls;
      if (calls.isEmpty) return accumulator.content.trim();
      final content = accumulator.content;
      messages.add(
        ChatMessage.assistant(
          content: content.isEmpty ? null : content,
          toolCalls: calls,
        ),
      );
      await _execute(calls, context, emit, messages);
    }
    return '';
  }

  /// 先搜索（写 catalog），再并行读数据，最后本地校验课表。
  Future<void> _execute(
    List<ToolCall> calls,
    CoachToolContext context,
    void Function(CoachThoughtStep step) emit,
    List<ChatMessage> messages,
  ) async {
    final search = <ToolCall>[];
    final data = <ToolCall>[];
    final writes = <ToolCall>[];
    final plan = <ToolCall>[];
    for (final call in calls.take(_maxToolsPerRound)) {
      switch (call.function.name) {
        case 'search_exercises':
          search.add(call);
        case 'propose_session' || 'suggest_next':
          plan.add(call);
        default:
          if (skillWriteNames.contains(call.function.name)) {
            writes.add(call);
          } else {
            data.add(call);
          }
      }
    }

    for (final batch in [search, data]) {
      if (batch.isEmpty) continue;
      for (final call in batch) {
        emit(
          CoachThoughtStep(
            kind: 'tool',
            title: coachToolStatus[call.function.name] ?? '正在整理',
            state: 'running',
          ),
        );
      }
      final payloads = await Future.wait([
        for (final call in batch) _runTool(call, context),
      ]);
      for (var i = 0; i < batch.length; i++) {
        final call = batch[i];
        emit(
          CoachThoughtStep(
            kind: 'tool',
            title: coachToolStatus[call.function.name] ?? '正在整理',
            detail: _stepDetail(
              call.function.name,
              _arguments(call),
              payloads[i],
            ),
          ),
        );
        messages.add(
          ChatMessage.tool(
            toolCallId: call.id,
            content: jsonEncode(payloads[i]),
          ),
        );
      }
    }
    for (final call in writes) {
      emit(
        CoachThoughtStep(
          kind: 'tool',
          title: coachToolStatus[call.function.name] ?? '正在整理',
          state: 'running',
        ),
      );
      final payload = await _runTool(call, context);
      emit(
        CoachThoughtStep(
          kind: 'tool',
          title: coachToolStatus[call.function.name] ?? '正在整理',
          detail: _stepDetail(call.function.name, _arguments(call), payload),
        ),
      );
      messages.add(
        ChatMessage.tool(toolCallId: call.id, content: jsonEncode(payload)),
      );
    }
    if (plan.isNotEmpty) {
      for (final call in plan) {
        emit(
          CoachThoughtStep(
            kind: 'tool',
            title: coachToolStatus[call.function.name] ?? '正在整理',
            state: 'running',
          ),
        );
      }
      final payloads = await Future.wait([
        for (final call in plan) _runTool(call, context),
      ]);
      for (var i = 0; i < plan.length; i++) {
        final call = plan[i];
        emit(
          CoachThoughtStep(
            kind: 'tool',
            title: coachToolStatus[call.function.name] ?? '正在整理',
            detail: _stepDetail(
              call.function.name,
              _arguments(call),
              payloads[i],
            ),
          ),
        );
        messages.add(
          ChatMessage.tool(
            toolCallId: call.id,
            content: jsonEncode(payloads[i]),
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _runTool(
    ToolCall call,
    CoachToolContext context,
  ) {
    return context.call(call.function.name, _arguments(call));
  }

  void close() => _client.close();

  String? _historyText(Map<String, String> item) {
    final role = item['role'];
    if (role != 'user' && role != 'assistant') return null;
    final content = _clip(item['content'] ?? '', 2000);
    return content.isEmpty ? null : content;
  }
}

Map<String, dynamic> _arguments(ToolCall call) {
  try {
    final decoded = jsonDecode(call.function.arguments);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
  } on FormatException {
    return const {};
  }
}

String _clip(String text, int limit) {
  final compact = text
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .join(' ');
  if (compact.length <= limit) return compact;
  return '${compact.substring(0, limit)}…';
}

String _stepDetail(
  String name,
  Map<String, dynamic> args,
  Map<String, dynamic> payload,
) {
  final error = payload['error'];
  if (error != null) return error.toString();
  switch (name) {
    case 'get_profile':
      if (payload['complete'] == false) return '档案还没填';
      return [
        payload['goal'],
        payload['experience'],
        payload['equipment'],
      ].whereType<String>().where((bit) => bit.isNotEmpty).join(' · ');
    case 'get_training_context':
      final zones = payload['week_zones'];
      if (zones is! List || zones.isEmpty) return '本周还没有训练量';
      return zones
          .take(3)
          .map((item) => item is Map ? '${item['name']} ${item['zone']}' : '')
          .where((text) => text.isNotEmpty)
          .join('、');
    case 'search_exercises':
      final items = payload['items'];
      if (items is! List || items.isEmpty) {
        return '没有找到「${args['search'] ?? ''}」';
      }
      return items
          .take(3)
          .map((item) => item is Map ? '${item['name']}' : '')
          .where((text) => text.isNotEmpty)
          .join('、');
    case 'get_exercise_loads':
      final items = payload['items'];
      if (items is! List) return '';
      return items
          .take(3)
          .map((item) {
            if (item is! Map) return '';
            final kg = item['estimated_1rm_kg'];
            final label = item['name'] ?? item['exercise_id'];
            return kg is num ? '$label 1RM ${_number(kg)}kg' : '$label';
          })
          .where((text) => text.isNotEmpty)
          .join('、');
    case 'get_recent_sessions':
      final items = payload['items'];
      return items is List ? '${items.length} 次训练' : '';
    case 'get_exercise_stats':
      final records = payload['records'];
      if (records is Map && records['session_count'] != null) {
        return '${payload['name'] ?? '动作'} · ${records['session_count']} 次';
      }
      return payload['name']?.toString() ?? '';
    case 'get_templates':
      if (payload['title'] != null) return payload['title'].toString();
      final items = payload['items'];
      return items is List ? '${items.length} 个模板' : '';
    case 'get_stats_overview':
      return payload['sessions_count'] == null
          ? ''
          : '${payload['sessions_count']} 次训练';
    case 'propose_session':
      return payload['ok'] == true
          ? '${payload['exercise_count'] ?? 0} 个动作'
          : '';
    case 'suggest_next':
      return payload['ok'] == true ? payload['name']?.toString() ?? '' : '';
    case 'list_catalog':
      final muscles = payload['muscle_groups'];
      return muscles is List ? '${muscles.length} 个肌群' : '';
    case 'list_my_exercises':
      final mine = payload['items'];
      return mine is List ? '${mine.length} 个自建动作' : '';
    case 'create_my_exercise' || 'update_my_exercise':
      return payload['name']?.toString() ?? '';
    case 'create_template' || 'update_template':
      return payload['title']?.toString() ?? '';
    case 'delete_my_exercise' ||
        'delete_template' ||
        'delete_session' ||
        'update_profile':
      return payload['ok'] == true ? '已完成' : '';
    default:
      return '';
  }
}

String _number(num value) {
  return value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

List<CoachThoughtStep> _collapse(List<CoachThoughtStep> steps) {
  final folded = <CoachThoughtStep>[];
  for (final step in steps) {
    if (folded.isNotEmpty &&
        folded.last.title == step.title &&
        folded.last.running) {
      folded[folded.length - 1] = step;
    } else {
      folded.add(step);
    }
  }
  return [
    for (final step in folded)
      if (!step.running) step,
  ];
}
