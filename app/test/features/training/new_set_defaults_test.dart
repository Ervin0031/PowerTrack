import 'package:app_flutter/features/training/domain/new_set_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('器械动作默认 10kg × 8', () {
    final set = defaultNewTrainingSet(clientUuid: 'a', isBodyweight: false);
    expect(set.reps, 8);
    expect(set.weightKg, 10);
    expect(set.setNumber, 1);
  });

  test('徒手动作默认 8 次且不预填重量', () {
    final set = defaultNewTrainingSet(clientUuid: 'a', isBodyweight: true);
    expect(set.reps, 8);
    expect(set.weightKg, isNull);
  });

  test('没练过的器械组空重量填 10kg，已有重量不动', () {
    final sets = fillUntrainedEquipmentWeight([
      defaultNewTrainingSet(
        clientUuid: 'a',
        isBodyweight: false,
      ).copyWith(weightKg: null),
      defaultNewTrainingSet(
        clientUuid: 'b',
        isBodyweight: false,
      ).copyWith(weightKg: 0),
      defaultNewTrainingSet(
        clientUuid: 'c',
        isBodyweight: false,
      ).copyWith(weightKg: 40),
    ], isBodyweight: false);
    expect(sets.map((set) => set.weightKg), [10, 10, 40]);
  });

  test('徒手动作的空重量保持留空', () {
    final sets = fillUntrainedEquipmentWeight([
      defaultNewTrainingSet(clientUuid: 'a', isBodyweight: true),
    ], isBodyweight: true);
    expect(sets.single.weightKg, isNull);
  });
}
