import 'package:app_flutter/features/training/domain/entities/muscle_group_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson 解析恢复字段', () {
    final status = MuscleGroupStatus.fromJson({
      'muscle_group_id': 1,
      'name': '胸部',
      'name_en': 'Chest',
      'category': 'upper',
      'last_trained_at': '2026-09-10T12:00:00',
      'hours_since_last': 24,
      'recovery_progress': 0.4,
      'recovery_window_hours': 60,
      'baseline_window_hours': 60,
      'recovery_factor': 1.0,
      'global_factor': 1.0,
      'muscle_factor': 1.0,
      'recovery_confidence': 'low',
      'observations_count': 1,
    });
    expect(status.name, '胸部');
    expect(status.isRecovered, isFalse);
    expect(status.valueLabel, '40%');
    expect(status.hoursUntilReady, 36);
    expect(status.inferredSpeedLabel, isNull);
    expect(status.subtitle, contains('根据训练历史推断'));
  });

  test('样本足够时展示比平均快/慢', () {
    final fast = MuscleGroupStatus.fromJson({
      'muscle_group_id': 1,
      'name': '胸部',
      'name_en': 'Chest',
      'category': 'upper',
      'last_trained_at': '2026-09-10T12:00:00',
      'hours_since_last': 80,
      'recovery_progress': 1.5,
      'recovery_window_hours': 51,
      'baseline_window_hours': 60,
      'recovery_factor': 0.75,
      'global_factor': 1.0,
      'muscle_factor': 0.75,
      'recovery_confidence': 'medium',
      'observations_count': 5,
    });
    expect(fast.isRecovered, isTrue);
    expect(fast.valueLabel, '已恢复');
    expect(fast.inferredSpeedLabel, '根据训练历史推断，恢复比平均快 25%');
    expect(fast.ringValue, 1);
  });

  test('summary fromJson', () {
    final summary = MuscleGroupStatusSummary.fromJson({
      'items': [],
      'global_factor': 1.0,
      'global_observations_count': 0,
      'global_confidence': 'low',
    });
    expect(summary.items, isEmpty);
    expect(summary.globalFactor, 1);
  });
}
