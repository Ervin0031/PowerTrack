import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/data/repositories/session_repository.dart';
import 'package:app_flutter/features/training/domain/entities/muscle_group_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 训练首页肌群恢复：结束训练后随会话 id 变化刷新。
final muscleGroupStatusProvider = FutureProvider<MuscleGroupStatusSummary>((ref) async {
  ref.watch(trainingSessionProvider.select((async) => async.value?.sessionId));
  return ref.read(sessionRepositoryProvider).getMuscleGroupStatus();
});
