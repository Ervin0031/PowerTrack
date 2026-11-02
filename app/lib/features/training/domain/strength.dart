/// 1RM / 容量 / Deload。与后端 `app/services/strength.py` 一致。
library;

import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';

const int kEpleyRepMin = 1;
const int kEpleyRepMax = 10;
const double kHardSetRpe = 8.0;
const int kSampleWindow = 8;

double? epley1rm(double weightKg, int reps) {
  if (weightKg <= 0 || reps < kEpleyRepMin || reps > kEpleyRepMax) return null;
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

/// 优先 RPE 表；否则 1 次记实测，2–10 次走 Epley。
double? estimate1rm({double? weightKg, int? reps, double? rpe}) {
  if (weightKg == null || weightKg <= 0 || reps == null || reps < 1) {
    return null;
  }
  if (rpe != null) {
    final pct = percent1rm(reps, rpe);
    if (pct != null && pct >= 40) return weightKg * 100 / pct;
  }
  return epley1rm(weightKg, reps);
}

double? blendEstimates(List<double> samples, {int window = kSampleWindow}) {
  final recent = samples.length <= window
      ? samples
      : samples.sublist(samples.length - window);
  final valid = recent.where((x) => x > 0).toList()..sort();
  if (valid.isEmpty) return null;
  final mid = valid.length ~/ 2;
  if (valid.length.isOdd) return valid[mid];
  return (valid[mid - 1] + valid[mid]) / 2;
}

double rirFromRpe(double rpe) => (10 - rpe).clamp(0, 10);

class IntensityZone {
  const IntensityZone(
    this.low,
    this.high,
    this.repLow,
    this.repHigh,
    this.label,
  );

  final double low;
  final double high;
  final int repLow;
  final int repHigh;
  final String label;

  double get mid => (low + high) / 2;
}

IntensityZone intensityZone(String goal) {
  switch (goal) {
    case FitnessGoal.performance:
      return const IntensityZone(0.85, 0.95, 2, 5, '最大力量');
    case FitnessGoal.reshape:
      return const IntensityZone(0.75, 0.85, 5, 8, '力量与增肌');
    case FitnessGoal.muscleGain:
      return const IntensityZone(0.65, 0.75, 8, 12, '增肌');
    default:
      return const IntensityZone(0.55, 0.65, 12, 20, '肌耐力');
  }
}

double? workingWeight(double oneRmKg, String goal) {
  if (oneRmKg <= 0) return null;
  return roundToPlate(oneRmKg * intensityZone(goal).mid);
}

const double kKgToLb = 2.2046226218;

double toDisplayWeight(double kg, String unit) =>
    unit == 'lb' ? kg * kKgToLb : kg;

double fromDisplayWeight(double value, String unit) =>
    unit == 'lb' ? value / kKgToLb : value;

String weightUnitLabel(String unit) => unit == 'lb' ? 'lb' : 'kg';

double setVolume(double? weightKg, int? reps) {
  if (weightKg == null || reps == null || weightKg <= 0 || reps <= 0) return 0;
  return weightKg * reps;
}

bool isHardSet(double? rpe) => rpe != null && rpe >= kHardSetRpe;

double? estimated1rmFromExercise(TrainingExercise exercise) {
  final samples = <double>[];
  for (final s in exercise.sets) {
    if (s.completedAt == null) continue;
    final est = estimate1rm(weightKg: s.weightKg, reps: s.reps, rpe: s.rpe);
    if (est != null) samples.add(est);
  }
  for (final g in exercise.ghostSets) {
    final est = estimate1rm(weightKg: g.weightKg, reps: g.reps, rpe: g.rpe);
    if (est != null) samples.add(est);
  }
  return blendEstimates(samples);
}

const _largeMuscleEn = {
  'chest',
  'upper chest',
  'lower chest',
  'back',
  'lats',
  'upper back',
  'lower back',
  'quadriceps',
  'hamstrings',
  'glutes',
  'shoulders',
};

const _largeMuscleZh = {
  '胸部',
  '上胸部',
  '下胸部',
  '背部',
  '背阔肌',
  '上背部',
  '下背部',
  '股四头肌',
  '腘绳肌',
  '臀部',
  '肩部',
};

const double kLargeBaselineHours = 60;
const double kSmallBaselineHours = 36;
const int kEffectiveHardSets = 3;
const double kEffectiveAvgRpe = 7.5;
const double kRecoveryFactorMin = 0.6;
const double kRecoveryFactorMax = 1.4;

double baselineWindowHours({String name = '', String nameEn = ''}) {
  final en = nameEn.trim().toLowerCase();
  final zh = name.trim();
  if (_largeMuscleEn.contains(en) || _largeMuscleZh.contains(zh)) {
    return kLargeBaselineHours;
  }
  return kSmallBaselineHours;
}

bool isEffectiveSession(Iterable<double?> rpes) {
  final list = rpes.toList();
  final hard = list.where(isHardSet).length;
  if (hard < kEffectiveHardSets) return false;
  final recorded = list.whereType<double>().toList();
  if (recorded.isEmpty) return false;
  return recorded.reduce((a, b) => a + b) / recorded.length >= kEffectiveAvgRpe;
}

double recoveryProgress(double hoursSinceLast, double recoveryWindowHours) {
  if (recoveryWindowHours <= 0) return 1;
  return hoursSinceLast / recoveryWindowHours;
}

double clampRecoveryFactor(double value) =>
    value.clamp(kRecoveryFactorMin, kRecoveryFactorMax).toDouble();

String recoveryConfidence(int observationsCount) {
  if (observationsCount >= 20) return 'high';
  if (observationsCount >= 5) return 'medium';
  return 'low';
}
