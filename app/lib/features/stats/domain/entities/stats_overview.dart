import 'package:app_flutter/core/network/api_datetime.dart';

/// 数据页总览（纯 Dart，对应 `GET /stats/overview`）。
class StatsOverview {
  const StatsOverview({
    required this.periodDays,
    required this.periodLabel,
    required this.sessionsCount,
    required this.totalVolumeKg,
    required this.totalDurationSeconds,
    required this.hardSets,
    this.avgRpe,
    this.trainedDays = const [],
    this.byMuscle = const [],
    this.recentPrs = const [],
    this.topExercises = const [],
  });

  factory StatsOverview.fromJson(Map<String, dynamic> json) {
    return StatsOverview(
      periodDays: (json['period_days'] as num?)?.toInt() ?? 30,
      periodLabel: json['period_label'] as String? ?? '',
      sessionsCount: (json['sessions_count'] as num?)?.toInt() ?? 0,
      totalVolumeKg: (json['total_volume_kg'] as num?)?.toDouble() ?? 0,
      totalDurationSeconds: (json['total_duration_seconds'] as num?)?.toInt() ?? 0,
      avgRpe: (json['avg_rpe'] as num?)?.toDouble(),
      hardSets: (json['hard_sets'] as num?)?.toInt() ?? 0,
      trainedDays: (json['trained_days'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      byMuscle: (json['by_muscle'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StatsMuscleVolume.fromJson)
          .toList(),
      recentPrs: (json['recent_prs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StatsRecentPr.fromJson)
          .toList(),
      topExercises: (json['top_exercises'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StatsTopExercise.fromJson)
          .toList(),
    );
  }

  final int periodDays;
  final String periodLabel;
  final int sessionsCount;
  final double totalVolumeKg;
  final int totalDurationSeconds;
  final double? avgRpe;
  final int hardSets;
  final List<String> trainedDays;
  final List<StatsMuscleVolume> byMuscle;
  final List<StatsRecentPr> recentPrs;
  final List<StatsTopExercise> topExercises;

  bool get isEmpty => sessionsCount == 0;

  Set<DateTime> get trainedDaySet {
    return {
      for (final raw in trainedDays)
        if (DateTime.tryParse(raw) case final parsed?)
          DateTime(parsed.year, parsed.month, parsed.day),
    };
  }
}

class StatsMuscleVolume {
  const StatsMuscleVolume({
    required this.name,
    required this.volume,
    required this.hardSets,
  });

  factory StatsMuscleVolume.fromJson(Map<String, dynamic> json) {
    return StatsMuscleVolume(
      name: json['name'] as String? ?? '',
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
      hardSets: (json['hard_sets'] as num?)?.toInt() ?? 0,
    );
  }

  final String name;
  final double volume;
  final int hardSets;
}

class StatsRecentPr {
  const StatsRecentPr({
    required this.exerciseId,
    required this.name,
    required this.kind,
    required this.value,
    required this.at,
  });

  factory StatsRecentPr.fromJson(Map<String, dynamic> json) {
    return StatsRecentPr(
      exerciseId: (json['exercise_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'max_weight',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      at: parseApiDateTimeOrNull(json['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final int exerciseId;
  final String name;
  final String kind;
  final double value;
  final DateTime at;

  String get kindLabel => switch (kind) {
        'max_weight' => '最大重量',
        'max_reps' => '最大次数',
        'max_set_volume' => '单组容量',
        _ => kind,
      };
}

class StatsTopExercise {
  const StatsTopExercise({
    required this.exerciseId,
    required this.name,
    required this.sessions,
    required this.volume,
    this.estimated1rmKg,
  });

  factory StatsTopExercise.fromJson(Map<String, dynamic> json) {
    return StatsTopExercise(
      exerciseId: (json['exercise_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
      estimated1rmKg: (json['estimated_1rm_kg'] as num?)?.toDouble(),
    );
  }

  final int exerciseId;
  final String name;
  final int sessions;
  final double volume;
  final double? estimated1rmKg;
}
