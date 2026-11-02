import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/domain/strength.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('epley1rm', () {
    test('100kg × 5 = 116.7', () {
      expect(epley1rm(100, 5), closeTo(116.666, 0.01));
    });

    test('1 次记实测，超过 10 次不估算', () {
      expect(epley1rm(100, 1), 100);
      expect(epley1rm(100, 12), isNull);
    });
  });

  group('percent1rm', () {
    test('与文献示例接近', () {
      expect(percent1rm(3, 8.5), closeTo(87.8, 0.2));
      expect(percent1rm(3, 7), closeTo(83.7, 0.2));
      expect(percent1rm(10, 8.5), closeTo(71.6, 1.0));
    });
  });

  test('RPE 估算与 Epley 不同', () {
    final withRpe = estimate1rm(weightKg: 100, reps: 3, rpe: 8.5);
    expect(withRpe, closeTo(100 / 0.878, 1.5));
    expect(withRpe, isNot(closeTo(epley1rm(100, 3)!, 0.01)));
  });

  test('中位数抑制异常值', () {
    expect(blendEstimates([100, 200, 120]), 120);
  });

  test('增肌区取 1RM 的 70%', () {
    expect(workingWeight(200, FitnessGoal.muscleGain), 140);
    expect(intensityZone(FitnessGoal.performance).label, '最大力量');
  });

  test('有效组 RPE ≥ 8', () {
    expect(isHardSet(8.0), isTrue);
    expect(isHardSet(7.5), isFalse);
    expect(setVolume(100, 8), 800);
  });

  test('roundToPlate 仍可用于推荐重量', () {
    expect(roundToPlate(137.2), 137.5);
  });

  test('大肌群基线 60h，小肌群 36h', () {
    expect(baselineWindowHours(name: '胸部', nameEn: 'Chest'), 60);
    expect(baselineWindowHours(name: '肱二头肌', nameEn: 'Biceps'), 36);
  });

  test('有效刺激需要 3 组 RPE≥8 且均 RPE≥7.5', () {
    expect(isEffectiveSession([8, 8, 8.5]), isTrue);
    expect(isEffectiveSession([8, 8]), isFalse);
    expect(isEffectiveSession([8, 8, 8, 5, 5, 5, 5, 5, 5]), isFalse);
  });

  test('恢复进度 = 间隔 / 窗口', () {
    expect(recoveryProgress(24, 60), closeTo(0.4, 0.001));
    expect(recoveryProgress(80, 60), closeTo(1.333, 0.001));
  });

  test('系数钳制在 0.6–1.4', () {
    expect(clampRecoveryFactor(0.2), 0.6);
    expect(clampRecoveryFactor(2), 1.4);
    expect(clampRecoveryFactor(1), 1);
  });

  test('观察次数决定置信度', () {
    expect(recoveryConfidence(0), 'low');
    expect(recoveryConfidence(5), 'medium');
    expect(recoveryConfidence(20), 'high');
  });
}
