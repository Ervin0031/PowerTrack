/// 本周相对上一周的容量变化，四舍五入到整数百分比。
///
/// 没有上一周，或上周容量 ≤ 0 时返回 null，调用方不显示百分比。
int? weekVolumeDeltaPercent({required double? previousWeek, required double thisWeek}) {
  if (previousWeek == null || previousWeek <= 0) return null;
  return ((thisWeek - previousWeek) / previousWeek * 100).round();
}

/// `▲ 12%` / `▼ 8%` / `与上周持平`。百分比为 null 时返回 null。
String? weekVolumeDeltaLabel(int? percent) {
  if (percent == null) return null;
  if (percent == 0) return '与上周持平';
  final arrow = percent > 0 ? '▲' : '▼';
  return '$arrow ${percent.abs()}%';
}
