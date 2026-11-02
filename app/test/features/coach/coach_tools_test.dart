import 'package:app_flutter/features/coach/data/coach_rest.dart';
import 'package:app_flutter/features/coach/data/coach_tools.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRest with CoachSkillStubs implements CoachRestApi {
  @override
  Future<Map<String, dynamic>?> getProfile() async => {'complete': true};

  @override
  Future<Map<String, dynamic>> getTrainingContext() async => {'recovery': const []};

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
  Future<Map<String, dynamic>> getRecentSessions(int limit) async => {'items': const []};

  @override
  Future<Map<String, dynamic>> getExerciseStats(int exerciseId, int days) async => {};

  @override
  Future<Map<String, dynamic>> getTemplates(int limit, {int? templateId}) async => {};

  @override
  Future<Map<String, dynamic>> getStatsOverview(int days) async => {};
}

Map<String, dynamic> _proposal({int exerciseId = 7}) => {
      'title': '推日',
      'summary': '胸和三头',
      'estimated_minutes': 45,
      'exercises': [
        {
          'exercise_id': exerciseId,
          'sets': [
            {'set_number': 1, 'set_kind': 'working', 'reps': 8, 'weight_kg': 40},
            {'set_number': 2, 'set_kind': 'bogus', 'reps': 8},
          ],
        },
      ],
    };

void main() {
  test('排课闸门：没意图、没 catalog、未知 id 都拒绝', () async {
    final context = CoachToolContext(rest: _FakeRest())..allowPlan = false;
    expect((await context.call('propose_session', _proposal()))['error'], contains('不是要排课'));

    context.allowPlan = true;
    expect(
      (await context.call('propose_session', _proposal()))['error'],
      contains('search_exercises'),
    );

    await context.call('search_exercises', {'search': '卧推'});
    final unknown = await context.call('propose_session', _proposal(exerciseId: 99));
    expect(unknown['error'], contains('不在本次搜索结果'));
    expect(context.proposal, isNull);
  });

  test('合法课表用搜索到的名字覆盖，并归一化 set_kind', () async {
    final context = CoachToolContext(rest: _FakeRest());
    await context.call('search_exercises', {'search': '卧推'});

    final result = await context.call('propose_session', _proposal());

    expect(result, {'ok': true, 'exercise_count': 1});
    final exercise = context.proposal!['exercises'][0] as Map<String, dynamic>;
    expect(exercise['name'], '杠铃卧推');
    expect(exercise['exercise_type'], 'compound');
    expect(exercise['image_url'], 'https://cdn.test/7-thumb.jpg');
    expect((exercise['sets'] as List)[1]['set_kind'], 'working');
  });

  test('suggest_next 拒绝本场已在练的动作', () async {
    final context = CoachToolContext(rest: _FakeRest(), blockedIds: {7});
    await context.call('search_exercises', {'search': '卧推'});

    final result = await context.call('suggest_next', {
      'reason': '继续练胸',
      'exercise': {
        'exercise_id': 7,
        'sets': [
          {'set_number': 1, 'set_kind': 'working', 'reps': 8},
        ],
      },
    });

    expect(result['error'], contains('已经在练'));
    expect(context.suggestion, isNull);
  });

  test('没列出自己的动作时不能删除', () async {
    final context = CoachToolContext(rest: _FakeRest());
    final result = await context.call('delete_my_exercise', {'exercise_id': 3});
    expect(result['error'], contains('list_my_exercises'));
  });

  test('自建动作可以写进新模板', () async {
    final rest = _SkillRest();
    final context = CoachToolContext(rest: rest);
    await context.call('list_catalog', {});
    final created = await context.call('create_my_exercise', {
      'name': '弹力带外旋',
      'exercise_type': 'isolation',
      'primary_muscle_group_id': 4,
    });
    expect(created['exercise_id'], 21);

    final saved = await context.call('create_template', {
      'title': '肩',
      'exercises': [
        {
          'exercise_id': 21,
          'sets': [
            {'set_number': 1, 'reps': 12},
          ],
        },
      ],
    });

    expect(saved['ok'], true);
    expect(rest.createdExercise['name'], '弹力带外旋');
    expect(rest.createdTemplate['title'], '肩');
  });

  test('工具异常回填固定文案，不泄露网络细节', () async {
    final context = CoachToolContext(rest: _ThrowingRest());
    final result = await context.call('get_stats_overview', {});
    expect(result['error'], '读取数据失败，请检查网络后重试');
  });
}

class _SkillRest extends _FakeRest {
  Map<String, dynamic> createdExercise = {};
  Map<String, dynamic> createdTemplate = {};

  @override
  Future<Map<String, dynamic>> listCatalog() async => {
        'muscle_groups': [
          {'id': 4, 'name': '肩'},
        ],
        'equipment': [
          {'id': 2, 'name': '弹力带'},
        ],
      };

  @override
  Future<Map<String, dynamic>> createMyExercise(Map<String, dynamic> body) async {
    createdExercise = body;
    return {'ok': true, 'exercise_id': 21, 'name': body['name'], 'is_custom': true};
  }

  @override
  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> body) async {
    createdTemplate = body;
    return {'ok': true, 'id': 8, 'title': body['title']};
  }
}

class _ThrowingRest extends _FakeRest {
  @override
  Future<Map<String, dynamic>> getStatsOverview(int days) async {
    throw StateError('secret-token-should-not-leak');
  }
}
