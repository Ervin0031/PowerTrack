import 'package:app_flutter/features/training/domain/entities/session_record.dart';

/// 训练首页聚合统计（纯 Dart，便于单测）。
class TrainingHomeStats {
  const TrainingHomeStats({
    required this.trainedThisWeek,
    required this.sessionsThisWeek,
    required this.weekStreak,
    required this.weeklyGoal,
    this.lastCompleted,
  });

  /// 本周一至周日是否有已完成训练（长度 7）。
  final List<bool> trainedThisWeek;

  /// 本周已完成会话数。
  final int sessionsThisWeek;

  /// 连续有训练的周数（本周为空时从上周起算）。
  final int weekStreak;

  /// 本周目标次数（用于进度环，软目标）。
  final int weeklyGoal;

  /// 最近一次已完成会话。
  final SessionRecord? lastCompleted;

  double get weekProgress {
    if (weeklyGoal <= 0) return 0;
    final p = sessionsThisWeek / weeklyGoal;
    return p.clamp(0.0, 1.0);
  }

  /// 由已完成会话列表聚合首页数据。
  ///
  /// [now] 可注入以便单测；[weeklyGoal] 默认 4。
  static TrainingHomeStats fromSessions(
    List<SessionRecord> sessions, {
    DateTime? now,
    int weeklyGoal = 4,
  }) {
    final clock = now ?? DateTime.now();
    final completed = sessions.where((s) => s.status == 'completed').toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final weekStart = startOfWeek(clock);
    final trained = List<bool>.filled(7, false);
    var sessionsThisWeek = 0;

    for (final s in completed) {
      final local = s.startedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (day.isBefore(weekStart)) continue;
      if (day.isAfter(weekStart.add(const Duration(days: 6)))) continue;
      final index = day.difference(weekStart).inDays;
      if (index >= 0 && index < 7) {
        trained[index] = true;
        sessionsThisWeek++;
      }
    }

    return TrainingHomeStats(
      trainedThisWeek: trained,
      sessionsThisWeek: sessionsThisWeek,
      weekStreak: computeWeekStreak(completed, clock),
      weeklyGoal: weeklyGoal,
      lastCompleted: completed.isEmpty ? null : completed.first,
    );
  }

  /// 当天所在周的周一 00:00（本地时区）。
  static DateTime startOfWeek(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  /// 连续有训练的周数。
  ///
  /// 若本周尚无训练，从上周开始往前数，避免周中打开 App 就把 streak 清零。
  static int computeWeekStreak(List<SessionRecord> completed, DateTime now) {
    if (completed.isEmpty) return 0;

    final weekKeys = <DateTime>{};
    for (final s in completed) {
      weekKeys.add(startOfWeek(s.startedAt.toLocal()));
    }

    var cursor = startOfWeek(now);
    if (!weekKeys.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 7));
    }

    var streak = 0;
    while (weekKeys.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 7));
    }
    return streak;
  }
}
