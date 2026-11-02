import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/data/repositories/session_repository.dart';
import 'package:app_flutter/features/training/domain/entities/exercise_stats.dart';
import 'package:app_flutter/features/training/domain/entities/one_rm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 动作数据图表。结束训练后随会话 id 变化刷新。
final exerciseStatsProvider = FutureProvider.autoDispose
    .family<ExerciseStats, int>((ref, exerciseId) {
      ref.watch(
        trainingSessionProvider.select((async) => async.value?.sessionId),
      );
      return ref
          .read(sessionRepositoryProvider)
          .getExerciseStats(exerciseId, days: 180);
    });

/// 动作估算 1RM（后端融合多样本）；暂无估算时为 null。结束训练后刷新。
final exerciseOneRmProvider = FutureProvider.autoDispose
    .family<OneRmEstimate?, int>((ref, exerciseId) {
      ref.watch(
        trainingSessionProvider.select((async) => async.value?.sessionId),
      );
      return ref.read(sessionRepositoryProvider).getOneRm(exerciseId);
    });

/// 由历史组反推的 1RM 时间序列。结束训练后刷新。
final exerciseOneRmHistoryProvider = FutureProvider.autoDispose
    .family<List<OneRmPoint>, int>((ref, exerciseId) {
      ref.watch(
        trainingSessionProvider.select((async) => async.value?.sessionId),
      );
      return ref.read(sessionRepositoryProvider).getOneRmHistory(exerciseId);
    });
