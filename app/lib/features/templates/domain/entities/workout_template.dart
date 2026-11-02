import 'package:app_flutter/core/network/api_datetime.dart';
import 'package:app_flutter/features/dynamic/domain/entities/workout_feed_item.dart';

import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/entities/training_set_kind.dart';

/// 模板难度：轻松 / 适中 / 高难度。
enum TemplateDifficulty {
  easy,
  moderate,
  hard;

  String get label => switch (this) {
        TemplateDifficulty.easy => '轻松',
        TemplateDifficulty.moderate => '适中',
        TemplateDifficulty.hard => '高难度',
      };

  String get apiValue => name;

  static TemplateDifficulty fromApi(String? value) => switch (value) {
        'easy' => TemplateDifficulty.easy,
        'hard' => TemplateDifficulty.hard,
        _ => TemplateDifficulty.moderate,
      };
}

int? _asInt(Object? value) => value is num ? value.toInt() : null;

double? _asDouble(Object? value) => value is num ? value.toDouble() : null;

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  return fallback;
}

DateTime _asDate(Object? value) {
  if (value is String) return parseApiDateTimeOrNull(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _asDateOrNull(Object? value) => parseApiDateTimeOrNull(value);

List<Map<String, dynamic>> _asMaps(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList();
}

/// 模板会练到的肌群。
class TemplateMuscleHit {
  const TemplateMuscleHit({
    required this.name,
    required this.nameEn,
    required this.isPrimary,
    this.setCount = 0,
  });

  factory TemplateMuscleHit.fromJson(Map<String, dynamic> json) {
    return TemplateMuscleHit(
      name: json['name'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      isPrimary: _asBool(json['is_primary']),
      setCount: _asInt(json['set_count']) ?? 0,
    );
  }

  final String name;
  final String nameEn;
  final bool isPrimary;
  final int setCount;

  WorkoutMuscleHit toFeedHit() => WorkoutMuscleHit(
        name: name,
        nameEn: nameEn,
        isPrimary: isPrimary,
        setCount: setCount,
        volume: setCount.toDouble(),
      );
}

class TemplateEquipmentHit {
  const TemplateEquipmentHit({required this.id, required this.name, required this.nameEn});

  factory TemplateEquipmentHit.fromJson(Map<String, dynamic> json) {
    return TemplateEquipmentHit(
      id: _asInt(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
    );
  }

  final int id;
  final String name;
  final String nameEn;
}

class TemplateSet {
  const TemplateSet({
    this.id,
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceMeters,
    this.notes,
    this.setKind = TrainingSetKind.working,
  });

  factory TemplateSet.fromJson(Map<String, dynamic> json) {
    return TemplateSet(
      id: _asInt(json['id']),
      setNumber: _asInt(json['set_number']) ?? 1,
      reps: _asInt(json['reps']),
      weightKg: _asDouble(json['weight_kg']),
      durationSeconds: _asInt(json['duration_seconds']),
      distanceMeters: _asDouble(json['distance_meters']),
      notes: json['notes'] as String?,
      setKind: TrainingSetKind.values.firstWhere(
        (k) => k.name == (json['set_kind'] as String? ?? 'working'),
        orElse: () => TrainingSetKind.working,
      ),
    );
  }

  final int? id;
  final int setNumber;
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final double? distanceMeters;
  final String? notes;
  final TrainingSetKind setKind;

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'reps': reps,
        'weightKg': weightKg,
        'durationSeconds': durationSeconds,
        'distanceMeters': distanceMeters,
        'notes': notes,
        'setKind': setKind.name,
      };

  TrainingSet toTrainingSet(String clientUuid) => TrainingSet(
        setNumber: setNumber,
        reps: reps,
        weightKg: weightKg,
        durationSeconds: durationSeconds,
        distanceMeters: distanceMeters,
        notes: notes,
        setKind: setKind,
        clientUuid: clientUuid,
      );
}

class TemplateExercise {
  const TemplateExercise({
    this.id,
    required this.exerciseId,
    required this.name,
    this.nameEn,
    this.imageUrl,
    this.exerciseType = 'compound',
    this.sortOrder = 0,
    this.supersetId,
    this.notes,
    this.restTargetSeconds,
    this.weightUnit = 'kg',
    this.sets = const [],
  });

  factory TemplateExercise.fromJson(Map<String, dynamic> json) {
    return TemplateExercise(
      id: _asInt(json['id']),
      exerciseId: _asInt(json['exercise_id']) ?? 0,
      name: json['name'] as String? ?? '',
      nameEn: json['name_en'] as String?,
      imageUrl: json['image_url'] as String?,
      exerciseType: json['exercise_type'] as String? ?? 'compound',
      sortOrder: _asInt(json['sort_order']) ?? 0,
      supersetId: _asInt(json['superset_id']),
      notes: json['notes'] as String?,
      restTargetSeconds: _asInt(json['rest_target_seconds']),
      weightUnit: json['weight_unit'] as String? ?? 'kg',
      sets: _asMaps(json['sets']).map(TemplateSet.fromJson).toList(),
    );
  }

  final int? id;
  final int exerciseId;
  final String name;
  final String? nameEn;
  final String? imageUrl;
  final String exerciseType;
  final int sortOrder;
  final int? supersetId;
  final String? notes;
  final int? restTargetSeconds;
  final String weightUnit;
  final List<TemplateSet> sets;

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sortOrder': sortOrder,
        'supersetId': supersetId,
        'notes': notes,
        'restTargetSeconds': restTargetSeconds,
        'weightUnit': weightUnit,
        'sets': [for (final set in sets) set.toJson()],
      };

  TrainingExercise toTrainingExercise() => TrainingExercise(
        exerciseId: exerciseId,
        name: name,
        imageUrl: imageUrl,
        exerciseType: exerciseType,
        supersetId: supersetId,
        notes: notes,
        restTargetSeconds: restTargetSeconds,
        weightUnit: weightUnit,
        sets: [
          for (var i = 0; i < sets.length; i++)
            sets[i].toTrainingSet('template-$exerciseId-${sets[i].setNumber}-$i'),
        ],
      );
}

class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.userId,
    required this.ownerUsername,
    required this.title,
    this.description,
    this.coverUrl,
    this.difficulty = TemplateDifficulty.moderate,
    this.isPublic = false,
    this.exerciseCount = 0,
    this.setCount = 0,
    this.completionCount = 0,
    this.isOwner = false,
    required this.createdAt,
    required this.updatedAt,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.equipment = const [],
    this.exercises = const [],
  });

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: _asInt(json['id']) ?? 0,
      userId: _asInt(json['user_id']) ?? 0,
      ownerUsername: json['owner_username'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
      difficulty: TemplateDifficulty.fromApi(json['difficulty'] as String?),
      isPublic: _asBool(json['is_public']),
      exerciseCount: _asInt(json['exercise_count']) ?? 0,
      setCount: _asInt(json['set_count']) ?? 0,
      completionCount: _asInt(json['completion_count']) ?? 0,
      isOwner: _asBool(json['is_owner']),
      createdAt: _asDate(json['created_at']),
      updatedAt: _asDate(json['updated_at']),
      primaryMuscles: _asMaps(json['primary_muscles']).map(TemplateMuscleHit.fromJson).toList(),
      secondaryMuscles: _asMaps(json['secondary_muscles']).map(TemplateMuscleHit.fromJson).toList(),
      equipment: _asMaps(json['equipment']).map(TemplateEquipmentHit.fromJson).toList(),
      exercises: _asMaps(json['exercises']).map(TemplateExercise.fromJson).toList(),
    );
  }

  final int id;
  final int userId;
  final String ownerUsername;
  final String title;
  final String? description;
  final String? coverUrl;
  final TemplateDifficulty difficulty;
  final bool isPublic;
  final int exerciseCount;
  final int setCount;
  final int completionCount;
  final bool isOwner;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TemplateMuscleHit> primaryMuscles;
  final List<TemplateMuscleHit> secondaryMuscles;
  final List<TemplateEquipmentHit> equipment;
  final List<TemplateExercise> exercises;

  List<WorkoutMuscleHit> get primaryFeedMuscles => [for (final m in primaryMuscles) m.toFeedHit()];

  List<WorkoutMuscleHit> get secondaryFeedMuscles => [for (final m in secondaryMuscles) m.toFeedHit()];
}

