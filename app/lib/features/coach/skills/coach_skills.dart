import 'package:app_flutter/features/coach/data/coach_rest.dart';
import 'package:openai_dart/openai_dart.dart';

/// 教练能改的数据。读工具先把 id 放进本轮上下文，写工具只接受这些 id。
abstract class CoachSkillHost {
  CoachRestApi get rest;

  Map<int, Map<String, dynamic>> get catalog;

  Set<int> get ownedExerciseIds;

  Set<int> get sessionIds;

  Set<int> get templateIds;

  Set<int> get muscleIds;

  Set<int> get equipmentIds;
}

const skillPrompt = '''
你可以操作用户自己的数据。只有用户明确要求创建、修改或删除时才调用写入工具。
- list_catalog：肌群和器械。创建或修改动作前先调用，id 必须来自这里。
- list_my_exercises：用户自己创建的动作。修改或删除动作前先调用。
- create_my_exercise / update_my_exercise / delete_my_exercise：只处理自建动作。公共动作库不能删、不能改。
- create_template 的动作 id 必须来自本轮 search_exercises 或 list_my_exercises。
- update_template / delete_template 前先 get_templates，且只能动用户自己的模板。
- delete_session 前先 get_recent_sessions，只删里面出现过的训练。
- update_profile：用户明确要改健身档案时提交完整字段。
不要改密码，不要注销账号。
''';

final skillToolNames = {for (final tool in skillTools) tool.function.name};

const skillWriteNames = {
  'create_my_exercise',
  'update_my_exercise',
  'delete_my_exercise',
  'create_template',
  'update_template',
  'delete_template',
  'delete_session',
  'update_profile',
};

