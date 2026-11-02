import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/data/repositories/session_repository.dart';
import 'package:app_flutter/features/training/domain/entities/session_record.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 训练日历：近一年已完成会话，按本地日历日分组。
final trainingCalendarProvider =
    FutureProvider.autoDispose<Map<DateTime, List<SessionRecord>>>((ref) async {
  ref.watch(trainingSessionProvider.select((async) => async.value?.sessionId));

  final now = DateTime.now();
  final page = await ref.read(sessionRepositoryProvider).listSessions(
        status: 'completed',
        startDate: DateTime(now.year - 1, now.month, now.day),
        limit: 100, // API le=100
      );

  final byDay = <DateTime, List<SessionRecord>>{};
  for (final session in page.items) {
    final local = session.startedAt.toLocal();
    final key = DateTime(local.year, local.month, local.day);
    byDay.putIfAbsent(key, () => []).add(session);
  }
  for (final list in byDay.values) {
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }
  return byDay;
});
