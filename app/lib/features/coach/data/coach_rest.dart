import 'dart:convert';

import 'package:dio/dio.dart';

/// 教练工具读取 App 数据的边界。实现必须走带 App JWT 的 Dio，
/// 与直连第三方 AI 的 HTTP 客户端完全分开。
abstract class CoachRestApi {
  Future<Map<String, dynamic>?> getProfile();

  Future<Map<String, dynamic>> getTrainingContext();

  Future<List<Map<String, dynamic>>> searchExercises(String search, int limit);

  Future<List<Map<String, dynamic>>> getExerciseLoads(List<int> ids);

  Future<Map<String, dynamic>> getRecentSessions(int limit);

  Future<Map<String, dynamic>> getExerciseStats(int exerciseId, int days);

  Future<Map<String, dynamic>> getTemplates(int limit, {int? templateId});

  Future<Map<String, dynamic>> getStatsOverview(int days);

  Future<Map<String, dynamic>> listCatalog();

  Future<Map<String, dynamic>> listMyExercises();

  Future<Map<String, dynamic>> createMyExercise(Map<String, dynamic> body);

  Future<Map<String, dynamic>> updateMyExercise(int id, Map<String, dynamic> body);

  Future<Map<String, dynamic>> deleteMyExercise(int id);

  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> body);

  Future<Map<String, dynamic>> updateTemplate(int id, Map<String, dynamic> body);

  Future<Map<String, dynamic>> deleteTemplate(int id);

  Future<Map<String, dynamic>> deleteSession(int id);

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body);
}

/// 测试替身没有实现写入时的空结果。正式请求走 [CoachRest]。
mixin CoachSkillStubs {
  Future<Map<String, dynamic>> listCatalog() async => const {
        'muscle_groups': <Map<String, dynamic>>[],
        'equipment': <Map<String, dynamic>>[],
      };

  Future<Map<String, dynamic>> listMyExercises() async => const {'items': <Map<String, dynamic>>[]};

  Future<Map<String, dynamic>> createMyExercise(Map<String, dynamic> body) async =>
      const {'error': '未实现'};

  Future<Map<String, dynamic>> updateMyExercise(int id, Map<String, dynamic> body) async =>
      const {'error': '未实现'};

  Future<Map<String, dynamic>> deleteMyExercise(int id) async => const {'error': '未实现'};

  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> body) async =>
      const {'error': '未实现'};

  Future<Map<String, dynamic>> updateTemplate(int id, Map<String, dynamic> body) async =>
      const {'error': '未实现'};

  Future<Map<String, dynamic>> deleteTemplate(int id) async => const {'error': '未实现'};

  Future<Map<String, dynamic>> deleteSession(int id) async => const {'error': '未实现'};

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async =>
      const {'error': '未实现'};
}

/// 用现有 REST 端点拼出模型需要的上下文。404 表示“还没数据”，不是错误。
class CoachRest implements CoachRestApi {
  CoachRest(this._dio);

  final Dio _dio;
  Map<int, String>? _muscleCache;
  final Map<int, String?> _nameCache = {};

  @override
  Future<Map<String, dynamic>?> getProfile() async {
    final data = await _getObject('/api/v1/users/me/profile');
    if (data == null || data['complete'] != true) return null;
    final profile = _asMap(data['profile']);
    if (profile == null) return null;
    return {
      'complete': true,
      'goal': profile['goal'],
      'experience': profile['experience'],
      'weight_kg': profile['weight_kg'],
      'injury_tags': profile['injury_tags'] ?? const [],
      'weekly_days': profile['weekly_days'],
      'session_minutes': profile['session_minutes'],
      'equipment': profile['equipment'],
    };
  }