final skillTools = <Tool>[
  _noArgs('list_catalog', '肌群和器械字典，创建动作前先看 id。'),
  _noArgs('list_my_exercises', '当前用户自己创建的动作。'),
  Tool.function(
    name: 'create_my_exercise',
    description: '创建一个归用户所有的动作。肌群和器械 id 必须来自 list_catalog。',
    parameters: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'name_en': {'type': 'string'},
        'exercise_type': {'type': 'string', 'enum': ['compound', 'isolation']},
        'primary_muscle_group_id': {'type': 'integer'},
        'equipment_id': {'type': 'integer'},
        'instructions': {'type': 'string'},
        'secondary_muscle_ids': {
          'type': 'array',
          'items': {'type': 'integer'},
        },
      },
      'required': ['name', 'exercise_type', 'primary_muscle_group_id'],
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'update_my_exercise',
    description: '修改用户自己创建的动作。只传要改的字段。',
    parameters: {
      'type': 'object',
      'properties': {
        'exercise_id': {'type': 'integer'},
        'name': {'type': 'string'},
        'name_en': {'type': 'string'},
        'exercise_type': {'type': 'string', 'enum': ['compound', 'isolation']},
        'primary_muscle_group_id': {'type': 'integer'},
        'equipment_id': {'type': 'integer'},
        'instructions': {'type': 'string'},
      },
      'required': ['exercise_id'],
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'delete_my_exercise',
    description: '删除用户自己创建、且没有训练记录的动作。',
    parameters: {
      'type': 'object',
      'properties': {
        'exercise_id': {'type': 'integer'},
      },
      'required': ['exercise_id'],
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'create_template',
    description: '用已经搜索到或用户自建的动作创建训练模板。',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'description': {'type': 'string'},
        'difficulty': {'type': 'string', 'enum': ['easy', 'moderate', 'hard']},
        'is_public': {'type': 'boolean'},
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
                    'set_kind': {'type': 'string', 'enum': ['warmup', 'working', 'drop', 'cooldown']},
                    'reps': {'type': 'integer'},
                    'weight_kg': {'type': 'number'},
                  },
                  'required': ['set_number'],
                  'additionalProperties': false,
                },
              },
            },
            'required': ['exercise_id', 'sets'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['title', 'exercises'],
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'update_template',
    description: '整体替换用户自己的模板。先 get_templates。',
    parameters: {
      'type': 'object',
      'properties': {
        'template_id': {'type': 'integer'},
        'title': {'type': 'string'},
        'description': {'type': 'string'},
        'difficulty': {'type': 'string', 'enum': ['easy', 'moderate', 'hard']},
        'is_public': {'type': 'boolean'},
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
                    'set_kind': {'type': 'string'},
                    'reps': {'type': 'integer'},
                    'weight_kg': {'type': 'number'},
                  },
                  'required': ['set_number'],
                  'additionalProperties': false,
                },
              },
            },
            'required': ['exercise_id', 'sets'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['template_id', 'title', 'exercises'],
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'delete_template',
    description: '删除用户自己的模板。template_id 必须来自本轮 get_templates。',
    parameters: {
      'type': 'object',
      'properties': {
        'template_id': {'type': 'integer'},
      },
      'required': ['template_id'],
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'delete_session',
    description: '删除用户自己的一次训练。session_id 必须来自本轮 get_recent_sessions。',
    parameters: {
      'type': 'object',
      'properties': {
        'session_id': {'type': 'integer'},
      },
      'required': ['session_id'],
      'additionalProperties': false,
    },
  ),
  Tool.function(
    name: 'update_profile',
    description: '覆盖保存健身档案。用户明确要求时才调用，并带上完整字段。',
    parameters: {
      'type': 'object',
      'properties': {
        'gender': {'type': 'string', 'enum': ['male', 'female', 'undisclosed']},
        'birth_year': {'type': 'integer'},
        'height_cm': {'type': 'number'},
        'weight_kg': {'type': 'number'},
        'goal': {
          'type': 'string',
          'enum': ['fat_loss', 'muscle_gain', 'reshape', 'health', 'performance'],
        },
        'experience': {'type': 'string', 'enum': ['beginner', 'intermediate', 'advanced']},
        'injury_tags': {'type': 'array', 'items': {'type': 'string'}},
        'weekly_days': {'type': 'integer'},
        'session_minutes': {'type': 'integer'},
        'equipment': {'type': 'string', 'enum': ['none', 'dumbbells', 'gym']},
        'preferences': {'type': 'array', 'items': {'type': 'string'}},
      },
      'required': ['gender', 'birth_year', 'height_cm', 'weight_kg', 'goal', 'experience'],
      'additionalProperties': false,
    },
  ),
];

Future<Map<String, dynamic>> callSkill(
  CoachSkillHost host,
  String name,
  Map<String, dynamic> args,
) {
  return switch (name) {
    'list_catalog' => _listCatalog(host),
    'list_my_exercises' => _listMine(host),
    'create_my_exercise' => _createExercise(host, args),
    'update_my_exercise' => _updateExercise(host, args),
    'delete_my_exercise' => _deleteExercise(host, args),
    'create_template' => _saveTemplate(host, args, create: true),
    'update_template' => _saveTemplate(host, args, create: false),
    'delete_template' => _deleteTemplate(host, args),
    'delete_session' => _deleteSession(host, args),
    'update_profile' => host.rest.updateProfile(args),
    _ => Future.value({'error': 'unknown tool $name'}),
  };
}

Future<Map<String, dynamic>> _listCatalog(CoachSkillHost host) async {
  final data = await host.rest.listCatalog();
  host.muscleIds
    ..clear()
    ..addAll(_ids(data['muscle_groups']));
  host.equipmentIds
    ..clear()
    ..addAll(_ids(data['equipment']));
  return data;
}

Future<Map<String, dynamic>> _listMine(CoachSkillHost host) async {
  final data = await host.rest.listMyExercises();
  for (final item in _maps(data['items'])) {
    final id = _int(item['id']);
    if (id == null) continue;
    host.ownedExerciseIds.add(id);
    host.catalog[id] = {
      'name': '${item['name'] ?? '动作'}',
      'exercise_type': '${item['exercise_type'] ?? 'compound'}',
    };
  }
  return data;
}

