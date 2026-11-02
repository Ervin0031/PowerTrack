// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SessionCreateImpl _$$SessionCreateImplFromJson(Map<String, dynamic> json) =>
    _$SessionCreateImpl(
      clientUuid: json['clientUuid'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
    );

Map<String, dynamic> _$$SessionCreateImplToJson(_$SessionCreateImpl instance) =>
    <String, dynamic>{
      'clientUuid': instance.clientUuid,
      'startedAt': instance.startedAt.toIso8601String(),
    };

_$WorkoutSetCreateImpl _$$WorkoutSetCreateImplFromJson(
  Map<String, dynamic> json,
) => _$WorkoutSetCreateImpl(
  exerciseId: (json['exerciseId'] as num).toInt(),
  setNumber: (json['setNumber'] as num).toInt(),
  reps: (json['reps'] as num?)?.toInt(),
  weightKg: (json['weightKg'] as num?)?.toDouble(),
  durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
  distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
  notes: json['notes'] as String?,
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  clientUuid: json['clientUuid'] as String,
  rpe: (json['rpe'] as num?)?.toDouble(),
);

Map<String, dynamic> _$$WorkoutSetCreateImplToJson(
  _$WorkoutSetCreateImpl instance,
) => <String, dynamic>{
  'exerciseId': instance.exerciseId,
  'setNumber': instance.setNumber,
  'reps': instance.reps,
  'weightKg': instance.weightKg,
  'durationSeconds': instance.durationSeconds,
  'distanceMeters': instance.distanceMeters,
  'notes': instance.notes,
  'completedAt': instance.completedAt?.toIso8601String(),
  'clientUuid': instance.clientUuid,
  'rpe': instance.rpe,
};

_$SessionCompleteImpl _$$SessionCompleteImplFromJson(
  Map<String, dynamic> json,
) => _$SessionCompleteImpl(
  clientUuid: json['clientUuid'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  completedAt: DateTime.parse(json['completedAt'] as String),
  notes: json['notes'] as String?,
  sets:
      (json['sets'] as List<dynamic>?)
          ?.map((e) => WorkoutSetCreate.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$$SessionCompleteImplToJson(
  _$SessionCompleteImpl instance,
) => <String, dynamic>{
  'clientUuid': instance.clientUuid,
  'startedAt': instance.startedAt.toIso8601String(),
  'completedAt': instance.completedAt.toIso8601String(),
  'notes': instance.notes,
  'sets': instance.sets,
};
