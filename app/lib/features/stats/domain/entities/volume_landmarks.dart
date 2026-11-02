/// 本周肌群容量地标 MEV/MAV/MRV（纯 Dart，对应 `GET /volume/landmarks`）。
///
/// 只统计填写了 RPE≥8 的组（hard set）；常量表未收录的肌群由后端用保守默认值
/// 兜底并标记 [VolumeLandmarkItem.isDefault]。
class VolumeLandmarks {
  const VolumeLandmarks({
    required this.weekStart,
    required this.weekVolume,
    required this.hardSets,
    this.items = const [],
  });

  factory VolumeLandmarks.fromJson(Map<String, dynamic> json) {
    return VolumeLandmarks(
      weekStart: json['week_start'] as String? ?? '',
      weekVolume: (json['week_volume'] as num?)?.toDouble() ?? 0,
      hardSets: (json['hard_sets'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VolumeLandmarkItem.fromJson)
          .toList(),
    );
  }

  final String weekStart;
  final double weekVolume;
  final int hardSets;
  final List<VolumeLandmarkItem> items;

  bool get isEmpty => items.isEmpty;
}

class VolumeLandmarkItem {
  const VolumeLandmarkItem({
    required this.name,
    required this.hardSets,
    required this.zone,
    required this.mv,
    required this.mev,
    required this.mavLow,
    required this.mavHigh,
    required this.mrv,
    this.isDefault = false,
  });

  factory VolumeLandmarkItem.fromJson(Map<String, dynamic> json) {
    return VolumeLandmarkItem(
      name: json['name'] as String? ?? '',
      hardSets: (json['hard_sets'] as num?)?.toInt() ?? 0,
      zone: json['zone'] as String? ?? 'below_mev',
      mv: (json['mv'] as num?)?.toInt() ?? 0,
      mev: (json['mev'] as num?)?.toInt() ?? 0,
      mavLow: (json['mav_low'] as num?)?.toInt() ?? 0,
      mavHigh: (json['mav_high'] as num?)?.toInt() ?? 0,
      mrv: (json['mrv'] as num?)?.toInt() ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  final String name;
  final int hardSets;

  /// `below_mev` / `mev` / `mav` / `above_mrv`。
  final String zone;
  final int mv;
  final int mev;
  final int mavLow;
  final int mavHigh;
  final int mrv;
  final bool isDefault;

  String get zoneLabel => switch (zone) {
        'below_mev' => '低于 MEV',
        'mev' => '维持量',
        'mav' => '最佳适应区',
        'above_mrv' => '超出 MRV',
        _ => zone,
      };

  /// 距 MAV 区间（[mavLow], [mavHigh]）的完成度，用于进度条（0–1，超出截断）。
  double get mavProgress {
    final target = mavHigh > 0 ? mavHigh : 1;
    return (hardSets / target).clamp(0.0, 1.0);
  }
}
