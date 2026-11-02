import 'package:app_flutter/core/network/api_datetime.dart';

/// 某动作的 1RM 估算（纯 Dart，对应 `GET /exercises/{id}/one-rm`）。
///
/// 后端已融合多样本；[needsRecalibrate] 为 true 表示样本与新表现偏离，建议重新校准。
class OneRmEstimate {
  const OneRmEstimate({
    required this.exerciseId,
    required this.estimatedKg,
    this.needsRecalibrate = false,
    this.samplesCount = 0,
  });

  factory OneRmEstimate.fromJson(Map<String, dynamic> json) {
    return OneRmEstimate(
      exerciseId: (json['exercise_id'] as num?)?.toInt() ?? 0,
      estimatedKg: (json['estimated_kg'] as num?)?.toDouble() ?? 0,
      needsRecalibrate: json['needs_recalibrate'] as bool? ?? false,
      samplesCount: (json['samples_count'] as num?)?.toInt() ?? 0,
    );
  }

  final int exerciseId;
  final double estimatedKg;
  final bool needsRecalibrate;
  final int samplesCount;
}

/// 由历史组反推的 1RM 时间序列点（`GET /exercises/{id}/one-rm/history`）。
class OneRmPoint {
  const OneRmPoint({required this.date, required this.estimatedKg, this.rpe});

  factory OneRmPoint.fromJson(Map<String, dynamic> json) {
    return OneRmPoint(
      date: parseApiDateTimeOrNull(json['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      estimatedKg: (json['estimated_kg'] as num?)?.toDouble() ?? 0,
      rpe: (json['rpe'] as num?)?.toDouble(),
    );
  }

  final DateTime date;
  final double estimatedKg;
  final double? rpe;
}
