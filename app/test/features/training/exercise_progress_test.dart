import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/presentation/widgets/exercise_card.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingSet _set({
  required int number,
  int? reps,
  double? weightKg,
  DateTime? completedAt,
  double? suggestedWeightKg,
}) {
  return TrainingSet(
    setNumber: number,
    reps: reps,
    weightKg: weightKg,
    completedAt: completedAt,
    suggestedWeightKg: suggestedWeightKg,
    clientUuid: 's$number',
  );
}

void main() {
  test('收起时写出进度和下一组', () {
    final line = exerciseProgressLine(
      TrainingExercise(
        exerciseId: 1,
        name: '杠铃卧推',
        sets: [
          _set(
            number: 1,
            reps: 8,
            weightKg: 60,
            completedAt: DateTime.utc(2026),
          ),
          _set(number: 2, reps: 5, weightKg: 80),
          _set(number: 3, reps: 5, weightKg: 80),
          _set(number: 4, reps: 5, weightKg: 80),
        ],
      ),
    );
    expect(line, '1/4 · 下一组 80kg × 5');
  });

  test('全部做完时只写完成', () {
    final done = DateTime.utc(2026);
    final line = exerciseProgressLine(
      TrainingExercise(
        exerciseId: 1,
        name: '杠铃卧推',
        sets: [
          _set(number: 1, reps: 5, weightKg: 80, completedAt: done),
          _set(number: 2, reps: 5, weightKg: 80, completedAt: done),
        ],
      ),
    );
    expect(line, '2/2 完成');
  });
}
