import 'package:app_flutter/features/coach/data/coach_rest.dart';
import 'package:app_flutter/features/coach/skills/coach_skills.dart';
import 'package:openai_dart/openai_dart.dart';

const setKinds = ['warmup', 'working', 'drop', 'cooldown'];

/// 工具注册表：JSON Schema + Dart handler。模型决定调哪个，handler 调 App REST。
final coachTools = <Tool>[
  _noArgsTool('get_profile', '健身档案：目标、经验、伤病、器械、时长。'),
  _noArgsTool(
    'get_training_context',
    '肌群恢复、本周 hard set 容量区间、最近三周容量和 deload 建议。',
  ),
  Tool.function(
    name: 'search_exercises',
    description: '按中文名搜动作库，返回真实 exercise_id。',
    parameters: {
      'type': 'object',
      'properties': {
        'search': {'type': 'string', 'description': '动作名，如卧推、深蹲'},
        'limit': {'type': 'integer', 'description': '1-8，默认 6'},
      },
      'required': ['search'],
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'get_exercise_loads',
    description: '动作的 1RM 和上次各组。id 必须来自本轮搜索。',
    parameters: {
      'type': 'object',
      'properties': {
        'exercise_ids': {
          'type': 'array',
          'items': {'type': 'integer'},
        },
      },
      'required': ['exercise_ids'],
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'get_recent_sessions',
    description: '最近完成的训练，含每个动作的组数、次数、重量和 RPE。',
    parameters: {
      'type': 'object',
      'properties': {
        'limit': {'type': 'integer', 'description': '1-10，默认 5'},
      },
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'get_exercise_stats',
    description: '单个动作的历史趋势：最大重量、估算 1RM、最近几次训练。',
    parameters: {
      'type': 'object',
      'properties': {
        'exercise_id': {'type': 'integer'},
        'days': {'type': 'integer', 'description': '7-365，默认 30'},
      },
      'required': ['exercise_id'],
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'get_templates',
    description: '查看已有训练模板列表，或指定模板的完整动作。',
    parameters: {
      'type': 'object',
      'properties': {
        'limit': {'type': 'integer', 'description': '1-20，默认 10'},
        'template_id': {'type': 'integer'},
      },
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'get_stats_overview',
    description: '训练概览：次数、容量、RPE、肌群分布、PR 和常用动作。',
    parameters: {
      'type': 'object',
      'properties': {
        'days': {'type': 'integer', 'description': '7-365，默认 30'},
      },
      'additionalProperties': false,
    },
  ),
  ...skillTools,
  Tool.function(
    name: 'propose_session',
    description: '只在用户要求排课或生成计划时提交课表。不会写入训练记录。',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'summary': {'type': 'string'},
        'estimated_minutes': {'type': 'integer'},
        'exercises': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'exercise_id': {'type': 'integer'},
              'notes': {'type': 'string'},
              'rest_target_seconds': {'type': 'integer'},
              'sets': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'set_number': {'type': 'integer'},
                    'set_kind': {'type': 'string', 'enum': setKinds},
                    'reps': {'type': 'integer'},
                    'weight_kg': {'type': 'number'},
                  },
                  'required': ['set_number', 'set_kind'],
                  'additionalProperties': false,
                },
              },
            },
            'required': ['exercise_id', 'sets'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['title', 'summary', 'estimated_minutes', 'exercises'],
      'additionalProperties': false,
    },
  ),
];

final suggestNextTool = Tool.function(
  name: 'suggest_next',
  description: '建议本场的下一个动作。不会写入训练记录。',
  parameters: {
    'type': 'object',
    'properties': {
      'reason': {'type': 'string'},
      'exercise': {
        'type': 'object',
        'properties': {
          'exercise_id': {'type': 'integer'},
          'notes': {'type': 'string'},
          'sets': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'set_number': {'type': 'integer'},
                'set_kind': {'type': 'string', 'enum': setKinds},
                'reps': {'type': 'integer'},
                'weight_kg': {'type': 'number'},
              },
              'required': ['set_number', 'set_kind'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['exercise_id', 'sets'],
        'additionalProperties': false,
      },
    },
    'required': ['reason', 'exercise'],
    'additionalProperties': false,
  },
);

final nextTools = <Tool>[
  for (final tool in coachTools)
    if (tool.function.name != 'propose_session' &&
        !skillToolNames.contains(tool.function.name))
      tool,
  suggestNextTool,
];

/// 空会话排一整堂：只留读工具和 propose_session。
final fillSessionTools = <Tool>[
  for (final tool in coachTools)
    if (!skillToolNames.contains(tool.function.name)) tool,
];

Tool _noArgsTool(String name, String description) => Tool.function(
  name: name,
  description: description,
  parameters: {
    'type': 'object',
    'properties': <String, dynamic>{},
    'additionalProperties': false,
  },
);

/// 一次工具循环里的可变状态。catalog 记录模型本轮实际见过的动作 id。
class CoachToolContext implements CoachSkillHost {
  CoachToolContext({required this.rest, this.blockedIds = const {}});

  @override
  final CoachRestApi rest;
  final Set<int> blockedIds;
  @override
  final Map<int, Map<String, dynamic>> catalog = {};
  @override
  final Set<int> ownedExerciseIds = {};
  @override
  final Set<int> sessionIds = {};
  @override
  final Set<int> templateIds = {};
  @override
  final Set<int> muscleIds = {};
  @override
  final Set<int> equipmentIds = {};
  Map<String, dynamic>? proposal;
  Map<String, dynamic>? suggestion;
  bool allowPlan = true;

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> args,
  ) async {
    try {
      if (skillToolNames.contains(name))
        return await callSkill(this, name, args);
      return switch (name) {
        'get_profile' => await rest.getProfile() ?? const {'complete': false},
        'get_training_context' => await rest.getTrainingContext(),
        'search_exercises' => await _searchExercises(args),
        'get_exercise_loads' => await _getExerciseLoads(args),
        'get_recent_sessions' => await _getRecentSessions(args),
        'get_exercise_stats' => await _getExerciseStats(args),
        'get_templates' => await _getTemplates(args),
        'get_stats_overview' => await _getStatsOverview(args),
        'propose_session' => await _proposeSession(args),
        'suggest_next' => await _suggestNext(args),
        _ => {'error': 'unknown tool $name'},
      };
    } catch (_) {
      // 工具失败回填给模型重试，不把网络细节或令牌带进上下文。
      return {'error': '读取数据失败，请检查网络后重试'};
    }
  }

  Future<Map<String, dynamic>> _searchExercises(
    Map<String, dynamic> args,
  ) async {
    final search = (args['search'] as String? ?? '').trim();
    if (search.isEmpty) return {'error': 'search 不能为空'};
    final limit = ((_int(args['limit']) ?? 6).clamp(1, 8)).toInt();
    final items = await rest.searchExercises(search, limit);
    for (final item in items) {
      final id = _int(item['exercise_id']);
      if (id == null) continue;
      catalog[id] = {
        'name': '${item['name'] ?? '动作'}',
        'exercise_type': '${item['exercise_type'] ?? 'compound'}',
        'image_url': item['image_url'],
      };
    }
    // 图片地址只用于本地渲染，不回填给模型，避免占用上下文。
    return {
      'items': [
        for (final item in items)
          {
            'exercise_id': item['exercise_id'],
            'name': item['name'],
            'exercise_type': item['exercise_type'],
            'muscle': item['muscle'],
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _getExerciseLoads(
    Map<String, dynamic> args,
  ) async {
    final raw = args['exercise_ids'];
    if (raw is! List) return {'error': 'exercise_ids 必须是数组'};
    final ids = <int>[];
    for (final value in raw.take(8)) {
      final id = _int(value);
      if (id != null) ids.add(id);
    }
    final known = [
      for (final id in ids)
        if (catalog.containsKey(id)) id,
    ];
    final items = <Map<String, dynamic>>[
      for (final id in ids)
        if (!catalog.containsKey(id)) {'exercise_id': id, 'error': '先搜索这个动作'},
    ];
    if (known.isNotEmpty) {
      final loads = await rest.getExerciseLoads(known);
      for (final load in loads) {
        final id = _int(load['exercise_id']);
        items.add({...load, 'name': id == null ? null : catalog[id]?['name']});
      }
    }
    return {'items': items};
  }

  Future<Map<String, dynamic>> _getRecentSessions(
    Map<String, dynamic> args,
  ) async {
    final limit = ((_int(args['limit']) ?? 5).clamp(1, 10)).toInt();
    final data = await rest.getRecentSessions(limit);
    for (final item
        in data['items'] is List ? data['items'] as List : const []) {
      if (item is Map) {
        final id = _int(item['session_id']);
        if (id != null) sessionIds.add(id);
      }
    }
    return data;
  }

  Future<Map<String, dynamic>> _getExerciseStats(
    Map<String, dynamic> args,
  ) async {
    final id = _int(args['exercise_id']);
    if (id == null) return {'error': 'exercise_id 缺失'};
    final days = ((_int(args['days']) ?? 30).clamp(7, 365)).toInt();
    return rest.getExerciseStats(id, days);
  }

  Future<Map<String, dynamic>> _getTemplates(Map<String, dynamic> args) async {
    final limit = ((_int(args['limit']) ?? 10).clamp(1, 20)).toInt();
    final data = await rest.getTemplates(
      limit,
      templateId: _int(args['template_id']),
    );
    final single = _int(data['id']);
    if (single != null) templateIds.add(single);
    if (data['items'] is List) {
      for (final item in data['items'] as List) {
        if (item is Map) {
          final id = _int(item['id']);
          if (id != null) templateIds.add(id);
        }
      }
    }
    return data;
  }

  Future<Map<String, dynamic>> _getStatsOverview(
    Map<String, dynamic> args,
  ) async {
    final days = ((_int(args['days']) ?? 30).clamp(7, 365)).toInt();
    return rest.getStatsOverview(days);
  }

  Future<Map<String, dynamic>> _proposeSession(
    Map<String, dynamic> args,
  ) async {
    if (!allowPlan) {
      return {'error': '用户这次不是要排课。用文字回答，不要提交课表。'};
    }
    if (catalog.isEmpty) {
      return {'error': '先 search_exercises，再用返回的 exercise_id'};
    }
    final title = _text(args['title'], 40);
    final summary = _text(args['summary'], 280);
    if (title == null || summary == null) {
      return {'error': 'title 需要 1-40 字，summary 需要 1-280 字'};
    }
    final minutes = _int(args['estimated_minutes']);
    if (minutes == null || minutes < 15 || minutes > 180) {
      return {'error': 'estimated_minutes 必须在 15-180 之间'};
    }
    final raw = args['exercises'];
    if (raw is! List || raw.isEmpty || raw.length > 8) {
      return {'error': 'exercises 需要 1-8 个动作'};
    }
    final filled = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) return {'error': '动作格式不对'};
      final map = Map<String, dynamic>.from(item);
      final id = _int(map['exercise_id']);
      if (id == null) return {'error': 'exercise_id 缺失'};
      final known = catalog[id];
      if (known == null) {
        return {'error': '这些 id 不在本次搜索结果里: $id'};
      }
      final sets = _parseSets(map['sets']);
      if (sets == null) return {'error': '每个动作需要 1-8 组合法组数'};
      final restSeconds = _int(map['rest_target_seconds']);
      filled.add({
        'exercise_id': id,
        'name': known['name'],
        'exercise_type': known['exercise_type'],
        'image_url': known['image_url'],
        if (map['notes'] is String) 'notes': (map['notes'] as String).trim(),
        if (restSeconds != null)
          'rest_target_seconds': restSeconds.clamp(0, 600),
        'sets': sets,
      });
    }
    proposal = {
      'title': title,
      'summary': summary,
      'estimated_minutes': minutes,
      'exercises': filled,
    };
    return {'ok': true, 'exercise_count': filled.length};
  }

  Future<Map<String, dynamic>> _suggestNext(Map<String, dynamic> args) async {
    if (catalog.isEmpty) {
      return {'error': '先 search_exercises，再用返回的 exercise_id'};
    }
    final raw = args['exercise'];
    if (raw is! Map) return {'error': 'exercise 必须是一个动作'};
    final map = Map<String, dynamic>.from(raw);
    final id = _int(map['exercise_id']);
    if (id == null) return {'error': 'exercise_id 缺失'};
    final known = catalog[id];
    if (known == null) return {'error': '这个 id 不在本次搜索结果里'};
    if (blockedIds.contains(id)) return {'error': '这个动作本场已经在练'};
    final sets = _parseSets(map['sets']);
    if (sets == null) return {'error': '这个动作需要 1-8 组合法组数'};
    final reason = (args['reason'] as String? ?? '').trim();
    suggestion = {
      'reason': reason.length > 180 ? reason.substring(0, 180) : reason,
      'exercise': {
        'exercise_id': id,
        'name': known['name'],
        'exercise_type': known['exercise_type'],
        'image_url': known['image_url'],
        if (map['notes'] is String) 'notes': (map['notes'] as String).trim(),
        'sets': sets,
      },
    };
    return {'ok': true, 'name': known['name']};
  }
}

List<Map<String, dynamic>>? _parseSets(dynamic raw) {
  if (raw is! List || raw.isEmpty || raw.length > 8) return null;
  final sets = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) return null;
    final setNumber = _int(item['set_number']);
    if (setNumber == null || setNumber < 1 || setNumber > 12) return null;
    final reps = _int(item['reps']);
    if (reps != null && (reps < 1 || reps > 30)) return null;
    final weight = _double(item['weight_kg']);
    if (weight != null && (weight < 0 || weight > 500)) return null;
    final kind = item['set_kind'] as String?;
    sets.add({
      'set_number': setNumber,
      'set_kind': setKinds.contains(kind) ? kind : 'working',
      'reps': ?reps,
      'weight_kg': ?weight,
    });
  }
  return sets;
}

String? _text(dynamic value, int max) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty || text.length > max) return null;
  return text;
}

int? _int(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _double(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
