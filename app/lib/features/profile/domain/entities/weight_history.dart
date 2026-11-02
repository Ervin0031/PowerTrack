import 'package:app_flutter/features/training/domain/entities/exercise_stats.dart' show parseChartDate;

/// 体重流水与 7 日移动平均（纯 Dart，对应 `GET /users/me/weight-history`）。
///
/// 体重只在档案值变化时写入，数据点天然稀疏；从未提交档案时 [points] 为空。
class WeightHistory {
  const WeightHistory({
    required this.periodDays,
    this.points = const [],
    this.changeKg,
    this.records = 0,
  });

  factory WeightHistory.fromJson(Map<String, dynamic> json) {
    return WeightHistory(
      periodDays: (json['period_days'] as num?)?.toInt() ?? 0,
      points: (json['points'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WeightPoint.fromJson)
          .toList(),
      changeKg: (json['change_kg'] as num?)?.toDouble(),
      records: (json['records'] as num?)?.toInt() ?? 0,
    );
  }

  final int periodDays;
  final List<WeightPoint> points;

  /// 窗口首末体重差（kg）；样本不足时为 null。
  final double? changeKg;
  final int records;

  bool get isEmpty => points.isEmpty;
}

class WeightPoint {
  const WeightPoint({required this.date, required this.weightKg, this.ma7Kg});

  factory WeightPoint.fromJson(Map<String, dynamic> json) {
    return WeightPoint(
      // 后端给的是纯日期 `yyyy-MM-dd`，按日历日解析，避免被当成 UTC 后错日。
      date: parseChartDate(json['date'] as String? ?? ''),
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      ma7Kg: (json['ma7_kg'] as num?)?.toDouble(),
    );
  }

  final DateTime date;
  final double weightKg;

  /// 7 日前向填充移动平均；点太少时后端可能不给。
  final double? ma7Kg;
}
