/// BMR / TDEE / 最大心率。与后端 `app/services/metrics.py` 一致。
library;

import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';

int ageFromBirthYear(int birthYear, {DateTime? now}) {
  final year = (now ?? DateTime.now()).year;
  final age = year - birthYear;
  if (age < 8) return 8;
  if (age > 100) return 100;
  return age;
}

double bmrMifflin({
  required double weightKg,
  required double heightCm,
  required int age,
  required String gender,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  final male = base + 5;
  final female = base - 161;
  if (gender == FitnessGender.male) return male;
  if (gender == FitnessGender.female) return female;
  return (male + female) / 2;
}

double activityFactor({int? weeklyDays, required String experience}) {
  if (weeklyDays != null) {
    if (weeklyDays <= 0) return 1.2;
    if (weeklyDays <= 2) return 1.375;
    if (weeklyDays <= 4) return 1.55;
    return 1.725;
  }
  if (experience == FitnessExperience.advanced) return 1.55;
  if (experience == FitnessExperience.intermediate) return 1.375;
  return 1.2;
}

double maxHeartRate(int age) => 208 - 0.7 * age;

double calorieTarget(double tdee, String goal) {
  if (goal == FitnessGoal.fatLoss) return tdee - 400;
  if (goal == FitnessGoal.muscleGain) return tdee + 250;
  return tdee;
}

String suggestedSplitName(String goal, int? weeklyDays) {
  final days = weeklyDays ?? 3;
  if (goal == FitnessGoal.fatLoss) {
    return days <= 3 ? '全身循环 + 有氧' : '上/下分化 + 有氧';
  }
  if (goal == FitnessGoal.muscleGain) {
    return days <= 3 ? '全身力量' : '推/拉/腿';
  }
  if (goal == FitnessGoal.performance) return '力量 + 体能';
  return days <= 3 ? '全身塑形' : '分化塑形';
}

double round1(double value) => (value * 10).roundToDouble() / 10;

ProfileMetrics computeMetrics(FitnessProfile profile, {DateTime? now}) {
  final age = ageFromBirthYear(profile.birthYear, now: now);
  final bmr = bmrMifflin(
    weightKg: profile.weightKg,
    heightCm: profile.heightCm,
    age: age,
    gender: profile.gender,
  );
  final factor = activityFactor(weeklyDays: profile.weeklyDays, experience: profile.experience);
  final tdee = bmr * factor;
  return ProfileMetrics(
    age: age,
    bmr: round1(bmr),
    tdee: round1(tdee),
    calorieTarget: round1(calorieTarget(tdee, profile.goal)),
    maxHr: round1(maxHeartRate(age)),
    activityFactor: factor,
    splitName: suggestedSplitName(profile.goal, profile.weeklyDays),
  );
}
