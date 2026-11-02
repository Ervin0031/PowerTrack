import 'package:app_flutter/features/training/domain/entities/training_session.dart';

/// 没练过该动作时的默认次数。
const int kDefaultNewSetReps = 8;

/// 没练过该动作时器械组的默认重量（kg）。
const double kDefaultNewSetWeightKg = 10;

/// 没练过该动作时的默认一组：器械 10kg×8；徒手次数 8、重量留空（界面显示「自重」）。
TrainingSet defaultNewTrainingSet({
  required String clientUuid,
  required bool isBodyweight,
  int setNumber = 1,
}) {
  return TrainingSet(
    setNumber: setNumber,
    reps: kDefaultNewSetReps,
    weightKg: isBodyweight ? null : kDefaultNewSetWeightKg,
    clientUuid: clientUuid,
  );
}

/// 器械动作里没写出的重量，填上最小默认重量。已有重量和徒手动作保持原样。
List<TrainingSet> fillUntrainedEquipmentWeight(
  List<TrainingSet> sets, {
  required bool isBodyweight,
}) {
  if (isBodyweight) return sets;
  return [
    for (final set in sets)
      if (set.weightKg == null || set.weightKg! <= 0)
        set.copyWith(weightKg: kDefaultNewSetWeightKg)
      else
        set,
  ];
}