class TemplateCompletion {
  const TemplateCompletion({
    required this.sessionId,
    required this.userId,
    required this.username,
    required this.startedAt,
    this.completedAt,
    this.durationSeconds,
    this.setCount = 0,
    this.isSelf = false,
  });

  factory TemplateCompletion.fromJson(Map<String, dynamic> json) {
    return TemplateCompletion(
      sessionId: _asInt(json['session_id']) ?? 0,
      userId: _asInt(json['user_id']) ?? 0,
      username: json['username'] as String? ?? '',
      startedAt: _asDate(json['started_at']),
      completedAt: _asDateOrNull(json['completed_at']),
      durationSeconds: _asInt(json['duration_seconds']),
      setCount: _asInt(json['set_count']) ?? 0,
      isSelf: _asBool(json['is_self']),
    );
  }

  final int sessionId;
  final int userId;
  final String username;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationSeconds;
  final int setCount;
  final bool isSelf;

  Duration? get duration => durationSeconds == null ? null : Duration(seconds: durationSeconds!);
}

class TemplatePage {
  const TemplatePage({this.items = const [], this.total = 0});

  factory TemplatePage.fromJson(Map<String, dynamic> json) {
    return TemplatePage(
      items: _asMaps(json['items']).map(WorkoutTemplate.fromJson).toList(),
      total: _asInt(json['total']) ?? 0,
    );
  }

  final List<WorkoutTemplate> items;
  final int total;
}

class TemplateCompletionPage {
  const TemplateCompletionPage({this.items = const [], this.total = 0});

  factory TemplateCompletionPage.fromJson(Map<String, dynamic> json) {
    return TemplateCompletionPage(
      items: _asMaps(json['items']).map(TemplateCompletion.fromJson).toList(),
      total: _asInt(json['total']) ?? 0,
    );
  }

  final List<TemplateCompletion> items;
  final int total;
}