Future<Map<String, dynamic>> _createExercise(
  CoachSkillHost host,
  Map<String, dynamic> args,
) async {
  final name = _text(args['name'], 100);
  final type = args['exercise_type'];
  final muscleId = _int(args['primary_muscle_group_id']);
  if (name == null) return {'error': '动作名需要 1-100 字'};
  if (type != 'compound' && type != 'isolation') {
    return {'error': 'exercise_type 只能是 compound 或 isolation'};
  }
  if (muscleId == null || !host.muscleIds.contains(muscleId)) {
    return {'error': '先 list_catalog，再用返回的肌群 id'};
  }
  final equipmentId = _int(args['equipment_id']);
  if (equipmentId != null && !host.equipmentIds.contains(equipmentId)) {
    return {'error': '器械 id 不在 list_catalog 的结果里'};
  }
  final secondary = <int>[
    for (final value in _asList(args['secondary_muscle_ids']))
      if (_int(value) != null && host.muscleIds.contains(_int(value))) _int(value)!,
  ];
  final created = await host.rest.createMyExercise({
    'name': name,
    'exercise_type': type,
    'primary_muscle_group_id': muscleId,
    if (args['name_en'] is String) 'name_en': args['name_en'],
    if (equipmentId != null) 'equipment_id': equipmentId,
    if (args['instructions'] is String) 'instructions': args['instructions'],
    if (secondary.isNotEmpty) 'secondary_muscle_ids': secondary,
  });
  final id = _int(created['exercise_id']);
  if (id != null && created['error'] == null) {
    host.ownedExerciseIds.add(id);
    host.catalog[id] = {'name': name, 'exercise_type': type};
  }
  return created;
}

Future<Map<String, dynamic>> _updateExercise(
  CoachSkillHost host,
  Map<String, dynamic> args,
) async {
  final id = _int(args['exercise_id']);
  if (id == null || !host.ownedExerciseIds.contains(id)) {
    return {'error': '先 list_my_exercises，只能改自己创建的动作'};
  }
  final body = <String, dynamic>{};
  final name = args['name'];
  if (name is String) {
    final trimmed = _text(name, 100);
    if (trimmed == null) return {'error': '动作名需要 1-100 字'};
    body['name'] = trimmed;
  }
  if (args['name_en'] is String) body['name_en'] = args['name_en'];
  if (args['exercise_type'] != null) body['exercise_type'] = args['exercise_type'];
  final muscleId = _int(args['primary_muscle_group_id']);
  if (muscleId != null) {
    if (!host.muscleIds.contains(muscleId)) return {'error': '先 list_catalog，再用返回的肌群 id'};
    body['primary_muscle_group_id'] = muscleId;
  }
  final equipmentId = _int(args['equipment_id']);
  if (equipmentId != null) {
    if (!host.equipmentIds.contains(equipmentId)) return {'error': '器械 id 不在 list_catalog 的结果里'};
    body['equipment_id'] = equipmentId;
  }
  if (args['instructions'] is String) body['instructions'] = args['instructions'];
  if (body.isEmpty) return {'error': '没有要修改的字段'};
  return host.rest.updateMyExercise(id, body);
}

Future<Map<String, dynamic>> _deleteExercise(
  CoachSkillHost host,
  Map<String, dynamic> args,
) async {
  final id = _int(args['exercise_id']);
  if (id == null || !host.ownedExerciseIds.contains(id)) {
    return {'error': '先 list_my_exercises，只能删除自己创建的动作'};
  }
  final result = await host.rest.deleteMyExercise(id);
  if (result['error'] == null) {
    host.ownedExerciseIds.remove(id);
    host.catalog.remove(id);
  }
  return result;
}

