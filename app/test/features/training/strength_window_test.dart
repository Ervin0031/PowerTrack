import 'package:app_flutter/features/training/domain/entities/exercise_stats.dart';
import 'package:app_flutter/features/training/domain/strength_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final points = [
    StatsPoint(at: DateTime(2026, 9, 1), value: 80),
    StatsPoint(at: DateTime(2026, 9, 8), value: 0),
    StatsPoint(at: DateTime(2026, 9, 15), value: 84),
    StatsPoint(at: DateTime(2026, 10, 1), value: 82),
  ];

  test('区间丢掉零重量并按日期排序', () {
    final window = strengthWindow(
      points: points.reversed.toList(),
      now: DateTime(2026, 10, 22),
      days: 180,
    );
    expect(window.samples.map((p) => p.value).toList(), [80, 84, 82]);
    expect(window.sessionDelta, -2);
    expect(window.rangeDelta, 2);
    expect(window.rangePercent, closeTo(2.5, 0.001));
    expect(window.percentAt(window.samples[1]), closeTo(5, 0.001));
  });

  test('重量纪录取最后一次最高，并对比它之前的最好成绩', () {
    final move = weightRecord(points);
    expect(move.best, 84);
    expect(move.previous, 80);
    expect(move.delta, 4);
  });

  test('短区间只留窗口内的点', () {
    final window = strengthWindow(
      points: points,
      now: DateTime(2026, 10, 22),
      days: 30,
    );
    expect(window.samples.single.value, 82);
    expect(window.sessionDelta, isNull);
    expect(percentChange(0, 10), isNull);
  });
}
