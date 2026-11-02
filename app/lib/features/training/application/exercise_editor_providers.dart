import 'package:app_flutter/features/training/application/exercise_editor.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前展开的动作 id。默认读进行中会话；模板编辑页覆盖为草稿。
final focusedExerciseIdProvider = Provider<int?>((ref) {
  return ref.watch(trainingSessionProvider.select((async) => async.value?.focusedExerciseId));
});

/// 动作列表编辑命令。默认走训练会话；模板编辑页覆盖为草稿 notifier。
final exerciseListEditorProvider = Provider<ExerciseListEditor>((ref) {
  return ref.read(trainingSessionProvider.notifier);
});

/// 当前列表里已有的动作 id，供选择库禁用重复添加。
///
/// 只订阅 id 列表。完成组会改次数和重量；若整份会话都订阅，每次写入都会再排一次
/// Provider 刷新，碰上还没跑完的调度就会断言「同一时间只能排一个任务」。
final editorExerciseIdsProvider = Provider<Set<int>>((ref) {
  final key = ref.watch(
    trainingSessionProvider.select((async) {
      final exercises = async.value?.exercises;
      if (exercises == null || exercises.isEmpty) return '';
      final ids = exercises.map((e) => e.exerciseId).toList()..sort();
      return ids.join(',');
    }),
  );
  if (key.isEmpty) return const <int>{};
  return key.split(',').map(int.parse).toSet();
});