Future<Map<String, dynamic>> _saveTemplate(
  CoachSkillHost host,
  Map<String, dynamic> args, {
  required bool create,
}) async {
  final title = _text(args['title'], 120);
  if (title == null) return {'error': '模板标题需要 1-120 字'};
  int? templateId;
  if (!create) {
    templateId = _int(args['template_id']);
    if (templateId == null || !host.templateIds.contains(templateId)) {
      return {'error': '先 get_templates，只能改自己已经看到的模板'};
    }
  }
  final raw = args['exercises'];
  if (raw is! List || raw.isEmpty || raw.length > 12) {
    return {'error': 'exercises 需要 1-12 个动作'};
  }
  final exercises = <Map<String, dynamic>>[];
  for (var index = 0; index < raw.length; index++) {
    final item = raw[index];
    if (item is! Map) return {'error': '动作格式不对'};
    final id = _int(item['exercise_id']);
    if (id == null || !host.catalog.containsKey(id)) {
      return {'error': '动作 id 必须来自本轮搜索或自建动作'};
    }
    final sets = <Map<String, dynamic>>[];
    final rawSets = item['sets'];
    if (rawSets is! List || rawSets.isEmpty || rawSets.length > 10) {
      return {'error': '每个动作需要 1-10 组'};
    }
    for (final set in rawSets) {
      if (set is! Map) return {'error': '组格式不对'};
      final number = _int(set['set_number']);
      if (number == null || number < 1) return {'error': 'set_number 必须从 1 开始'};
      final kind = set['set_kind'];
      sets.add({
        'set_number': number,
        'set_kind': kind is String && kind.isNotEmpty ? kind : 'working',
        if (_int(set['reps']) != null) 'reps': _int(set['reps']),
        if (set['weight_kg'] is num) 'weight_kg': set['weight_kg'],
      });
    }
    exercises.add({
      'exercise_id': id,
      'sort_order': index,
      if (item['notes'] is String) 'notes': item['notes'],
      if (_int(item['rest_target_seconds']) != null)
        'rest_target_seconds': _int(item['rest_target_seconds']),
      'sets': sets,
    });
  }
  final body = {
    'title': title,
    if (args['description'] is String) 'description': args['description'],
    'difficulty': args['difficulty'] ?? 'moderate',
    'is_public': args['is_public'] == true,
    'exercises': exercises,
  };
  final saved = create
      ? await host.rest.createTemplate(body)
      : await host.rest.updateTemplate(templateId!, body);
  final id = _int(saved['id']);
  if (id != null && saved['error'] == null) host.templateIds.add(id);
  return saved;
}

Future<Map<String, dynamic>> _deleteTemplate(
  CoachSkillHost host,
  Map<String, dynamic> args,
) async {
  final id = _int(args['template_id']);
  if (id == null || !host.templateIds.contains(id)) {
    return {'error': '先 get_templates，只能删除已经看到的模板'};
  }
  final result = await host.rest.deleteTemplate(id);
  if (result['error'] == null) host.templateIds.remove(id);
  return result;
}

Future<Map<String, dynamic>> _deleteSession(
  CoachSkillHost host,
  Map<String, dynamic> args,
) async {
  final id = _int(args['session_id']);
  if (id == null || !host.sessionIds.contains(id)) {
    return {'error': '先 get_recent_sessions，只能删除里面出现过的训练'};
  }
  final result = await host.rest.deleteSession(id);
  if (result['error'] == null) host.sessionIds.remove(id);
  return result;
}

Tool _noArgs(String name, String description) => Tool.function(
      name: name,
      description: description,
      parameters: {
        'type': 'object',
        'properties': <String, dynamic>{},
        'additionalProperties': false,
      },
    );

String? _text(dynamic value, int max) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty || text.length > max) return null;
  return text;
}

int? _int(dynamic value) => value is num ? value.toInt() : null;

List<dynamic> _asList(dynamic value) => value is List ? value : const [];

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

Set<int> _ids(dynamic value) => {
      for (final item in _maps(value))
        if (_int(item['id']) != null) _int(item['id'])!,
    };
