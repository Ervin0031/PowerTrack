// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExerciseImpl _$$ExerciseImplFromJson(Map<String, dynamic> json) =>
    _$ExerciseImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
      exerciseType: json['exercise_type'] as String,
      equipmentId: (json['equipment_id'] as num?)?.toInt(),
      imageUrl: json['image_url'] as String?,
    );

Map<String, dynamic> _$$ExerciseImplToJson(_$ExerciseImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'name_en': instance.nameEn,
      'exercise_type': instance.exerciseType,
      'equipment_id': instance.equipmentId,
      'image_url': instance.imageUrl,
    };

_$MuscleGroupImpl _$$MuscleGroupImplFromJson(Map<String, dynamic> json) =>
    _$MuscleGroupImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      nameEn: json['name_en'] as String,
      category: json['category'] as String,
    );

Map<String, dynamic> _$$MuscleGroupImplToJson(_$MuscleGroupImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'name_en': instance.nameEn,
      'category': instance.category,
    };

_$EquipmentImpl _$$EquipmentImplFromJson(Map<String, dynamic> json) =>
    _$EquipmentImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      nameEn: json['name_en'] as String,
    );

Map<String, dynamic> _$$EquipmentImplToJson(_$EquipmentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'name_en': instance.nameEn,
    };

_$ExerciseDetailImpl _$$ExerciseDetailImplFromJson(Map<String, dynamic> json) =>
    _$ExerciseDetailImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
      exerciseType: json['exercise_type'] as String,
      primaryMuscleGroupId: (json['primary_muscle_group_id'] as num).toInt(),
      equipmentId: (json['equipment_id'] as num?)?.toInt(),
      instructions: json['instructions'] as String?,
      isCustom: json['is_custom'] as bool? ?? false,
      imageKey: json['image_key'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      primaryMuscleName: json['primary_muscle_name'] as String?,
      primaryMuscleNameEn: json['primary_muscle_name_en'] as String?,
      equipmentName: json['equipment_name'] as String?,
      equipmentNameEn: json['equipment_name_en'] as String?,
      secondaryMuscles:
          (json['secondary_muscles'] as List<dynamic>?)
              ?.map((e) => MuscleGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ExerciseDetailImplToJson(
  _$ExerciseDetailImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'name_en': instance.nameEn,
  'exercise_type': instance.exerciseType,
  'primary_muscle_group_id': instance.primaryMuscleGroupId,
  'equipment_id': instance.equipmentId,
  'instructions': instance.instructions,
  'is_custom': instance.isCustom,
  'image_key': instance.imageKey,
  'image_url': instance.imageUrl,
  'created_at': instance.createdAt.toIso8601String(),
  'primary_muscle_name': instance.primaryMuscleName,
  'primary_muscle_name_en': instance.primaryMuscleNameEn,
  'equipment_name': instance.equipmentName,
  'equipment_name_en': instance.equipmentNameEn,
  'secondary_muscles': instance.secondaryMuscles,
};
