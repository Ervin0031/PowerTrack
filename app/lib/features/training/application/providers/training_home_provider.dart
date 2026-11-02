import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/data/repositories/session_repository.dart';
import 'package:app_flutter/features/training/domain/entities/training_home_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'training_home_provider.g.dart';

/// 训练首页统计：拉取近 12 周已完成会话并聚合。
///
/// 监听进行中会话 id，结束训练后自动刷新。
@riverpod
Future<TrainingHomeStats> trainingHome(Ref ref) async {
  ref.watch(trainingSessionProvider.select((async) => async.value?.sessionId));

  final now = DateTime.now();
  final start = TrainingHomeStats.startOfWeek(now).subtract(const Duration(days: 7 * 11));
  final page = await ref.read(sessionRepositoryProvider).listSessions(
        status: 'completed',
        startDate: start,
        limit: 100,
      );
  return TrainingHomeStats.fromSessions(page.items, now: now);
}
