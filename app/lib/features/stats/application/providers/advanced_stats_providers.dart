import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/stats/data/repositories/stats_repository.dart';
import 'package:app_flutter/features/stats/domain/entities/strength_standards.dart';
import 'package:app_flutter/features/stats/domain/entities/volume_landmarks.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 本周肌群容量地标（固定「本周」，与数据页周期开关无关）。结束训练后刷新。
final volumeLandmarksProvider = FutureProvider.autoDispose<VolumeLandmarks>((ref) {
  ref.watch(trainingSessionProvider.select((async) => async.value?.sessionId));
  return ref.read(statsRepositoryProvider).getVolumeLandmarks();
});

/// 相对力量与体型对称度。结束训练或体重变化后刷新（倍体重比依赖当前体重）。
final strengthStandardsProvider = FutureProvider.autoDispose<StrengthStandards>((ref) {
  ref.watch(trainingSessionProvider.select((async) => async.value?.sessionId));
  ref.watch(fitnessProfileProvider.select((async) => async.value?.weightKg));
  return ref.read(statsRepositoryProvider).getStrengthStandards();
});
