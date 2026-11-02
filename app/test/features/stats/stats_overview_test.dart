import 'package:app_flutter/features/stats/domain/entities/stats_overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StatsOverview.fromJson', () {
    final overview = StatsOverview.fromJson({
      'period_days': 30,
      'period_label': '本月',
      'sessions_count': 2,
      'total_volume_kg': 2280,
      'total_duration_seconds': 9000,
      'avg_rpe': 8.6,
      'hard_sets': 4,
      'trained_days': ['2026-09-01', '2026-09-08'],
      'by_muscle': [
        {'name': '胸部', 'volume': 1680, 'hard_sets': 3},
      ],
      'recent_prs': [
        {
          'exercise_id': 10,
          'name': '杠铃卧推',
          'kind': 'max_weight',
          'value': 100,
          'at': '2026-09-08T10:00:00',
        },
      ],
      'top_exercises': [
        {
          'exercise_id': 10,
          'name': '杠铃卧推',
          'sessions': 2,
          'volume': 1680,
          'estimated_1rm_kg': 115,
        },
      ],
    });

    expect(overview.sessionsCount, 2);
    expect(overview.trainedDays, ['2026-09-01', '2026-09-08']);
    expect(overview.byMuscle.first.name, '胸部');
    expect(overview.recentPrs.first.value, 100);
    expect(overview.topExercises.first.estimated1rmKg, 115);
    expect(overview.isEmpty, isFalse);
  });
}
