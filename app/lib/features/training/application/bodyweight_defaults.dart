import 'package:app_flutter/features/exercises/data/repositories/exercise_repository.dart';
import 'package:app_flutter/features/exercises/domain/bodyweight.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/training/domain/bodyweight_load.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 读取健身档案中的体重；档案未加载或测试未注入时返回 null。
double? readUserBodyweightKg(Ref ref) {
  try {
    final kg = ref.read(fitnessProfileProvider).value?.weightKg;
    if (kg == null || kg <= 0) return null;
    return kg;
  } catch (_) {
    return null;
  }
}

/// 解析动作是否徒手。优先用 [equipmentId] + 器械目录；否则拉动作详情。
Future<bool> resolveIsBodyweight(
  Ref ref, {
  int? equipmentId,
  int? exerciseId,
  String? equipmentName,
  String? equipmentNameEn,
}) async {
  if (equipmentName != null || equipmentNameEn != null) {
    return isBodyweightEquipment(
      equipmentId: equipmentId,
      name: equipmentName,
      nameEn: equipmentNameEn,
    );
  }
  if (equipmentId != null) {
    try {
      final catalog = await ref.read(exerciseRepositoryProvider).listEquipment();
      return isBodyweightByCatalog(equipmentId, catalog);
    } catch (_) {
      return false;
    }
  }
  if (exerciseId != null) {
    try {
      final detail = await ref.read(exerciseRepositoryProvider).getExercise(exerciseId);
      return isBodyweightEquipment(
        equipmentId: detail.equipmentId,
        name: detail.equipmentName,
        nameEn: detail.equipmentNameEn,
      );
    } catch (_) {
      return false;
    }
  }
  return true;
}

Future<List<Equipment>> loadEquipmentCatalog(Ref ref) async {
  try {
    return await ref.read(exerciseRepositoryProvider).listEquipment();
  } catch (_) {
    return const [];
  }
}

TrainingExercise applyBodyweightDefault(TrainingExercise exercise, double? bodyKg) {
  if (!exercise.isBodyweight) return exercise;
  return exercise.copyWith(sets: fillBodyweightIfMissing(exercise.sets, bodyKg));
}
