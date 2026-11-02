import 'dart:convert';

import 'package:app_flutter/core/network/ai_error.dart';
import 'package:app_flutter/features/coach/data/coach_agent.dart';
import 'package:app_flutter/features/coach/data/coach_rest.dart';
import 'package:app_flutter/features/settings/domain/entities/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openai_dart/openai_dart.dart';

class _FakeRest with CoachSkillStubs implements CoachRestApi {
  @override
  Future<Map<String, dynamic>?> getProfile() async => null;

  @override
  Future<Map<String, dynamic>> getTrainingContext() async => {};

  @override
  Future<List<Map<String, dynamic>>> searchExercises(String search, int limit) async => [
        {
          'exercise_id': 7,
          'name': '杠铃卧推',
          'exercise_type': 'compound',
          'muscle': '胸',
          'image_url': 'https://cdn.test/7-thumb.jpg',
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> getExerciseLoads(List<int> ids) async => [
        for (final id in ids) {'exercise_id': id, 'estimated_1rm_kg': 100},
      ];

  @override
  Future<Map<String, dynamic>> getRecentSessions(int limit) async => {};

  @override
  Future<Map<String, dynamic>> getExerciseStats(int exerciseId, int days) async => {};

  @override
  Future<Map<String, dynamic>> getTemplates(int limit, {int? templateId}) async => {};

  @override
  Future<Map<String, dynamic>> getStatsOverview(int days) async => {};
}

const _settings = AiSettings(
  baseUrl: 'https://ai.test/v1',
  model: 'deepseek-flash',
  hasKey: true,
);

OpenAIClient _client(http.Client httpClient, {String apiKey = 'test-key'}) {
  return OpenAIClient(
    config: OpenAIConfig(
      authProvider: ApiKeyProvider(apiKey),
      baseUrl: 'https://ai.test/v1',
      retryPolicy: const RetryPolicy(maxRetries: 0),
    ),
    httpClient: httpClient,
  );
}

http.Response _sse(List<Map<String, dynamic>> deltas, {required String finish}) {
  final body = StringBuffer();
  for (var i = 0; i < deltas.length; i++) {
    body
      ..writeln(
        'data: ${jsonEncode({
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1,
          'model': 'deepseek-flash',
          'choices': [
            {'index': 0, 'delta': deltas[i], 'finish_reason': i == deltas.length - 1 ? finish : null},
          ],
        })}',
      )
      ..writeln();
  }
  body
    ..writeln('data: [DONE]')
    ..writeln();
  return http.Response.bytes(
    utf8.encode(body.toString()),
    200,
    headers: {'content-type': 'text/event-stream; charset=utf-8'},
  );
}

http.Response _completion({
  String? content,
  List<Map<String, dynamic>>? toolCalls,
}) {
  if (toolCalls != null) {
    return _sse([
      {
        'tool_calls': [
          for (var i = 0; i < toolCalls.length; i++) {...toolCalls[i], 'index': i},
        ],
      },
    ], finish: 'tool_calls');
  }
  final text = content ?? '';
  if (text.length < 2) {
    return _sse([
      {'role': 'assistant', 'content': text},
    ], finish: 'stop');
  }
  final mid = text.length ~/ 2;
  return _sse([
    {'role': 'assistant', 'content': text.substring(0, mid)},
    {'content': text.substring(mid)},
  ], finish: 'stop');
}

Map<String, dynamic> _call(String id, String name, Map<String, dynamic> args) => {
      'id': id,
      'type': 'function',
      'function': {'name': name, 'arguments': jsonEncode(args)},
    };

