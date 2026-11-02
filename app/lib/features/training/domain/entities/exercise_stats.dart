import 'package:app_flutter/core/network/api_datetime.dart';

/// 动作数据图表（纯 Dart，对应 `GET /exercises/{id}/stats`）。
class ExerciseStats {
  const ExerciseStats({
    required this.exerciseId,
    required this.periodDays,
    required this.periodLabel,
    required this.axis,
    required this.maxWeight,
    required this.totalVolume,
    required this.maxReps,
    required this.totalReps,
    required this.records,
    required this.history,
  });

  factory ExerciseStats.fromJson(Map<String, dynamic> json) {
    return ExerciseStats(
      exerciseId: (json['exercise_id'] as num?)?.toInt() ?? 0,
      periodDays: (json['period_days'] as num?)?.toInt() ?? 30,
      periodLabel: json['period_label'] as String? ?? '上个月',
      axis: (json['axis'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      maxWeight: MetricSeries.fromJson(json['max_weight']),
      totalVolume: MetricSeries.fromJson(json['total_volume']),
      maxReps: MetricSeries.fromJson(json['max_reps']),
      totalReps: MetricSeries.fromJson(json['total_reps']),
      records: PersonalRecords.fromJson(json['records']),
      history: (json['history'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ExerciseHistorySession.fromJson)
          .toList(),
    );
  }

  final int exerciseId;
  final int periodDays;
  final String periodLabel;
  final List<String> axis;
  final MetricSeries maxWeight;
  final MetricSeries totalVolume;
  final MetricSeries maxReps;
  final MetricSeries totalReps;
  final PersonalRecords records;
  final List<ExerciseHistorySession> history;

  bool get isEmpty => records.sessionCount == 0;
}

class MetricSeries {
  const MetricSeries({this.value, this.points = const []});

  factory MetricSeries.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const MetricSeries();
    return MetricSeries(
      value: (json['value'] as num?)?.toDouble(),
      points: (json['points'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StatsPoint.fromJson)
          .toList(),
    );
  }

  final double? value;
  final List<StatsPoint> points;

  bool get hasData => value != null || points.any((p) => p.value > 0);
}

class StatsPoint {
  const StatsPoint({required this.at, required this.value});

  factory StatsPoint.fromJson(Map<String, dynamic> json) {
    return StatsPoint(
      at: parseChartDate(json['t'] as String? ?? ''),
      value: (json['v'] as num?)?.toDouble() ?? 0,
    );
  }

  final DateTime at;
  final double value;
}

/// 图表用日历日，避免 `2026-08-12` 被解析成 UTC 午夜后错日。
DateTime parseChartDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

class PersonalRecords {
  const PersonalRecords({
    this.maxWeightKg,
    this.maxWeightAt,
    this.maxReps,
    this.maxRepsAt,
    this.maxSetVolume,
    this.maxSetVolumeAt,
    this.estimated1rmKg,
    this.sessionCount = 0,
    this.firstAt,
    this.lastAt,
  });

  factory PersonalRecords.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const PersonalRecords();
    return PersonalRecords(
      maxWeightKg: (json['max_weight_kg'] as num?)?.toDouble(),
      maxWeightAt: _parseTime(json['max_weight_at']),
      maxReps: (json['max_reps'] as num?)?.toInt(),
      maxRepsAt: _parseTime(json['max_reps_at']),
      maxSetVolume: (json['max_set_volume'] as num?)?.toDouble(),
      maxSetVolumeAt: _parseTime(json['max_set_volume_at']),
      estimated1rmKg: (json['estimated_1rm_kg'] as num?)?.toDouble(),
      sessionCount: (json['session_count'] as num?)?.toInt() ?? 0,
      firstAt: _parseTime(json['first_at']),
      lastAt: _parseTime(json['last_at']),
    );
  }

  final double? maxWeightKg;
  final DateTime? maxWeightAt;
  final int? maxReps;
  final DateTime? maxRepsAt;
  final double? maxSetVolume;
  final DateTime? maxSetVolumeAt;
  final double? estimated1rmKg;
  final int sessionCount;
  final DateTime? firstAt;
  final DateTime? lastAt;
}

class ExerciseHistorySession {
  const ExerciseHistorySession({
    required this.sessionId,
    required this.startedAt,
    this.completedAt,
    this.sets = const [],
  });

  factory ExerciseHistorySession.fromJson(Map<String, dynamic> json) {
    return ExerciseHistorySession(
      sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
      startedAt: _parseTime(json['started_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: _parseTime(json['completed_at']),
      sets: (json['sets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ExerciseHistorySet.fromJson)
          .toList(),
    );
  }

  final int sessionId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<ExerciseHistorySet> sets;
}

class ExerciseHistorySet {
  const ExerciseHistorySet({
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.rpe,
    this.notes,
  });

  factory ExerciseHistorySet.fromJson(Map<String, dynamic> json) {
    return ExerciseHistorySet(
      setNumber: (json['set_number'] as num?)?.toInt() ?? 0,
      reps: (json['reps'] as num?)?.toInt(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      rpe: (json['rpe'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  final int setNumber;
  final int? reps;
  final double? weightKg;
  final double? rpe;
  final String? notes;
}

DateTime? _parseTime(dynamic value) => parseApiDateTimeOrNull(value);