  @override
  Future<Map<String, dynamic>> getTrainingContext() async {
    final recoveryFuture = _getObject('/api/v1/muscle-groups/status');
    final landmarksFuture = _getObject('/api/v1/volume/landmarks');
    final weeklyFuture = _getObject('/api/v1/volume/weekly');
    final recovery = await recoveryFuture;
    final landmarks = await landmarksFuture;
    final weekly = await weeklyFuture;

    final zones = _asMaps(landmarks?['items'])
        .where((item) => (_int(item['hard_sets']) ?? 0) > 0)
        .map(
          (item) => {
            'name': item['name'],
            'hard_sets': item['hard_sets'],
            'zone': item['zone'],
          },
        )
        .toList();
    final weeks = _asMaps(weekly?['weeks']);
    final recent = weeks.length <= 3 ? weeks : weeks.sublist(weeks.length - 3);

    return {
      'recovery': [
        for (final item in _asMaps(recovery?['items']))
          {
            'name': item['name'],
            'recovery_progress': item['recovery_progress'],
            'hours_since_last': item['hours_since_last'],
          },
      ],
      'week_start': landmarks?['week_start'],
      'week_hard_sets': landmarks?['hard_sets'],
      'week_zones': zones,
      'recent_weeks': [
        for (final week in recent)
          {
            'week_start': week['week_start'],
            'hard_volume': week['hard_volume'],
            'hard_sets': week['hard_sets'],
            'avg_rpe': week['avg_rpe'],
            'by_muscle': [
              for (final muscle in _asMaps(week['by_muscle']))
                {
                  'name': muscle['name'],
                  'hard_sets': muscle['hard_sets'],
                },
            ],
          },
      ],
      'suggest_deload': weekly?['suggest_deload'],
      'deload_reason': weekly?['deload_reason'],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> searchExercises(
    String search,
    int limit,
  ) async {
    final pageFuture = _getObject(
      '/api/v1/exercises',
      query: {'search': search, 'limit': limit},
    );
    final musclesFuture = _muscleNames();
    final page = await pageFuture;
    final muscles = await musclesFuture;
    return [
      for (final item in _asMaps(page?['items']))
        {
          'exercise_id': item['id'],
          'name': item['name'],
          'exercise_type': item['exercise_type'],
          'muscle': muscles[_int(item['primary_muscle_group_id'])],
          // 列表优先用缩略图，没有则退回原图。
          'image_url': item['thumb_url'] ?? item['image_url'],
        },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getExerciseLoads(List<int> ids) async {
    return Future.wait([for (final id in ids.take(8)) _loadsFor(id)]);
  }

  @override
  Future<Map<String, dynamic>> getRecentSessions(int limit) async {
    final page = await _getObject(
      '/api/v1/sessions',
      query: {'status': 'completed', 'limit': limit},
    );
    final sessions = _asMaps(page?['items']).take(2).toList();
    final details = await Future.wait([
      for (final session in sessions)
        _getObject('/api/v1/sessions/${session['id']}'),
    ]);
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < details.length; i++) {
      final detail = details[i];
      if (detail == null) continue;
      final grouped = <int, List<Map<String, dynamic>>>{};
      for (final set in _asMaps(detail['sets'])) {
        final id = _int(set['exercise_id']);
        if (id == null) continue;
        grouped.putIfAbsent(id, () => []).add(set);
      }
      final names = await Future.wait([
        for (final id in grouped.keys) _exerciseName(id),
      ]);
      final exercises = <Map<String, dynamic>>[];
      var index = 0;
      for (final entry in grouped.entries) {
        exercises.add({
          'exercise_id': entry.key,
          'name': names[index++],
          'sets': [
            for (final set in entry.value.take(12))
              {
                'set_number': set['set_number'],
                'set_kind': set['set_kind'],
                'reps': set['reps'],
                'weight_kg': set['weight_kg'],
                'rpe': set['rpe'],
              },
          ],
        });
      }
      items.add({
        'session_id': detail['id'],
        'started_at': detail['started_at'],
        'completed_at': detail['completed_at'],
        'notes': detail['notes'],
        'exercises': exercises,
      });
    }
    return {'items': items};
  }

  @override
  Future<Map<String, dynamic>> getExerciseStats(
    int exerciseId,
    int days,
  ) async {
    final data = await _getObject(
      '/api/v1/exercises/$exerciseId/stats',
      query: {'days': days},
    );
    if (data == null) return {'error': '没有这个动作的数据'};
    final records = _asMap(data['records']) ?? const {};
    return {
      'exercise_id': exerciseId,
      'name': await _exerciseName(exerciseId),
      'period_days': data['period_days'],
      'records': {
        'max_weight_kg': records['max_weight_kg'],
        'estimated_1rm_kg': records['estimated_1rm_kg'],
        'session_count': records['session_count'],
        'last_at': records['last_at'],
      },
      'history': [
        for (final item in _asMaps(data['history']).take(5))
          {
            'session_id': item['session_id'],
            'started_at': item['started_at'],
            'sets': [
              for (final set in _asMaps(item['sets']))
                {
                  'set_number': set['set_number'],
                  'set_kind': set['set_kind'],
                  'reps': set['reps'],
                  'weight_kg': set['weight_kg'],
                  'rpe': set['rpe'],
                },
            ],
          },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getTemplates(
    int limit, {
    int? templateId,
  }) async {
    if (templateId != null) {
      final data = await _getObject(
        '/api/v1/templates/$templateId',
        notFoundAsNull: true,
      );
      if (data == null) return {'error': '模板不存在'};
      return {
        'id': data['id'],
        'title': data['title'],
        'difficulty': data['difficulty'],
        'description': data['description'],
        'exercises': [
          for (final item in _asMaps(data['exercises']))
            {
              'exercise_id': item['exercise_id'],
              'name': item['name'],
              'exercise_type': item['exercise_type'],
              'notes': item['notes'],
              'rest_target_seconds': item['rest_target_seconds'],
              'sets': [
                for (final set in _asMaps(item['sets']))
                  {
                    'set_number': set['set_number'],
                    'set_kind': set['set_kind'],
                    'reps': set['reps'],
                    'weight_kg': set['weight_kg'],
                  },
              ],
            },
        ],
      };
    }
    final data = await _getObject(
      '/api/v1/templates',
      query: {'scope': 'all', 'limit': limit},
    );
    return {
      'items': [
        for (final item in _asMaps(data?['items']))
          {
            'id': item['id'],
            'title': item['title'],
            'difficulty': item['difficulty'],
            'exercise_count': item['exercise_count'],
            'set_count': item['set_count'],
            'primary_muscles': [
              for (final muscle in _asMaps(item['primary_muscles']))
                muscle['name'],
            ],
          },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getStatsOverview(int days) async {
    final data = await _getObject(
      '/api/v1/stats/overview',
      query: {'days': days},
    );
    return {
      'period_days': data?['period_days'],
      'period_label': data?['period_label'],
      'sessions_count': data?['sessions_count'],
      'total_volume_kg': data?['total_volume_kg'],
      'avg_rpe': data?['avg_rpe'],
      'hard_sets': data?['hard_sets'],
      'by_muscle': data?['by_muscle'] ?? const [],
      'recent_prs': _asMaps(data?['recent_prs']).take(8).toList(),
      'top_exercises': _asMaps(data?['top_exercises']).take(8).toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> listCatalog() async {
    final musclesFuture = _getObject(
      '/api/v1/exercises/muscle-groups',
      query: {'limit': 100},
    );
    final equipmentFuture = _getObject(
      '/api/v1/exercises/equipment',
      query: {'limit': 100},
    );
    final muscles = await musclesFuture;
    final equipment = await equipmentFuture;
    return {
      'muscle_groups': [
        for (final item in _asMaps(muscles?['items']))
          {'id': item['id'], 'name': item['name'], 'category': item['category']},
      ],
      'equipment': [
        for (final item in _asMaps(equipment?['items']))
          {'id': item['id'], 'name': item['name']},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> listMyExercises() async {
    final data = await _getObject('/api/v1/exercises/mine');
    return {
      'items': [
        for (final item in _asMaps(data?['items']))
          {
            'id': item['id'],
            'name': item['name'],
            'exercise_type': item['exercise_type'],
            'primary_muscle_group_id': item['primary_muscle_group_id'],
            'equipment_id': item['equipment_id'],
          },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> createMyExercise(Map<String, dynamic> body) async {
    final data = await _send('/api/v1/exercises/mine', body);
    if (data['error'] != null) return data;
    return {
      'ok': true,
      'exercise_id': data['id'],
      'name': data['name'],
      'is_custom': true,
    };
  }

  @override
  Future<Map<String, dynamic>> updateMyExercise(
    int id,
    Map<String, dynamic> body,
  ) async {
    final data = await _send('/api/v1/exercises/mine/$id', body, method: 'PUT');
    if (data['error'] != null) return data;
    return {'ok': true, 'exercise_id': data['id'], 'name': data['name']};
  }

  @override
  Future<Map<String, dynamic>> deleteMyExercise(int id) {
    return _remove('/api/v1/exercises/mine/$id');
  }

  @override
  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> body) {
    return _sendTemplate('/api/v1/templates', body);
  }

  @override
  Future<Map<String, dynamic>> updateTemplate(int id, Map<String, dynamic> body) {
    return _sendTemplate('/api/v1/templates/$id', body, method: 'PUT');
  }

  @override
  Future<Map<String, dynamic>> deleteTemplate(int id) {
    return _remove('/api/v1/templates/$id');
  }

  @override
  Future<Map<String, dynamic>> deleteSession(int id) {
    return _remove('/api/v1/sessions/$id');
  }

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    final data = await _send('/api/v1/users/me/profile', body, method: 'PUT');
    if (data['error'] != null) return data;
    final profile = _asMap(data['profile']);
    return {
      'ok': true,
      'complete': data['complete'] == true,
      'goal': profile?['goal'],
      'experience': profile?['experience'],
      'weight_kg': profile?['weight_kg'],
    };
  }

  Future<Map<String, dynamic>> _sendTemplate(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    try {
      final form = FormData.fromMap({'data': jsonEncode(body)});
      final response = method == 'PUT'
          ? await _dio.put<dynamic>(path, data: form)
          : await _dio.post<dynamic>(path, data: form);
      final data = _asMap(response.data);
      if (data == null) return {'ok': true};
      return {
        'ok': true,
        'id': data['id'],
        'title': data['title'],
        'exercise_count': data['exercise_count'],
      };
    } on DioException catch (error) {
      return {'error': _dioMessage(error)};
    }
  }

  Future<Map<String, dynamic>> _send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    try {
      final response = method == 'PUT'
          ? await _dio.put<dynamic>(path, data: body)
          : await _dio.post<dynamic>(path, data: body);
      return _asMap(response.data) ?? {'ok': true};
    } on DioException catch (error) {
      return {'error': _dioMessage(error)};
    }
  }

  Future<Map<String, dynamic>> _remove(String path) async {
    try {
      await _dio.delete<dynamic>(path);
      return {'ok': true};
    } on DioException catch (error) {
      if (error.response?.statusCode == 204) return {'ok': true};
      return {'error': _dioMessage(error)};
    }
  }

  Future<Map<String, dynamic>> _loadsFor(int id) async {
    final oneRmFuture = _getObject(
      '/api/v1/exercises/$id/one-rm',
      notFoundAsNull: true,
    );
    final lastFuture = _getObject(
      '/api/v1/exercises/$id/last-session-sets',
      notFoundAsNull: true,
    );
    final oneRm = await oneRmFuture;
    final last = await lastFuture;
    return {
      'exercise_id': id,
      'estimated_1rm_kg': oneRm?['estimated_kg'],
      'last_sets': [
        for (final set in _asMaps(last?['sets']).take(8))
          {
            'set_number': set['set_number'],
            'set_kind': set['set_kind'],
            'reps': set['reps'],
            'weight_kg': set['weight_kg'],
            'rpe': set['rpe'],
          },
      ],
    };
  }

  Future<Map<int, String>> _muscleNames() async {
    final cached = _muscleCache;
    if (cached != null) return cached;
    final data = await _getObject(
      '/api/v1/exercises/muscle-groups',
      query: {'limit': 100},
    );
    final map = <int, String>{};
    for (final item in _asMaps(data?['items'])) {
      final id = _int(item['id']);
      final name = item['name'] as String?;
      if (id != null && name != null) map[id] = name;
    }
    return _muscleCache = map;
  }

  Future<String?> _exerciseName(int id) async {
    if (_nameCache.containsKey(id)) return _nameCache[id];
    final data = await _getObject(
      '/api/v1/exercises/$id',
      notFoundAsNull: true,
    );
    final name = data?['name'] as String?;
    _nameCache[id] = name;
    return name;
  }

  Future<Map<String, dynamic>?> _getObject(
    String path, {
    Map<String, dynamic>? query,
    bool notFoundAsNull = false,
  }) async {
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);
      return _asMap(response.data);
    } on DioException catch (error) {
      if (notFoundAsNull && error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

List<Map<String, dynamic>> _asMaps(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

int? _int(dynamic value) => value is num ? value.toInt() : null;

String _dioMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) return first['msg'].toString();
    }
  }
  return switch (error.response?.statusCode) {
    403 => '没有权限',
    404 => '找不到',
    409 => '已被使用，不能删除',
    _ => '操作失败',
  };
}
