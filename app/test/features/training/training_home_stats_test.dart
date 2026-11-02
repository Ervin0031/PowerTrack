import 'package:app_flutter/features/training/domain/entities/session_record.dart';
import 'package:app_flutter/features/training/domain/entities/training_home_stats.dart';
import 'package:flutter_test/flutter_test.dart';

SessionRecord _session(DateTime startedAt, {int id = 1}) {
  return SessionRecord(
    id: id,
    clientUuid: 'u-$id',
    status: 'completed',
    startedAt: startedAt,
    completedAt: startedAt.add(const Duration(hours: 1)),
  );
}

void main() {
  // 固定「本周三」：2026-09-02
  final now = DateTime(2026, 9, 2, 12);
  final weekStart = DateTime(2026, 8, 31); // Monday

  test('startOfWeek 对齐到周一', () {
    expect(TrainingHomeStats.startOfWeek(now), weekStart);
    expect(TrainingHomeStats.startOfWeek(DateTime(2026, 8, 31)), weekStart);
    expect(TrainingHomeStats.startOfWeek(DateTime(2026, 9, 6)), weekStart);
  });

  test('本周训练日与次数', () {
    final stats = TrainingHomeStats.fromSessions(
      [
        _session(DateTime(2026, 8, 31, 10), id: 1), // Mon
        _session(DateTime(2026, 9, 2, 18), id: 2), // Wed
        _session(DateTime(2026, 8, 24, 10), id: 3), // previous week
      ],
      now: now,
      weeklyGoal: 4,
    );

    expect(stats.sessionsThisWeek, 2);
    expect(stats.trainedThisWeek, [true, false, true, false, false, false, false]);
    expect(stats.weekProgress, 0.5);
    expect(stats.lastCompleted?.id, 2);
  });

  test('本周无训练时连续周从上周起算', () {
    final stats = TrainingHomeStats.fromSessions(
      [
        _session(DateTime(2026, 8, 25, 10), id: 1), // last Tue
        _session(DateTime(2026, 8, 18, 10), id: 2), // week before
      ],
      now: now,
    );

    expect(stats.sessionsThisWeek, 0);
    expect(stats.weekStreak, 2);
  });

  test('连续周在中间断掉时停止', () {
    final stats = TrainingHomeStats.fromSessions(
      [
        _session(DateTime(2026, 9, 1, 10), id: 1), // this week
        _session(DateTime(2026, 8, 18, 10), id: 2), // skip last week
      ],
      now: now,
    );

    expect(stats.weekStreak, 1);
  });

  test('无历史时全零', () {
    final stats = TrainingHomeStats.fromSessions(const [], now: now);
    expect(stats.sessionsThisWeek, 0);
    expect(stats.weekStreak, 0);
    expect(stats.lastCompleted, isNull);
    expect(stats.trainedThisWeek.every((e) => !e), isTrue);
  });
}
