import 'package:app_flutter/features/training/application/providers/exercise_stats_provider.dart';
import 'package:app_flutter/features/training/domain/entities/exercise_stats.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_stats_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('ExerciseStats.fromJson 解析空数据', () {
    final stats = ExerciseStats.fromJson({
      'exercise_id': 3,
      'period_days': 30,
      'period_label': '上个月',
      'axis': ['2026-08-12', '2026-08-27', '2026-09-11'],
      'max_weight': {'value': null, 'points': []},
      'total_volume': {'value': null, 'points': []},
      'max_reps': {'value': null, 'points': []},
      'total_reps': {'value': null, 'points': []},
      'records': {'session_count': 0},
      'history': [],
    });
    expect(stats.exerciseId, 3);
    expect(stats.isEmpty, isTrue);
    expect(stats.maxWeight.hasData, isFalse);
    expect(stats.axis, hasLength(3));
  });

  test('parseChartDate 用日历日', () {
    expect(parseChartDate('2026-08-12'), DateTime(2026, 8, 12));
  });

  test('ExerciseStats.fromJson 解析有数据的图表', () {
    final stats = ExerciseStats.fromJson({
      'exercise_id': 1,
      'period_days': 30,
      'period_label': '上个月',
      'axis': ['2026-08-12', '2026-08-27', '2026-09-11'],
      'max_weight': {
        'value': 80,
        'points': [
          {'t': '2026-09-08', 'v': 80},
        ],
      },
      'total_volume': {
        'value': 880,
        'points': [
          {'t': '2026-09-08', 'v': 880},
        ],
      },
      'max_reps': {'value': 8, 'points': []},
      'total_reps': {'value': 13, 'points': []},
      'records': {
        'max_weight_kg': 80,
        'max_reps': 8,
        'estimated_1rm_kg': 100.5,
        'session_count': 1,
        'last_at': '2026-09-08T10:00:00',
      },
      'history': [
        {
          'session_id': 9,
          'started_at': '2026-09-08T10:00:00',
          'sets': [
            {'set_number': 1, 'reps': 8, 'weight_kg': 60, 'rpe': 8},
          ],
        },
      ],
    });
    expect(stats.maxWeight.value, 80);
    expect(stats.maxWeight.points.single.value, 80);
    expect(stats.records.estimated1rmKg, 100.5);
    expect(stats.history.single.sets.single.reps, 8);
  });

  testWidgets('空数据页展示指标卡和无数据', (tester) async {
    final empty = ExerciseStats.fromJson({
      'exercise_id': 1,
      'period_days': 30,
      'period_label': '上个月',
      'axis': ['2026-08-12', '2026-08-27', '2026-09-11'],
      'max_weight': {'value': null, 'points': []},
      'total_volume': {'value': null, 'points': []},
      'max_reps': {'value': null, 'points': []},
      'total_reps': {'value': null, 'points': []},
      'records': {'session_count': 0},
      'history': [],
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseStatsProvider.overrideWith((ref, id) async => empty),
        ],
        child: const MaterialApp(
          home: ExerciseStatsPage(exerciseId: 1, name: '哑铃卧推'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('哑铃卧推'), findsOneWidget);
    expect(find.text('重量变化'), findsOneWidget);
    expect(find.text('PR'), findsOneWidget);
    expect(find.text('最大重量'), findsOneWidget);
  });
}
