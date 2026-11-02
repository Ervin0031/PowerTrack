import 'package:app_flutter/core/network/api_datetime.dart';

/// 肌群恢复状态（纯 Dart，对应 `GET /muscle-groups/status`）。
class MuscleGroupStatus {
  const MuscleGroupStatus({
    required this.muscleGroupId,
    required this.name,
    required this.nameEn,
    required this.category,
    required this.lastTrainedAt,
    required this.hoursSinceLast,
    required this.recoveryProgress,
    required this.recoveryWindowHours,
    required this.baselineWindowHours,
    required this.recoveryFactor,
    required this.globalFactor,
    required this.muscleFactor,
    required this.recoveryConfidence,
    required this.observationsCount,
  });

  factory MuscleGroupStatus.fromJson(Map<String, dynamic> json) {
    return MuscleGroupStatus(
      muscleGroupId: (json['muscle_group_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      category: json['category'] as String? ?? '',
      lastTrainedAt: parseApiDateTimeOrNull(json['last_trained_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      hoursSinceLast: (json['hours_since_last'] as num?)?.toDouble() ?? 0,
      recoveryProgress: (json['recovery_progress'] as num?)?.toDouble() ?? 0,
      recoveryWindowHours: (json['recovery_window_hours'] as num?)?.toDouble() ?? 0,
      baselineWindowHours: (json['baseline_window_hours'] as num?)?.toDouble() ?? 0,
      recoveryFactor: (json['recovery_factor'] as num?)?.toDouble() ?? 1,
      globalFactor: (json['global_factor'] as num?)?.toDouble() ?? 1,
      muscleFactor: (json['muscle_factor'] as num?)?.toDouble() ?? 1,
      recoveryConfidence: json['recovery_confidence'] as String? ?? 'low',
      observationsCount: (json['observations_count'] as num?)?.toInt() ?? 0,
    );
  }

  final int muscleGroupId;
  final String name;
  final String nameEn;
  final String category;
  final DateTime lastTrainedAt;
  final double hoursSinceLast;
  final double recoveryProgress;
  final double recoveryWindowHours;
  final double baselineWindowHours;
  final double recoveryFactor;
  final double globalFactor;
  final double muscleFactor;
  final String recoveryConfidence;
  final int observationsCount;

  bool get isRecovered => recoveryProgress >= 1;

  double get ringValue {
    if (recoveryProgress <= 0) return 0.02;
    if (recoveryProgress >= 1) return 1;
    return recoveryProgress;
  }

  int get hoursUntilReady {
    final remain = recoveryWindowHours - hoursSinceLast;
    if (remain <= 0) return 0;
    return remain.ceil();
  }

  /// 行为推断文案。样本不足或偏离不到 5% 时不展示速度对比。
  String? get inferredSpeedLabel {
    if (recoveryConfidence == 'low') return null;
    final pct = ((1 - recoveryFactor) * 100).round();
    if (pct.abs() < 5) return null;
    if (pct > 0) return '根据训练历史推断，恢复比平均快 $pct%';
    return '根据训练历史推断，恢复比平均慢 ${-pct}%';
  }

  String get subtitle {
    final speed = inferredSpeedLabel;
    if (isRecovered) {
      return speed ?? '根据训练历史推断 · 已恢复';
    }
    final wait = hoursUntilReady;
    final waitLabel = wait >= 24 ? '约 ${(wait / 24).ceil()} 天后可再练' : '约 $wait 小时后可再练';
    if (speed != null) return '$speed · $waitLabel';
    return '根据训练历史推断 · $waitLabel';
  }

  String get valueLabel => isRecovered ? '已恢复' : '${(recoveryProgress * 100).clamp(0, 99).round()}%';
}

class MuscleGroupStatusSummary {
  const MuscleGroupStatusSummary({
    required this.items,
    required this.globalFactor,
    required this.globalObservationsCount,
    required this.globalConfidence,
  });

  factory MuscleGroupStatusSummary.fromJson(Map<String, dynamic> json) {
    return MuscleGroupStatusSummary(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MuscleGroupStatus.fromJson)
          .toList(),
      globalFactor: (json['global_factor'] as num?)?.toDouble() ?? 1,
      globalObservationsCount: (json['global_observations_count'] as num?)?.toInt() ?? 0,
      globalConfidence: json['global_confidence'] as String? ?? 'low',
    );
  }

  final List<MuscleGroupStatus> items;
  final double globalFactor;
  final int globalObservationsCount;
  final String globalConfidence;
}
