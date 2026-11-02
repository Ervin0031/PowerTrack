/// 动作库相关实体（动作 / 肌群 / 器械）。
///
/// 纯 Dart，零 Flutter / Riverpod 依赖，字段与后端 Schema 对应
/// （backend/app/schemas/exercise.py 中的 `ExerciseResponse` /
/// `MuscleGroupResponse` / `EquipmentResponse`）。
// ignore_for_file: invalid_annotation_target
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

/// 训练动作实体。
@Freezed()
abstract class Exercise with _$Exercise {
  const factory Exercise({
    required int id,
    required String name,
    @JsonKey(name: 'name_en') String? nameEn,
    @JsonKey(name: 'exercise_type') required String exerciseType,
    @JsonKey(name: 'equipment_id') int? equipmentId,
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _Exercise;

  factory Exercise.fromJson(Map<String, dynamic> json) => _$ExerciseFromJson(json);
}

/// 肌群实体（按部位分类：upper / lower / core）。
@Freezed()
abstract class MuscleGroup with _$MuscleGroup {
  const factory MuscleGroup({
    required int id,
    required String name,
    @JsonKey(name: 'name_en') required String nameEn,
    required String category,
  }) = _MuscleGroup;

  factory MuscleGroup.fromJson(Map<String, dynamic> json) => _$MuscleGroupFromJson(json);
}

/// 训练器械实体。
@Freezed()
abstract class Equipment with _$Equipment {
  const factory Equipment({
    required int id,
    required String name,
    @JsonKey(name: 'name_en') required String nameEn,
  }) = _Equipment;

  factory Equipment.fromJson(Map<String, dynamic> json) => _$EquipmentFromJson(json);
}

/// 动作详情实体（含主/辅助肌群、器械的关联名称）。
///
/// 字段对应后端 `ExerciseDetailResponse`，比列表用到的 [Exercise] 多
/// `primary_muscle_name` / `equipment_name` / `secondary_muscles` 等展示字段。
@Freezed()
abstract class ExerciseDetail with _$ExerciseDetail {
  const factory ExerciseDetail({
    required int id,
    required String name,
    @JsonKey(name: 'name_en') String? nameEn,
    @JsonKey(name: 'exercise_type') required String exerciseType,
    @JsonKey(name: 'primary_muscle_group_id') required int primaryMuscleGroupId,
    @JsonKey(name: 'equipment_id') int? equipmentId,
    String? instructions,
    @JsonKey(name: 'is_custom') @Default(false) bool isCustom,
    @JsonKey(name: 'image_key') String? imageKey,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'primary_muscle_name') String? primaryMuscleName,
    @JsonKey(name: 'primary_muscle_name_en') String? primaryMuscleNameEn,
    @JsonKey(name: 'equipment_name') String? equipmentName,
    @JsonKey(name: 'equipment_name_en') String? equipmentNameEn,
    @JsonKey(name: 'secondary_muscles')
    @Default([])
    List<MuscleGroup> secondaryMuscles,
  }) = _ExerciseDetail;

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) => _$ExerciseDetailFromJson(json);
}
