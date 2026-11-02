// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TrainingSetImpl _$$TrainingSetImplFromJson(Map<String, dynamic> json) =>
    _$TrainingSetImpl(
      setNumber: (json['setNumber'] as num).toInt(),
      reps: (json['reps'] as num?)?.toInt(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      restSeconds: (json['restSeconds'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      setKind:
          $enumDecodeNullable(_$TrainingSetKindEnumMap, json['setKind']) ??
          TrainingSetKind.working,
      clientUuid: json['clientUuid'] as String,
      rpe: (json['rpe'] as num?)?.toDouble(),
      suggestedWeightKg: (json['suggestedWeightKg'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$TrainingSetImplToJson(_$TrainingSetImpl instance) =>
    <String, dynamic>{
      'setNumber': instance.setNumber,
      'reps': instance.reps,
      'weightKg': instance.weightKg,
      'restSeconds': instance.restSeconds,
      'durationSeconds': instance.durationSeconds,
      'distanceMeters': instance.distanceMeters,
      'notes': instance.notes,
      'completedAt': instance.completedAt?.toIso8601String(),
      'startedAt': instance.startedAt?.toIso8601String(),
      'setKind': _$TrainingSetKindEnumMap[instance.setKind]!,
      'clientUuid': instance.clientUuid,
      'rpe': instance.rpe,
      'suggestedWeightKg': instance.suggestedWeightKg,
    };

const _$TrainingSetKindEnumMap = {
  TrainingSetKind.warmup: 'warmup',
  TrainingSetKind.working: 'working',
  TrainingSetKind.cooldown: 'cooldown',
  TrainingSetKind.drop: 'drop',
};

_$TrainingExerciseImpl _$$TrainingExerciseImplFromJson(
  Map<String, dynamic> json,
) => _$TrainingExerciseImpl(
  exerciseId: (json['exerciseId'] as num).toInt(),
  name: json['name'] as String,
  imageUrl: json['imageUrl'] as String?,
  exerciseType: json['exerciseType'] as String? ?? 'compound',
  supersetId: (json['supersetId'] as num?)?.toInt(),
  isBodyweight: json['isBodyweight'] as bool? ?? false,
  sets:
      (json['sets'] as List<dynamic>?)
          ?.map((e) => TrainingSet.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  ghostSets:
      (json['ghostSets'] as List<dynamic>?)
          ?.map((e) => GhostSet.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  ghostSessionDate: json['ghostSessionDate'] == null
      ? null
      : DateTime.parse(json['ghostSessionDate'] as String),
  notes: json['notes'] as String?,
  restTargetSeconds: (json['restTargetSeconds'] as num?)?.toInt(),
  weightUnit: json['weightUnit'] as String? ?? 'kg',
);

Map<String, dynamic> _$$TrainingExerciseImplToJson(
  _$TrainingExerciseImpl instance,
) => <String, dynamic>{
  'exerciseId': instance.exerciseId,
  'name': instance.name,
  'imageUrl': instance.imageUrl,
  'exerciseType': instance.exerciseType,
  'supersetId': instance.supersetId,
  'isBodyweight': instance.isBodyweight,
  'sets': instance.sets,
  'ghostSets': instance.ghostSets,
  'ghostSessionDate': instance.ghostSessionDate?.toIso8601String(),
  'notes': instance.notes,
  'restTargetSeconds': instance.restTargetSeconds,
  'weightUnit': instance.weightUnit,
};

_$ActiveTrainingImpl _$$ActiveTrainingImplFromJson(Map<String, dynamic> json) =>
    _$ActiveTrainingImpl(
      sessionId: (json['sessionId'] as num).toInt(),
      clientUuid: json['clientUuid'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      status: json['status'] as String? ?? 'in_progress',
      exercises:
          (json['exercises'] as List<dynamic>?)
              ?.map((e) => TrainingExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      focusedExerciseId: (json['focusedExerciseId'] as num?)?.toInt(),
      restBonusSeconds: (json['restBonusSeconds'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$ActiveTrainingImplToJson(
  _$ActiveTrainingImpl instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'clientUuid': instance.clientUuid,
  'startedAt': instance.startedAt.toIso8601String(),
  'status': instance.status,
  'exercises': instance.exercises,
  'focusedExerciseId': instance.focusedExerciseId,
  'restBonusSeconds': instance.restBonusSeconds,
};
