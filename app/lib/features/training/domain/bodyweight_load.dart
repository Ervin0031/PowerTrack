import 'package:app_flutter/features/training/domain/entities/training_session.dart';

/// 徒手动作重量格展示文案（不写入 kg）。
const String kBodyweightLoadLabel = '自重';

/// 徒手动作未填重量时，写入用户体重（kg）。已有有效重量（含负重）不覆盖。
List<TrainingSet> fillBodyweightIfMissing(List<TrainingSet> sets, double? bodyKg) {
  if (bodyKg == null || bodyKg <= 0) return sets;
  return [
    for (final s in sets)
      (s.weightKg == null || s.weightKg! <= 0) ? s.copyWith(weightKg: bodyKg) : s,
  ];
}

/// 新增一组时：沿用上一组有效重量，否则徒手动作回退到用户体重。
double? copyOrBodyweightKg({
  required bool isBodyweight,
  double? previousKg,
  double? bodyKg,
}) {
  if (previousKg != null && previousKg > 0) return previousKg;
  if (isBodyweight && bodyKg != null && bodyKg > 0) return bodyKg;
  return previousKg;
}
