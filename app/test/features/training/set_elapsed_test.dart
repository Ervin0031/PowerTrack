import 'package:app_flutter/features/training/domain/set_elapsed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('没有更早的完成时，用本组起点', () {
    final now = DateTime.utc(2026, 1, 1, 1);
    expect(
      setElapsedSeconds(
        startedAt: now.subtract(const Duration(seconds: 40)),
        now: now,
        otherCompletedAt: const [],
      ),
      40,
    );
  });

  test('加入列表时的起点早于上一组完成，改从上一组完成算', () {
    final added = DateTime.utc(2026, 1, 1, 0);
    final previous = DateTime.utc(2026, 1, 1, 1);
    final now = previous.add(const Duration(seconds: 90));
    expect(
      setElapsedSeconds(
        startedAt: added,
        now: now,
        otherCompletedAt: [previous],
      ),
      90,
    );
  });

  test('还没开表也没有上一组时不记耗时', () {
    expect(
      setElapsedSeconds(
        startedAt: null,
        now: DateTime.utc(2026),
        otherCompletedAt: const [null],
      ),
      isNull,
    );
  });
}
