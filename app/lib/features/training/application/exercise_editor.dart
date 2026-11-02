import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/training/domain/entities/training_set_kind.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 动作卡片/组表格的编辑源。模板编辑页通过 [ProviderScope] 覆盖。
enum ExerciseEditorKind { session, template }

final exerciseEditorKindProvider = Provider<ExerciseEditorKind>(
  (_) => ExerciseEditorKind.session,
);

/// 训练会话与模板草稿共用的动作列表编辑接口。
abstract interface class ExerciseListEditor {
  Future<void> addExercises(List<Exercise> exercises, {int? supersetId});

  Future<bool> replaceExercise(int oldId, Exercise next);

  void removeExercise(int exerciseId);

  void toggleExerciseExpanded(int exerciseId);

  void addSet(int exerciseId);

  void removeSet(int exerciseId, int setNumber);

  void updateExercise(
    int exerciseId, {
    Object? notes,
    Object? restTargetSeconds,
    String? weightUnit,
  });

  void updateSet(
    int exerciseId,
    int setNumber, {
    Object? reps,
    Object? weightKg,
    Object? restSeconds,
    Object? durationSeconds,
    Object? distanceMeters,
    Object? notes,
    TrainingSetKind? setKind,
    Object? rpe,
    Object? suggestedWeightKg,
    bool followRemaining = true,
    bool followMatching = false,
  });

  void updateAllSets(int exerciseId, {int? reps, double? weightKg});

  void applySuggestedWeight(int exerciseId, int setNumber);

  void toggleSetDone(int exerciseId, int setNumber);

  RpeFollowUp? completeSetWithRpe(int exerciseId, int setNumber, double rpe);

  void reduceRemainingWeights(int exerciseId);
}
