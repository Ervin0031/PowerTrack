import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/data/repositories/session_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 训练首页容量：结束训练后随会话 id 变化刷新。
final weeklyVolumeProvider = FutureProvider<WeeklyVolumeSummary>((ref) async {
  ref.watch(trainingSessionProvider.select((async) => async.value?.sessionId));
  return ref.read(sessionRepositoryProvider).getWeeklyVolume();
});
