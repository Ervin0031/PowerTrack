import 'dart:convert';

import 'package:app_flutter/features/coach/application/coach_provider.dart';
import 'package:app_flutter/features/coach/data/coach_agent.dart';
import 'package:app_flutter/features/coach/data/coach_repository.dart';
import 'package:app_flutter/features/coach/data/coach_rest.dart';
import 'package:app_flutter/features/coach/domain/coach_proposal.dart';
import 'package:app_flutter/features/coach/domain/coach_thought.dart';
import 'package:app_flutter/features/coach/domain/coach_thread.dart';
import 'package:app_flutter/features/profile/data/repositories/profile_repository.dart';
import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:app_flutter/features/settings/domain/entities/ai_settings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Future<List<Map<String, dynamic>>> searchExercises(String search, int limit) async => const [];

  @override
  Future<List<Map<String, dynamic>>> getExerciseLoads(List<int> ids) async => const [];

  @override
  Future<Map<String, dynamic>> getRecentSessions(int limit) async => {};

  @override
  Future<Map<String, dynamic>> getExerciseStats(int exerciseId, int days) async => {};

  @override
  Future<Map<String, dynamic>> getTemplates(int limit, {int? templateId}) async => {};

  @override
  Future<Map<String, dynamic>> getStatsOverview(int days) async => {};
}

class _FakeCoachRepo extends CoachRepository {
  _FakeCoachRepo({this.failImport = false}) : super(Dio());

  final bool failImport;
  final imports = <Map<String, dynamic>>[];

  @override
  Future<int> createThread() async => 42;

  @override
  Future<List<CoachThreadSummary>> listThreads() async => const [];

  @override
  Future<void> importTurn({
    required int threadId,
    required String userContent,
    required String assistantContent,
    CoachProposal? proposal,
    List<CoachThoughtStep> trace = const [],
  }) async {
    if (failImport) throw StateError('network down');
    imports.add({
      'thread_id': threadId,
      'user': userContent,
      'assistant': assistantContent,
      'proposal': proposal,
      'trace': trace,
    });
  }
}

class _FakeProfileRepo extends FitnessProfileRepository {
  _FakeProfileRepo(this.profile) : super(Dio());

  final FitnessProfile? profile;

  @override
  Future<FitnessProfile?> fetch() async => profile;
}

const _profile = FitnessProfile(
  gender: 'male',
  birthYear: 1990,
  heightCm: 180,
  weightKg: 80,
  goal: 'muscle_gain',
  experience: 'intermediate',
);

CoachAgent _agent(http.Client client) {
  return CoachAgent(
    settings: const AiSettings(
      baseUrl: 'https://ai.test/v1',
      model: 'deepseek-flash',
      hasKey: true,
    ),
    apiKey: 'test-key',
    rest: _FakeRest(),
    client: OpenAIClient(
      config: OpenAIConfig(
        authProvider: ApiKeyProvider('test-key'),
        baseUrl: 'https://ai.test/v1',
        retryPolicy: const RetryPolicy(maxRetries: 0),
      ),
      httpClient: client,
    ),
  );
}

http.Response _reply(String text) {
  final chunk = jsonEncode({
    'id': 'chatcmpl-test',
    'object': 'chat.completion.chunk',
    'created': 1,
    'model': 'deepseek-flash',
    'choices': [
      {
        'index': 0,
        'delta': {'role': 'assistant', 'content': text},
        'finish_reason': 'stop',
      },
    ],
  });
  return http.Response.bytes(
    utf8.encode('data: $chunk\n\ndata: [DONE]\n\n'),
    200,
    headers: {'content-type': 'text/event-stream; charset=utf-8'},
  );
}

ProviderContainer _container({
  required FitnessProfile? profile,
  required _FakeCoachRepo repo,
  required CoachAgent agent,
}) {
  final container = ProviderContainer(
    overrides: [
      coachAgentProvider.overrideWith((ref) async => agent),
      fitnessProfileRepositoryProvider.overrideWithValue(_FakeProfileRepo(profile)),
      coachRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(agent.close);
  return container;
}

void main() {
  test('未配置 Key：提示去设置，不追加消息', () async {
    final container = ProviderContainer(
      overrides: [
        coachAgentProvider.overrideWith((ref) async => throw const AiNotConfiguredException()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(coachControllerProvider.notifier).send('你好');

    final state = container.read(coachControllerProvider);
    expect(state.messages, isEmpty);
    expect(state.error, '请先在设置里填写 AI API Key');
  });

  test('缺档案：置 needsProfile，不调用模型', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return _reply('不该出现');
    });
    final agent = _agent(client);
    final container = _container(
      profile: null,
      repo: _FakeCoachRepo(),
      agent: agent,
    );

    await container.read(coachControllerProvider.notifier).send('你好');

    final state = container.read(coachControllerProvider);
    expect(state.needsProfile, isTrue);
    expect(state.messages, isEmpty);
    expect(requests, 0);
  });

  test('成功一轮：更新消息并写回服务端历史', () async {
    final client = MockClient((request) async => _reply('好的，今天练推。'));
    final agent = _agent(client);
    final repo = _FakeCoachRepo();
    final container = _container(
      profile: _profile,
      repo: repo,
      agent: agent,
    );

    await container.read(coachControllerProvider.notifier).send('按我的档案排今天这一堂');

    final state = container.read(coachControllerProvider);
    expect(state.threadId, 42);
    expect(state.messages.map((item) => item.text), ['按我的档案排今天这一堂', '好的，今天练推。']);
    expect(state.error, isNull);
    expect(repo.imports, hasLength(1));
    expect(repo.imports.single['thread_id'], 42);
    expect(repo.imports.single['user'], '按我的档案排今天这一堂');
    expect(repo.imports.single['assistant'], '好的，今天练推。');
  });

  test('import 失败不影响当前对话', () async {
    final client = MockClient((request) async => _reply('好的'));
    final agent = _agent(client);
    final container = _container(
      profile: _profile,
      repo: _FakeCoachRepo(failImport: true),
      agent: agent,
    );

    await container.read(coachControllerProvider.notifier).send('你好');

    final state = container.read(coachControllerProvider);
    expect(state.messages.map((item) => item.text), ['你好', '好的']);
    expect(state.error, isNull);
    expect(state.sending, isFalse);
  });
}
