import 'package:app_flutter/features/stats/data/repositories/stats_repository.dart';
import 'package:app_flutter/features/stats/domain/entities/stats_overview.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 数据页周期：近 7 天 / 本月 / 近 90 天。
final statsPeriodDaysProvider = StateProvider<int>((ref) => 30);

/// 数据页总览。结束训练后随会话 id 变化刷新。
final statsOverviewProvider = FutureProvider.autoDispose<StatsOverview>((ref) async {
  ref.watch(trainingSessionProvider.select((async) => async.value?.sessionId));
  final days = ref.watch(statsPeriodDaysProvider);
  return ref.read(statsRepositoryProvider).getOverview(days: days);
});