void main() {
  test('两轮工具调用：先搜索再排课，结果按 tool_call_id 回填', () async {
    final requests = <http.Request>[];
    var round = 0;
    final mock = MockClient((request) async {
      requests.add(request);
      round++;
      if (round == 1) {
        return _completion(
          toolCalls: [_call('search-1', 'search_exercises', {'search': '卧推'})],
        );
      }
      if (round == 2) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = (body['messages'] as List).cast<Map<String, dynamic>>();
        final tool = messages.lastWhere((item) => item['role'] == 'tool');
        expect(tool['tool_call_id'], 'search-1');
        expect(tool['content'], contains('杠铃卧推'));
        return _completion(
          toolCalls: [
            _call('plan-1', 'propose_session', {
              'title': '推日',
              'summary': '胸和三头',
              'estimated_minutes': 45,
              'exercises': [
                {
                  'exercise_id': 7,
                  'sets': [
                    {'set_number': 1, 'set_kind': 'working', 'reps': 8, 'weight_kg': 40},
                  ],
                }
              ],
            }),
          ],
        );
      }
      return _completion(content: '今天练推。');
    });
    final agent = CoachAgent(
      settings: _settings,
      apiKey: 'test-key',
      rest: _FakeRest(),
      client: _client(mock),
    );
    addTearDown(agent.close);

    final streamed = <String>[];
    final turn = await agent.run(
      history: [
        {'role': 'user', 'content': '你好'},
        {'role': 'assistant', 'content': '想练点什么？'},
      ],
      userText: '按我的档案排今天这一堂',
      onText: streamed.add,
    );

    expect(turn.messages, ['今天练推。']);
    expect(streamed, ['今天', '今天练推。']);
    expect(turn.proposal?.title, '推日');
    expect(turn.proposal?.exercises.single.name, '杠铃卧推');
    expect(turn.proposal?.exercises.single.imageUrl, 'https://cdn.test/7-thumb.jpg');
    expect(turn.thoughts, isNotEmpty);
    expect(turn.thoughts.every((step) => !step.running), isTrue);

    expect(requests, hasLength(3));
    expect(requests.first.url.path, '/v1/chat/completions');
    final auth = requests.first.headers.entries
        .firstWhere((entry) => entry.key.toLowerCase() == 'authorization')
        .value;
    expect(auth, 'Bearer test-key', reason: 'AI 请求只能带用户自己的 Key');
    expect(requests.first.body, contains('按我的档案排今天这一堂'));
    expect(requests.first.body, contains('你好'));
  });

  test('分析类请求即使模型提交课表也会被本地闸门拒绝', () async {
    var round = 0;
    final mock = MockClient((request) async {
      round++;
      if (round == 1) {
        return _completion(
          toolCalls: [_call('search-1', 'search_exercises', {'search': '卧推'})],
        );
      }
      if (round == 2) {
        return _completion(
          toolCalls: [
            _call('plan-1', 'propose_session', {
              'title': '推日',
              'summary': '胸和三头',
              'estimated_minutes': 45,
              'exercises': [
                {
                  'exercise_id': 7,
                  'sets': [
                    {'set_number': 1, 'set_kind': 'working', 'reps': 8},
                  ],
                }
              ],
            }),
          ],
        );
      }
      return _completion(content: '最近训练量还行。');
    });
    final agent = CoachAgent(
      settings: _settings,
      apiKey: 'test-key',
      rest: _FakeRest(),
      client: _client(mock),
    );
    addTearDown(agent.close);

    final turn = await agent.run(history: const [], userText: '分析最近训练数据');

    expect(turn.messages, ['最近训练量还行。']);
    expect(turn.proposal, isNull);
  });

  test('401 映射为固定文案，不拼接 Key 或 provider body', () async {
    final mock = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'error': {'message': 'invalid key test-key'},
        }),
        401,
        headers: {'content-type': 'application/json'},
      ),
    );
    final agent = CoachAgent(
      settings: _settings,
      apiKey: 'test-key',
      rest: _FakeRest(),
      client: _client(mock),
    );
    addTearDown(agent.close);

    Object? caught;
    try {
      await agent.run(history: const [], userText: '你好');
    } catch (error) {
      caught = error;
    }

    expect(caught, isNotNull);
    expect(aiErrorMessage(caught!), 'API Key 无效或已过期');
    expect(aiErrorMessage(caught), isNot(contains('test-key')));
  });
}
