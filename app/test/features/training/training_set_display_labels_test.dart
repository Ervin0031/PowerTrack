import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/entities/training_set_kind.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingSet _set(int n, TrainingSetKind kind) => TrainingSet(
      setNumber: n,
      setKind: kind,
      clientUuid: 'u-$n',
    );

void main() {
  test('热身/主要/放松文案', () {
    final labels = trainingSetDisplayLabels([
      _set(1, TrainingSetKind.warmup),
      _set(2, TrainingSetKind.working),
      _set(3, TrainingSetKind.working),
      _set(4, TrainingSetKind.cooldown),
    ]);
    expect(labels, ['热身', '1', '2', '放松']);
  });

  test('递减组接主要组序号加字母', () {
    final labels = trainingSetDisplayLabels([
      _set(1, TrainingSetKind.working),
      _set(2, TrainingSetKind.drop),
      _set(3, TrainingSetKind.drop),
      _set(4, TrainingSetKind.working),
      _set(5, TrainingSetKind.drop),
    ]);
    expect(labels, ['1', '1A', '1B', '2', '2A']);
  });

  test('无主要组时递减从 1A 起', () {
    final labels = trainingSetDisplayLabels([
      _set(1, TrainingSetKind.drop),
      _set(2, TrainingSetKind.drop),
      _set(3, TrainingSetKind.drop),
    ]);
    expect(labels, ['1A', '1B', '1C']);
  });
}
