import 'package:app_flutter/features/training/domain/entities/exercise_stats.dart';

/// 一个区间里按时间排好的正重量样本。
class StrengthWindow {
  const StrengthWindow(this.samples);

  final List<StatsPoint> samples;

  StatsPoint? get first => samples.isEmpty ? null : samples.first;
  StatsPoint? get last => samples.isEmpty ? null : samples.last;
  StatsPoint? get previous =>
      samples.length < 2 ? null : samples[samples.length - 2];

  /// 最近一次相对上一次的公斤差。
  double? get sessionDelta => _delta(previous?.value, last?.value);

  /// 区间末相对区间初的公斤差。
  double? get rangeDelta => _delta(first?.value, last?.value);

  double? get sessionPercent => percentChange(previous?.value, last?.value);
  double? get rangePercent => percentChange(first?.value, last?.value);

  /// 相对区间第一笔的百分比，画图用。第一笔是 0。
  double percentAt(StatsPoint point) =>
      percentChange(first?.value, point.value) ?? 0;

  static double? _delta(double? from, double? to) {
    if (from == null || to == null) return null;
    return to - from;
  }
}

/// 已有点里最后一次刷新纪录：最好成绩，以及它出现之前的最好成绩。
class RecordMove {
  const RecordMove({this.best, this.previous, this.delta});

  final double? best;
  final double? previous;
  final double? delta;
}

RecordMove weightRecord(List<StatsPoint> points) {
  final live = [
    for (final point in points)
      if (point.value > 0) point,
  ]..sort((a, b) => a.at.compareTo(b.at));
  if (live.isEmpty) return const RecordMove();

  var best = live.first;
  for (final point in live.skip(1)) {
    if (point.value >= best.value) best = point;
  }
  double? previous;
  for (final point in live) {
    if (!point.at.isBefore(best.at)) continue;
    if (previous == null || point.value > previous) previous = point.value;
  }
  return RecordMove(
    best: best.value,
    previous: previous,
    delta: previous == null ? null : best.value - previous,
  );
}

/// 基准为 0 或缺失时没有百分比。
double? percentChange(double? from, double? to) {
  if (from == null || to == null || from == 0) return null;
  return (to - from) / from * 100;
}

/// 取 [now] 往前 [days] 个日历日内、重量大于 0 的点，按日期升序。
StrengthWindow strengthWindow({
  required List<StatsPoint> points,
  required DateTime now,
  required int days,
}) {
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: days - 1));
  final live = [
    for (final point in points)
      if (point.value > 0 && !point.at.isBefore(start)) point,
  ]..sort((a, b) => a.at.compareTo(b.at));
  return StrengthWindow(live);
}
