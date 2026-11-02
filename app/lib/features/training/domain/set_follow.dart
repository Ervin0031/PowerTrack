import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';

/// 新增一组时沿用上一组重量。上一组已力竭且自动降重开启时，按同一次建议降重。
double? copiedWeightAfterPrevious({
  double? previousKg,
  int? previousReps,
  DateTime? previousCompletedAt,
  double? previousRpe,
  String exerciseType = 'compound',
  String? goal,
  List<double> priorRpes = const [],
  String unit = 'kg',
  required bool autoReduce,
}) {
  if (previousKg == null) return null;
  if (!autoReduce ||
      previousCompletedAt == null ||
      (previousRpe ?? 0) < kRpeFailure) {
    return previousKg;
  }
  final advice = recommendNextSet(
    weightKg: previousKg,
    rpe: previousRpe!,
    reps: previousReps,
    exerciseType: exerciseType,
    priorRpes: priorRpes,
    goal: goal,
    unit: unit,
  );
  return advice.suggestedWeightKg ?? previousKg;
}

/// 重量是否视为同一个值。空和空相同；相差小于 0.001kg 视为相同。
bool sameSetWeight(double? a, double? b) {
  if (a == null || b == null) return a == null && b == null;
  return (a - b).abs() < 0.001;
}

/// 替换被编辑的组，并让还没完成、且该字段仍等于旧值的组跟着变。
///
/// 已经填成别的数、或已经完成的组保持原样。前面和后面的组都算。
List<TrainingSet> patchSetMatching({
  required List<TrainingSet> sets,
  required TrainingSet edited,
  required int? previousReps,
  required double? previousWeightKg,
  bool followReps = false,
  bool followWeight = false,
}) {
  return [
    for (final s in sets)
      if (s.setNumber == edited.setNumber)
        edited
      else if (s.completedAt != null)
        s
      else
        s.copyWith(
          reps: followReps && s.reps == previousReps ? edited.reps : s.reps,
          weightKg: followWeight && sameSetWeight(s.weightKg, previousWeightKg)
              ? edited.weightKg
              : s.weightKg,
          suggestedWeightKg: followWeight && sameSetWeight(s.weightKg, previousWeightKg)
              ? null
              : s.suggestedWeightKg,
        ),
  ];
}

/// 替换被编辑的组；可选地把次数/重量同步到之后未完成的同类型组。
List<TrainingSet> patchSetAndFollow({
  required List<TrainingSet> sets,
  required TrainingSet edited,
  bool followReps = false,
  bool followWeight = false,
}) {
  return [
    for (final s in sets)
      if (s.setNumber == edited.setNumber)
        edited
      else if ((followReps || followWeight) &&
          s.completedAt == null &&
          s.setNumber > edited.setNumber &&
          s.setKind == edited.setKind)
        s.copyWith(
          reps: followReps ? edited.reps : s.reps,
          weightKg: followWeight ? edited.weightKg : s.weightKg,
          suggestedWeightKg: followWeight ? null : s.suggestedWeightKg,
        )
      else
        s,
  ];
}
