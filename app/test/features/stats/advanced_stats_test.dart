import 'package:app_flutter/features/stats/domain/entities/strength_standards.dart';
import 'package:app_flutter/features/stats/domain/entities/volume_landmarks.dart';
import 'package:app_flutter/features/training/domain/entities/one_rm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VolumeLandmarks.fromJson', () {
    test('解析 zone 并映射中文标签与进度', () {
      final landmarks = VolumeLandmarks.fromJson({
        'week_start': '2026-10-12',
        'week_volume': 12345.0,
        'hard_sets': 9,
        'items': [
          {
            'name': '胸部',
            'hard_sets': 7,
            'zone': 'mav',
            'mv': 6,
            'mev': 8,
            'mav_low': 12,
            'mav_high': 20,
            'mrv': 22,
            'is_default': false,
          },
        ],
      });

      expect(landmarks.hardSets, 9);
      final chest = landmarks.items.single;
      expect(chest.zoneLabel, '最佳适应区');
      expect(chest.mavProgress, closeTo(0.35, 0.0001));
    });

    test('超出 MRV 时进度截断为 1', () {
      const item = VolumeLandmarkItem(
        name: '背部',
        hardSets: 30,
        zone: 'above_mrv',
        mv: 6,
        mev: 10,
        mavLow: 12,
        mavHigh: 20,
        mrv: 22,
      );

      expect(item.zoneLabel, '超出 MRV');
      expect(item.mavProgress, 1.0);
    });
  });

  group('StrengthStandards.fromJson', () {
    test('未提交档案时倍体重比为空，推拉比给出结论', () {
      final standards = StrengthStandards.fromJson({
        'has_profile': false,
        'gender': 'undisclosed',
        'bodyweight_kg': null,
        'relative_strength': const [],
        'dots': null,
        'wilks': null,
        'push_pull': {
          'window_days': 28,
          'push_volume_kg': 8000.0,
          'pull_volume_kg': 4000.0,
          'push_hard_sets': 12,
          'pull_hard_sets': 6,
          'ratio': 2.0,
          'verdict': 'push_dominant',
        },
      });

      expect(standards.hasProfile, isFalse);
      expect(standards.isEmpty, isTrue);
      expect(standards.dots, isNull);
      expect(standards.pushPull?.verdictLabel, '推力偏多');
    });

    test('三大项不全时 total_kg 为 null 并列出缺失项', () {
      final standards = StrengthStandards.fromJson({
        'has_profile': true,
        'gender': 'male',
        'bodyweight_kg': 75.0,
        'relative_strength': [
          {
            'exercise_id': 3,
            'name': '深蹲',
            'estimated_1rm_kg': 120.0,
            'ratio': 1.6,
            'is_big_three': true,
          },
        ],
        'big_three': {
          'squat': {'estimated_1rm_kg': 120.0, 'ratio': 1.6},
          'bench': null,
          'deadlift': null,
          'total_kg': null,
          'complete': false,
          'missing': ['卧推', '硬拉'],
        },
        'dots': 210.5,
      });

      expect(standards.bigThree.totalKg, isNull);
      expect(standards.bigThree.missing, ['卧推', '硬拉']);
      expect(standards.bigThree.squat?.ratio, 1.6);
      expect(standards.relativeStrength.single.isBigThree, isTrue);
      expect(standards.isEmpty, isFalse);
    });
  });

  group('OneRmEstimate / OneRmPoint', () {
    test('缺少 1RM 端点返回的字段可解析', () {
      final estimate = OneRmEstimate.fromJson({
        'exercise_id': 7,
        'estimated_kg': 102.5,
        'needs_recalibrate': true,
        'samples_count': 12,
      });

      expect(estimate.estimatedKg, 102.5);
      expect(estimate.needsRecalibrate, isTrue);
      expect(estimate.samplesCount, 12);
    });

    test('历史点解析 UTC 时间', () {
      final point = OneRmPoint.fromJson({'date': '2026-10-12T08:30:00', 'estimated_kg': 100.0, 'rpe': 8.5});

      expect(point.date.isUtc, isTrue);
      expect(point.rpe, 8.5);
    });
  });
}
