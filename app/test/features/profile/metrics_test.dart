import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:app_flutter/features/profile/domain/metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 11);

  group('computeMetrics', () {
    test('女性减脂示例与 Mifflin-St Jeor 一致', () {
      const profile = FitnessProfile(
        gender: FitnessGender.female,
        birthYear: 1995,
        heightCm: 165,
        weightKg: 58,
        goal: FitnessGoal.fatLoss,
        experience: FitnessExperience.beginner,
        weeklyDays: 3,
      );
      final m = computeMetrics(profile, now: now);
      expect(m.age, 31);
      expect(m.bmr, closeTo(1295.25, 0.1));
      expect(m.activityFactor, 1.55);
      expect(m.calorieTarget, closeTo(m.tdee - 400, 0.1));
      expect(m.maxHr, closeTo(208 - 0.7 * 31, 0.1));
      expect(m.splitName, '全身循环 + 有氧');
    });

    test('不愿透露性别时取男女公式平均', () {
      const profile = FitnessProfile(
        gender: FitnessGender.undisclosed,
        birthYear: 1995,
        heightCm: 165,
        weightKg: 58,
        goal: FitnessGoal.health,
        experience: FitnessExperience.beginner,
      );
      final m = computeMetrics(profile, now: now);
      const male = 10 * 58 + 6.25 * 165 - 5 * 31 + 5;
      const female = 10 * 58 + 6.25 * 165 - 5 * 31 - 161;
      expect(m.bmr, closeTo((male + female) / 2, 0.15));
    });

    test('增肌热量目标为 TDEE+250', () {
      const profile = FitnessProfile(
        gender: FitnessGender.male,
        birthYear: 1990,
        heightCm: 180,
        weightKg: 80,
        goal: FitnessGoal.muscleGain,
        experience: FitnessExperience.advanced,
        weeklyDays: 5,
      );
      final m = computeMetrics(profile, now: now);
      expect(m.calorieTarget, closeTo(m.tdee + 250, 0.1));
      expect(m.splitName, '推/拉/腿');
    });
  });

  group('FitnessProfileDraft', () {
    test('缺性别/目标/经验时不能提交', () {
      expect(const FitnessProfileDraft().canSubmit, isFalse);
      expect(
        const FitnessProfileDraft(gender: FitnessGender.male, goal: FitnessGoal.health).canSubmit,
        isFalse,
      );
      expect(
        const FitnessProfileDraft(
          gender: FitnessGender.male,
          goal: FitnessGoal.health,
          experience: FitnessExperience.beginner,
        ).canSubmit,
        isTrue,
      );
    });

    test('json 往返保留伤病和训练安排', () {
      const draft = FitnessProfileDraft(
        gender: FitnessGender.female,
        birthYear: 1995,
        heightCm: 165,
        weightKg: 58.5,
        goal: FitnessGoal.fatLoss,
        experience: FitnessExperience.beginner,
        injuryTags: [FitnessInjury.knee],
        weeklyDays: 4,
        sessionMinutes: 45,
      );
      final again = FitnessProfileDraft.fromJson(draft.toJson());
      expect(again.gender, draft.gender);
      expect(again.injuryTags, ['knee']);
      expect(again.weeklyDays, 4);
      expect(again.weightKg, 58.5);
    });
  });

  group('FitnessProfile', () {
    test('fromJson 读取后端 snake_case', () {
      final profile = FitnessProfile.fromJson({
        'gender': 'female',
        'birth_year': 1995,
        'height_cm': 165,
        'weight_kg': 58,
        'goal': 'fat_loss',
        'experience': 'beginner',
        'injury_tags': ['knee'],
        'weekly_days': 3,
        'session_minutes': 45,
        'metrics': {
          'age': 31,
          'bmr': 1295.3,
          'tdee': 2007.7,
          'calorie_target': 1607.7,
          'max_hr': 186.3,
          'activity_factor': 1.55,
          'split_name': '全身循环 + 有氧',
        },
      });
      expect(profile.isCoreComplete, isTrue);
      expect(profile.metrics?.splitName, '全身循环 + 有氧');
      expect(profile.toJson()['birthYear'], 1995);
      expect(profile.toJson()['injuryTags'], ['knee']);
    });
  });
}
