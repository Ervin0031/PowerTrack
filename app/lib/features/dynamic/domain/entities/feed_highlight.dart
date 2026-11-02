import 'package:app_flutter/core/network/api_datetime.dart';

/// 动态卡片内嵌的训练快照（对应后端 `services/feed.py::build_session_snapshot`）。
///
/// 快照在分享时刻固化，源训练删除后依然完整。结构不对时 [fromJson] 返回 null，
/// 由卡片降级为纯文字动态。
class FeedSnapshot {
  const FeedSnapshot({
    this.schemaVersion = 1,
    this.sessionId,
    this.startedAt,
    this.completedAt,
    this.durationSeconds,
    this.notes,
    this.totalVolumeKg = 0,
    this.hardSets = 0,
    this.totalSets = 0,
    this.exercisesCount = 0,
    this.muscles = const [],
    this.prs = const [],
  });

  static FeedSnapshot? fromJson(Map<String, dynamic> json) {
    // schema_version 是快照结构的唯一契约；不认识的版本宁可降级也不猜。
    if (json['schema_version'] != 1) return null;
    return FeedSnapshot(
      schemaVersion: 1,
      sessionId: (json['session_id'] as num?)?.toInt(),
      startedAt: parseApiDateTimeOrNull(json['started_at']),
      completedAt: parseApiDateTimeOrNull(json['completed_at']),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      totalVolumeKg: (json['total_volume_kg'] as num?)?.toDouble() ?? 0,
      hardSets: (json['hard_sets'] as num?)?.toInt() ?? 0,
      totalSets: (json['total_sets'] as num?)?.toInt() ?? 0,
      exercisesCount: (json['exercises_count'] as num?)?.toInt() ?? 0,
      muscles: (json['muscles'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SnapshotMuscle.fromJson)
          .toList(),
      prs: (json['prs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SnapshotPr.fromJson)
          .toList(),
    );
  }

  final int schemaVersion;
  final int? sessionId;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? durationSeconds;
  final String? notes;
  final double totalVolumeKg;
  final int hardSets;
  final int totalSets;
  final int exercisesCount;
  final List<SnapshotMuscle> muscles;
  final List<SnapshotPr> prs;

  Duration? get duration {
    final seconds = durationSeconds;
    return seconds == null || seconds <= 0 ? null : Duration(seconds: seconds);
  }
}

/// 快照里的一个肌群（按容量降序，最多 5 条）。
class SnapshotMuscle {
  const SnapshotMuscle({required this.name, this.hardSets = 0, this.volume = 0});

  factory SnapshotMuscle.fromJson(Map<String, dynamic> json) {
    return SnapshotMuscle(
      name: json['name'] as String? ?? '',
      hardSets: (json['hard_sets'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
    );
  }

  final String name;
  final int hardSets;
  final double volume;
}

/// 快照里的一个 PR 高亮（每动作 e1RM 最高且超过历史最好的一组）。
class SnapshotPr {
  const SnapshotPr({
    required this.exerciseId,
    required this.exerciseName,
    this.setId,
    this.setNumber,
    this.weightKg,
    this.reps,
    this.rpe,
    this.estimated1rmKg,
    this.previousBestKg,
    this.improvementKg,
  });

  factory SnapshotPr.fromJson(Map<String, dynamic> json) {
    return SnapshotPr(
      exerciseId: (json['exercise_id'] as num?)?.toInt() ?? 0,
      exerciseName: json['exercise_name'] as String? ?? '',
      setId: (json['set_id'] as num?)?.toInt(),
      setNumber: (json['set_number'] as num?)?.toInt(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      reps: (json['reps'] as num?)?.toInt(),
      rpe: (json['rpe'] as num?)?.toDouble(),
      estimated1rmKg: (json['estimated_1rm_kg'] as num?)?.toDouble(),
      previousBestKg: (json['previous_best_kg'] as num?)?.toDouble(),
      improvementKg: (json['improvement_kg'] as num?)?.toDouble(),
    );
  }

  final int exerciseId;
  final String exerciseName;
  final int? setId;
  final int? setNumber;
  final double? weightKg;
  final int? reps;
  final double? rpe;
  final double? estimated1rmKg;
  final double? previousBestKg;
  final double? improvementKg;
}
