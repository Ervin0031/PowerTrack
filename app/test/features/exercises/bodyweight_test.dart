import 'package:app_flutter/features/exercises/domain/bodyweight.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/training/domain/bodyweight_load.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isBodyweightEquipment', () {
    test('未指定器械视为徒手', () {
      expect(isBodyweightEquipment(), isTrue);
    });

    test('器械名为自重或 Bodyweight', () {
      expect(isBodyweightEquipment(equipmentId: 9, name: '自重', nameEn: 'Bodyweight'), isTrue);
      expect(isBodyweightEquipment(equipmentId: 9, name: '徒手'), isTrue);
    });

    test('杠铃不是徒手', () {
      expect(isBodyweightEquipment(equipmentId: 1, name: '杠铃', nameEn: 'Barbell'), isFalse);
    });
  });

  group('isBodyweightByCatalog', () {
    const catalog = [
      Equipment(id: 1, name: '杠铃', nameEn: 'Barbell'),
      Equipment(id: 9, name: '自重', nameEn: 'Bodyweight'),
    ];

    test('equipmentId 为空视为徒手', () {
      expect(isBodyweightByCatalog(null, catalog), isTrue);
    });

    test('匹配自重器械', () {
      expect(isBodyweightByCatalog(9, catalog), isTrue);
    });

    test('匹配杠铃或未知 id 不视为徒手', () {
      expect(isBodyweightByCatalog(1, catalog), isFalse);
      expect(isBodyweightByCatalog(99, catalog), isFalse);
    });
  });

  group('fillBodyweightIfMissing', () {
    test('空重量写入用户体重，已有重量不覆盖', () {
      final filled = fillBodyweightIfMissing(
        [
          TrainingSet(setNumber: 1, clientUuid: 'a'),
          TrainingSet(setNumber: 2, weightKg: 20, clientUuid: 'b'),
        ],
        72,
      );
      expect(filled[0].weightKg, 72);
      expect(filled[1].weightKg, 20);
    });

    test('无档案体重时不改', () {
      final sets = [TrainingSet(setNumber: 1, clientUuid: 'a')];
      expect(fillBodyweightIfMissing(sets, null), sets);
    });
  });

  test('copyOrBodyweightKg 优先上一组有效重量', () {
    expect(
      copyOrBodyweightKg(isBodyweight: true, previousKg: 80, bodyKg: 72),
      80,
    );
    expect(
      copyOrBodyweightKg(isBodyweight: true, previousKg: null, bodyKg: 72),
      72,
    );
    expect(
      copyOrBodyweightKg(isBodyweight: false, previousKg: null, bodyKg: 72),
      isNull,
    );
  });
}
