import 'package:app_flutter/core/native/workout_live_activity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('workoutIslandLoadLabel', () {
    test('次数在前，重量带单位', () {
      expect(
        workoutIslandLoadLabel(reps: 8, weightKg: 5, isBodyweight: false),
        '8 x 5 kg',
      );
    });

    test('磅单位从 kg 换算', () {
      expect(
        workoutIslandLoadLabel(reps: 5, weightKg: 10, isBodyweight: false, weightUnit: 'lb'),
        '5 x 22 lb',
      );
    });

    test('徒手没有重量时写自重', () {
      expect(
        workoutIslandLoadLabel(reps: 8, weightKg: null, isBodyweight: true),
        '8 x 自重',
      );
    });
  });

  group('workoutIslandNextLine', () {
    test('休息时加 Next 前缀', () {
      expect(
        workoutIslandNextLine(resting: true, loadLabel: '8 x 5 kg', currentSet: 2, exerciseSets: 4),
        'Next: 8 x 5 kg',
      );
    });

    test('训练中直接显示负荷', () {
      expect(
        workoutIslandNextLine(resting: false, loadLabel: '8 x 5 kg', currentSet: 2, exerciseSets: 4),
        '8 x 5 kg',
      );
    });

    test('休息结束提示带上动作名', () {
      expect(workoutIslandRestPrompt('杠铃深蹲'), '开始下一组：杠铃深蹲');
      expect(workoutIslandRestPrompt('  '), '开始下一组');
      expect(workoutIslandRestPrompt('训练进行中'), '开始下一组');
    });

    test('没有负荷时退回组号', () {
      expect(
        workoutIslandNextLine(resting: false, loadLabel: '', currentSet: 2, exerciseSets: 4),
        '第 2/4 组',
      );
    });
  });
}
