import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/entities/training_set_kind.dart';
import 'package:app_flutter/features/training/domain/set_follow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('copiedWeightAfterPrevious', () {
    test('上一组没记次数的力竭：100kg → 95kg', () {
      expect(
        copiedWeightAfterPrevious(
          previousKg: 100,
          previousCompletedAt: DateTime.utc(2026),
          previousRpe: 10,
          autoReduce: true,
        ),
        95,
      );
    });

    test('上一组 1 次力竭：按表降到 92.5kg', () {
      expect(
        copiedWeightAfterPrevious(
          previousKg: 100,
          previousReps: 1,
          previousCompletedAt: DateTime.utc(2026),
          previousRpe: 10,
          autoReduce: true,
        ),
        92.5,
      );
    });

    test('前面已经力竭过，再追加一组不降重', () {
      expect(
        copiedWeightAfterPrevious(
          previousKg: 95,
          previousReps: 5,
          previousCompletedAt: DateTime.utc(2026),
          previousRpe: 10,
          priorRpes: const [10],
          autoReduce: true,
        ),
        95,
      );
    });

    test('未完成或未力竭时原样复制', () {
      expect(
        copiedWeightAfterPrevious(
          previousKg: 100,
          previousCompletedAt: DateTime.utc(2026),
          previousRpe: 8,
          autoReduce: true,
        ),
        100,
      );
      expect(
        copiedWeightAfterPrevious(
          previousKg: 100,
          previousCompletedAt: null,
          previousRpe: 10,
          autoReduce: true,
        ),
        100,
      );
    });

    test('关闭自动降重时不改重量', () {
      expect(
        copiedWeightAfterPrevious(
          previousKg: 100,
          previousCompletedAt: DateTime.utc(2026),
          previousRpe: 10,
          autoReduce: false,
        ),
        100,
      );
    });
  });

  group('patchSetAndFollow', () {
    final completed = DateTime.utc(2026);
    final sets = [
      TrainingSet(
        setNumber: 1,
        reps: 8,
        weightKg: 100,
        completedAt: completed,
        clientUuid: 's1',
      ),
      TrainingSet(setNumber: 2, reps: 8, weightKg: 100, clientUuid: 's2'),
      TrainingSet(setNumber: 3, reps: 8, weightKg: 100, clientUuid: 's3'),
      TrainingSet(
        setNumber: 4,
        reps: 8,
        weightKg: 80,
        setKind: TrainingSetKind.drop,
        clientUuid: 's4',
      ),
    ];

    test('次数和重量同步到之后未完成的同类型组', () {
      final edited = sets[1].copyWith(reps: 6, weightKg: 90);
      final next = patchSetAndFollow(
        sets: sets,
        edited: edited,
        followReps: true,
        followWeight: true,
      );
      expect(next[0].reps, 8);
      expect(next[0].weightKg, 100);
      expect(next[1].reps, 6);
      expect(next[1].weightKg, 90);
      expect(next[2].reps, 6);
      expect(next[2].weightKg, 90);
      expect(next[3].reps, 8);
      expect(next[3].weightKg, 80);
    });

    test('自动更新只带动仍等于旧值的未完成组', () {
      final edited = sets[1].copyWith(reps: 6, weightKg: 90);
      final next = patchSetMatching(
        sets: sets,
        edited: edited,
        previousReps: 8,
        previousWeightKg: 100,
        followReps: true,
        followWeight: true,
      );
      expect(next[0].reps, 8);
      expect(next[0].weightKg, 100);
      expect(next[1].reps, 6);
      expect(next[1].weightKg, 90);
      expect(next[2].reps, 6);
      expect(next[2].weightKg, 90);
      expect(next[3].reps, 6, reason: '次数仍是旧值，跟着变');
      expect(next[3].weightKg, 80, reason: '重量已经不同，不跟着变');
    });

    test('只改次数时不改后续重量', () {
      final edited = sets[1].copyWith(reps: 6);
      final next = patchSetAndFollow(
        sets: sets,
        edited: edited,
        followReps: true,
      );
      expect(next[2].reps, 6);
      expect(next[2].weightKg, 100);
    });
  });
}
