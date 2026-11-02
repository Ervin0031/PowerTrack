import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recommendNextSet', () {
    test('甜蜜区 RPE 8.0：100kg → 建议 102.5kg', () {
      final advice = recommendNextSet(weightKg: 100, rpe: 8.0);
      expect(advice.suggestedWeightKg, 102.5);
      expect(advice.extraRestSeconds, 0);
      expect(advice.fatigueWarning, isFalse);
    });

    test('红区 RPE 9.5：额外休息 60 秒，重量不变', () {
      final advice = recommendNextSet(weightKg: 100, rpe: 9.5);
      expect(advice.suggestedWeightKg, 100);
      expect(advice.extraRestSeconds, 60);
      expect(advice.message, kRestMessage);
      expect(advice.fatigueWarning, isFalse);
    });

    test('没记次数的力竭：复合降 5%，孤立降 7.5%', () {
      final compound = recommendNextSet(weightKg: 100, rpe: 10.0);
      final isolation = recommendNextSet(
        weightKg: 100,
        rpe: 10.0,
        exerciseType: 'isolation',
      );
      expect(compound.suggestedWeightKg, 95);
      expect(isolation.suggestedWeightKg, 92.5);
      expect(compound.fatigueWarning, isTrue);
      expect(compound.reduceRemainingFactor, isNot(0.10));
      expect(compound.extraRestSeconds, 60);
      expect(compound.message, '力竭了，下一组 95kg');
    });

    test('单次力竭留到目标余力，不会砍到 90kg', () {
      final gain = recommendNextSet(
        weightKg: 100,
        rpe: 10,
        reps: 1,
        goal: 'muscle_gain',
      );
      final strength = recommendNextSet(
        weightKg: 100,
        rpe: 10,
        reps: 1,
        goal: 'performance',
      );
      expect(gain.suggestedWeightKg, 92.5);
      expect(strength.suggestedWeightKg, 95);
      expect(gain.suggestedWeightKg, isNot(90));
    });

    test('5 次力竭按表低于 100kg 且高于 90kg', () {
      final advice = recommendNextSet(weightKg: 100, rpe: 10, reps: 5);
      expect(advice.suggestedWeightKg, lessThan(100));
      expect(advice.suggestedWeightKg, greaterThan(90));
      expect(advice.message, failureNextMessage(advice.suggestedWeightKg!));
    });

    test('同一动作已经力竭过，第二次不给新重量', () {
      final advice = recommendNextSet(
        weightKg: 95,
        rpe: 10,
        reps: 5,
        priorRpes: const [10],
      );
      expect(advice.suggestedWeightKg, isNull);
      expect(advice.fatigueWarning, isTrue);
      expect(advice.reduceRemainingFactor, isNull);
      expect(advice.extraRestSeconds, 60);
      expect(advice.message, kFailureAgainMessage);
    });

    test('连续红区再少 2.5kg，第一次红区重量不动', () {
      final first = recommendNextSet(weightKg: 100, rpe: 9.5);
      final again = recommendNextSet(
        weightKg: 100,
        rpe: 9.5,
        priorRpes: const [9.5],
      );
      expect(first.suggestedWeightKg, 100);
      expect(again.suggestedWeightKg, 97.5);
      expect(again.extraRestSeconds, 60);
      expect(again.message, '连续顶到极限，下一组 97.5kg');
    });

    test('连续升 RPE 锁定重量', () {
      final advice = recommendNextSet(
        weightKg: 100,
        rpe: 8.5,
        priorRpes: const [7.5, 8.0],
      );
      expect(advice.suggestedWeightKg, 100);
      expect(advice.reason, kReasonRising);
    });

    test('复合动作甜区比孤立更保守', () {
      final compound = recommendNextSet(weightKg: 80, rpe: 8.0);
      final isolation = recommendNextSet(
        weightKg: 80,
        rpe: 8.0,
        exerciseType: 'isolation',
      );
      expect(compound.suggestedWeightKg, 80);
      expect(isolation.suggestedWeightKg, 82.5);
      expect(compound.reason, kReasonCompound);
      expect(isolation.reason, kReasonIsolation);
    });

    test('有 1RM 时夹到目标区', () {
      final advice = recommendNextSet(
        weightKg: 100,
        rpe: 6.0,
        oneRmKg: 100,
        goal: 'performance',
      );
      expect(advice.suggestedWeightKg, 95);
      expect(advice.cappedBy1rm, isTrue);
      expect(advice.reason, kReasonCapped);
    });
  });

  test('幽灵文案：上周 100kg × 8下 (RPE 9.0)', () {
    final now = DateTime(2026, 9, 10);
    final line = ghostLine(
      sessionDate: DateTime(2026, 9, 3),
      weightKg: 100,
      reps: 8,
      rpe: 9.0,
      now: now,
    );
    expect(line, '上周：100kg × 8下 (RPE 9.0)');
  });

  test('roundToPlate 92.25 → 92.5', () {
    expect(roundToPlate(92.25), 92.5);
  });

  test('formatWeightKg 最多一位小数', () {
    expect(formatWeightKg(100), '100');
    expect(formatWeightKg(102.5), '102.5');
    expect(formatWeightKg(14.306151645207438), '14.3');
  });

  test('formatWeight 按单位换算', () {
    expect(formatWeight(100, unit: 'kg'), '100');
    expect(formatWeight(100, unit: 'lb'), '220.5');
  });
}
