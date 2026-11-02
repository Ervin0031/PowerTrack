import 'package:app_flutter/core/network/api_datetime.dart';

/// 已完成训练会话里的一组（纯 Dart）。
class WorkoutSetRecord {
  const WorkoutSetRecord({
    required this.id,
    required this.exerciseId,
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceMeters,
    this.notes,
    this.completedAt,
    this.rpe,
  });

  factory WorkoutSetRecord.fromJson(Map<String, dynamic> json) {
    return WorkoutSetRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      exerciseId: (json['exercise_id'] as num?)?.toInt() ?? 0,
      setNumber: (json['set_number'] as num?)?.toInt() ?? 0,
      reps: (json['reps'] as num?)?.toInt(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      completedAt: parseApiDateTimeOrNull(json['completed_at']),
      rpe: (json['rpe'] as num?)?.toDouble(),
    );
  }

  final int id;
  final int exerciseId;
  final int setNumber;
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final double? distanceMeters;
  final String? notes;
  final DateTime? completedAt;
  final double? rpe;

  double get volume {
    if (weightKg == null || reps == null || weightKg! <= 0 || reps! <= 0) return 0;
    return weightKg! * reps!;
  }
}

/// 会话详情：会话头 + 全部组。
class WorkoutSessionDetail {
  const WorkoutSessionDetail({
    required this.id,
    required this.clientUuid,
    required this.userId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.notes,
    this.sets = const [],
  });

  factory WorkoutSessionDetail.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      clientUuid: json['client_uuid'] as String? ?? '',
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      startedAt: parseApiDateTime(json['started_at'] as String),
      completedAt: parseApiDateTimeOrNull(json['completed_at']),
      notes: json['notes'] as String?,
      sets: (json['sets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkoutSetRecord.fromJson)
          .toList(),
    );
  }

  final int id;
  final String clientUuid;
  final int userId;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? notes;
  final List<WorkoutSetRecord> sets;

  Duration? get duration {
    final end = completedAt;
    if (end == null) return null;
    final d = end.difference(startedAt);
    return d.isNegative ? Duration.zero : d;
  }
}

/// 会话中出现的一个肌群。
class WorkoutMuscleHit {
  const WorkoutMuscleHit({
    required this.name,
    required this.nameEn,
    required this.isPrimary,
    required this.setCount,
    required this.volume,
  });

  final String name;
  final String nameEn;
  final bool isPrimary;
  final int setCount;
  final double volume;
}

/// 会话中的一个动作摘要。
class WorkoutExerciseSummary {
  const WorkoutExerciseSummary({
    required this.exerciseId,
    required this.name,
    this.nameEn,
    this.imageUrl,
    required this.setCount,
    this.maxWeightKg,
    required this.volume,
    this.primaryMuscleName,
    this.sets = const [],
    this.vsLast,
  });

  final int exerciseId;
  final String name;
  final String? nameEn;
  final String? imageUrl;
  final int setCount;
  final double? maxWeightKg;
  final double volume;
  final String? primaryMuscleName;
  final List<WorkoutSetRecord> sets;
  final WorkoutVsLast? vsLast;

  WorkoutExerciseSummary copyWith({WorkoutVsLast? vsLast}) {
    return WorkoutExerciseSummary(
      exerciseId: exerciseId,
      name: name,
      nameEn: nameEn,
      imageUrl: imageUrl,
      setCount: setCount,
      maxWeightKg: maxWeightKg,
      volume: volume,
      primaryMuscleName: primaryMuscleName,
      sets: sets,
      vsLast: vsLast ?? this.vsLast,
    );
  }
}

/// 同一动作在本次之前最近一次训练的对比。
class WorkoutVsLast {
  const WorkoutVsLast({
    required this.previousVolume,
    this.previousMaxWeightKg,
    this.previousRepsAtMax,
    required this.previousAt,
  });

  final double previousVolume;
  final double? previousMaxWeightKg;
  final int? previousRepsAtMax;
  final DateTime previousAt;
}

/// 用于从历史会话里挑「上次」的轻量快照。
class WorkoutPreviousSession {
  const WorkoutPreviousSession({
    required this.sessionId,
    required this.startedAt,
    this.sets = const [],
  });

  final int sessionId;
  final DateTime startedAt;
  final List<WorkoutSetRecord> sets;
}

/// 动态卡片 / 详情共用的一次训练展示模型。
class WorkoutFeedItem {
  const WorkoutFeedItem({
    required this.sessionId,
    required this.startedAt,
    this.completedAt,
    this.notes,
    this.duration,
    required this.volumeKg,
    this.estimatedKcal,
    required this.title,
    this.exercises = const [],
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.restSeconds = const [],
    this.hardSetCount = 0,
    this.averageRpe,
  });

  final int sessionId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? notes;
  final Duration? duration;
  final double volumeKg;
  final double? estimatedKcal;
  final String title;
  final List<WorkoutExerciseSummary> exercises;
  final List<WorkoutMuscleHit> primaryMuscles;
  final List<WorkoutMuscleHit> secondaryMuscles;
  final List<int> restSeconds;
  final int hardSetCount;
  final double? averageRpe;

  int get setCount => exercises.fold(0, (sum, e) => sum + e.setCount);

  bool get hasIntensity => hardSetCount > 0 || averageRpe != null;

  List<WorkoutExerciseSummary> get highlights {
    final ranked = [...exercises]..sort((a, b) => b.volume.compareTo(a.volume));
    return ranked.take(2).where((e) => e.maxWeightKg != null && e.maxWeightKg! > 0).toList();
  }

  WorkoutFeedItem copyWith({List<WorkoutExerciseSummary>? exercises}) {
    return WorkoutFeedItem(
      sessionId: sessionId,
      startedAt: startedAt,
      completedAt: completedAt,
      notes: notes,
      duration: duration,
      volumeKg: volumeKg,
      estimatedKcal: estimatedKcal,
      title: title,
      exercises: exercises ?? this.exercises,
      primaryMuscles: primaryMuscles,
      secondaryMuscles: secondaryMuscles,
      restSeconds: restSeconds,
      hardSetCount: hardSetCount,
      averageRpe: averageRpe,
    );
  }
}
