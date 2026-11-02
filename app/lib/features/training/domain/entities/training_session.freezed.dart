// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'training_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TrainingSet _$TrainingSetFromJson(Map<String, dynamic> json) {
  return _TrainingSet.fromJson(json);
}

/// @nodoc
mixin _$TrainingSet {
  int get setNumber => throw _privateConstructorUsedError;
  int? get reps => throw _privateConstructorUsedError;
  double? get weightKg => throw _privateConstructorUsedError;
  int? get restSeconds => throw _privateConstructorUsedError;
  int? get durationSeconds => throw _privateConstructorUsedError;
  double? get distanceMeters => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  DateTime? get startedAt => throw _privateConstructorUsedError;
  TrainingSetKind get setKind => throw _privateConstructorUsedError;
  String get clientUuid => throw _privateConstructorUsedError;
  double? get rpe => throw _privateConstructorUsedError;
  double? get suggestedWeightKg => throw _privateConstructorUsedError;

  /// Serializes this TrainingSet to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TrainingSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TrainingSetCopyWith<TrainingSet> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TrainingSetCopyWith<$Res> {
  factory $TrainingSetCopyWith(
    TrainingSet value,
    $Res Function(TrainingSet) then,
  ) = _$TrainingSetCopyWithImpl<$Res, TrainingSet>;
  @useResult
  $Res call({
    int setNumber,
    int? reps,
    double? weightKg,
    int? restSeconds,
    int? durationSeconds,
    double? distanceMeters,
    String? notes,
    DateTime? completedAt,
    DateTime? startedAt,
    TrainingSetKind setKind,
    String clientUuid,
    double? rpe,
    double? suggestedWeightKg,
  });
}

/// @nodoc
class _$TrainingSetCopyWithImpl<$Res, $Val extends TrainingSet>
    implements $TrainingSetCopyWith<$Res> {
  _$TrainingSetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TrainingSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setNumber = null,
    Object? reps = freezed,
    Object? weightKg = freezed,
    Object? restSeconds = freezed,
    Object? durationSeconds = freezed,
    Object? distanceMeters = freezed,
    Object? notes = freezed,
    Object? completedAt = freezed,
    Object? startedAt = freezed,
    Object? setKind = null,
    Object? clientUuid = null,
    Object? rpe = freezed,
    Object? suggestedWeightKg = freezed,
  }) {
    return _then(
      _value.copyWith(
            setNumber: null == setNumber
                ? _value.setNumber
                : setNumber // ignore: cast_nullable_to_non_nullable
                      as int,
            reps: freezed == reps
                ? _value.reps
                : reps // ignore: cast_nullable_to_non_nullable
                      as int?,
            weightKg: freezed == weightKg
                ? _value.weightKg
                : weightKg // ignore: cast_nullable_to_non_nullable
                      as double?,
            restSeconds: freezed == restSeconds
                ? _value.restSeconds
                : restSeconds // ignore: cast_nullable_to_non_nullable
                      as int?,
            durationSeconds: freezed == durationSeconds
                ? _value.durationSeconds
                : durationSeconds // ignore: cast_nullable_to_non_nullable
                      as int?,
            distanceMeters: freezed == distanceMeters
                ? _value.distanceMeters
                : distanceMeters // ignore: cast_nullable_to_non_nullable
                      as double?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            completedAt: freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            startedAt: freezed == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            setKind: null == setKind
                ? _value.setKind
                : setKind // ignore: cast_nullable_to_non_nullable
                      as TrainingSetKind,
            clientUuid: null == clientUuid
                ? _value.clientUuid
                : clientUuid // ignore: cast_nullable_to_non_nullable
                      as String,
            rpe: freezed == rpe
                ? _value.rpe
                : rpe // ignore: cast_nullable_to_non_nullable
                      as double?,
            suggestedWeightKg: freezed == suggestedWeightKg
                ? _value.suggestedWeightKg
                : suggestedWeightKg // ignore: cast_nullable_to_non_nullable
                      as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TrainingSetImplCopyWith<$Res>
    implements $TrainingSetCopyWith<$Res> {
  factory _$$TrainingSetImplCopyWith(
    _$TrainingSetImpl value,
    $Res Function(_$TrainingSetImpl) then,
  ) = __$$TrainingSetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int setNumber,
    int? reps,
    double? weightKg,
    int? restSeconds,
    int? durationSeconds,
    double? distanceMeters,
    String? notes,
    DateTime? completedAt,
    DateTime? startedAt,
    TrainingSetKind setKind,
    String clientUuid,
    double? rpe,
    double? suggestedWeightKg,
  });
}

/// @nodoc
class __$$TrainingSetImplCopyWithImpl<$Res>
    extends _$TrainingSetCopyWithImpl<$Res, _$TrainingSetImpl>
    implements _$$TrainingSetImplCopyWith<$Res> {
  __$$TrainingSetImplCopyWithImpl(
    _$TrainingSetImpl _value,
    $Res Function(_$TrainingSetImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TrainingSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setNumber = null,
    Object? reps = freezed,
    Object? weightKg = freezed,
    Object? restSeconds = freezed,
    Object? durationSeconds = freezed,
    Object? distanceMeters = freezed,
    Object? notes = freezed,
    Object? completedAt = freezed,
    Object? startedAt = freezed,
    Object? setKind = null,
    Object? clientUuid = null,
    Object? rpe = freezed,
    Object? suggestedWeightKg = freezed,
  }) {
    return _then(
      _$TrainingSetImpl(
        setNumber: null == setNumber
            ? _value.setNumber
            : setNumber // ignore: cast_nullable_to_non_nullable
                  as int,
        reps: freezed == reps
            ? _value.reps
            : reps // ignore: cast_nullable_to_non_nullable
                  as int?,
        weightKg: freezed == weightKg
            ? _value.weightKg
            : weightKg // ignore: cast_nullable_to_non_nullable
                  as double?,
        restSeconds: freezed == restSeconds
            ? _value.restSeconds
            : restSeconds // ignore: cast_nullable_to_non_nullable
                  as int?,
        durationSeconds: freezed == durationSeconds
            ? _value.durationSeconds
            : durationSeconds // ignore: cast_nullable_to_non_nullable
                  as int?,
        distanceMeters: freezed == distanceMeters
            ? _value.distanceMeters
            : distanceMeters // ignore: cast_nullable_to_non_nullable
                  as double?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        completedAt: freezed == completedAt
            ? _value.completedAt
            : completedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        startedAt: freezed == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        setKind: null == setKind
            ? _value.setKind
            : setKind // ignore: cast_nullable_to_non_nullable
                  as TrainingSetKind,
        clientUuid: null == clientUuid
            ? _value.clientUuid
            : clientUuid // ignore: cast_nullable_to_non_nullable
                  as String,
        rpe: freezed == rpe
            ? _value.rpe
            : rpe // ignore: cast_nullable_to_non_nullable
                  as double?,
        suggestedWeightKg: freezed == suggestedWeightKg
            ? _value.suggestedWeightKg
            : suggestedWeightKg // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TrainingSetImpl implements _TrainingSet {
  const _$TrainingSetImpl({
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.restSeconds,
    this.durationSeconds,
    this.distanceMeters,
    this.notes,
    this.completedAt,
    this.startedAt,
    this.setKind = TrainingSetKind.working,
    required this.clientUuid,
    this.rpe,
    this.suggestedWeightKg,
  });

  factory _$TrainingSetImpl.fromJson(Map<String, dynamic> json) =>
      _$$TrainingSetImplFromJson(json);

  @override
  final int setNumber;
  @override
  final int? reps;
  @override
  final double? weightKg;
  @override
  final int? restSeconds;
  @override
  final int? durationSeconds;
  @override
  final double? distanceMeters;
  @override
  final String? notes;
  @override
  final DateTime? completedAt;
  @override
  final DateTime? startedAt;
  @override
  @JsonKey()
  final TrainingSetKind setKind;
  @override
  final String clientUuid;
  @override
  final double? rpe;
  @override
  final double? suggestedWeightKg;

  @override
  String toString() {
    return 'TrainingSet(setNumber: $setNumber, reps: $reps, weightKg: $weightKg, restSeconds: $restSeconds, durationSeconds: $durationSeconds, distanceMeters: $distanceMeters, notes: $notes, completedAt: $completedAt, startedAt: $startedAt, setKind: $setKind, clientUuid: $clientUuid, rpe: $rpe, suggestedWeightKg: $suggestedWeightKg)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TrainingSetImpl &&
            (identical(other.setNumber, setNumber) ||
                other.setNumber == setNumber) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.restSeconds, restSeconds) ||
                other.restSeconds == restSeconds) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.distanceMeters, distanceMeters) ||
                other.distanceMeters == distanceMeters) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.setKind, setKind) || other.setKind == setKind) &&
            (identical(other.clientUuid, clientUuid) ||
                other.clientUuid == clientUuid) &&
            (identical(other.rpe, rpe) || other.rpe == rpe) &&
            (identical(other.suggestedWeightKg, suggestedWeightKg) ||
                other.suggestedWeightKg == suggestedWeightKg));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    setNumber,
    reps,
    weightKg,
    restSeconds,
    durationSeconds,
    distanceMeters,
    notes,
    completedAt,
    startedAt,
    setKind,
    clientUuid,
    rpe,
    suggestedWeightKg,
  );

  /// Create a copy of TrainingSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TrainingSetImplCopyWith<_$TrainingSetImpl> get copyWith =>
      __$$TrainingSetImplCopyWithImpl<_$TrainingSetImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TrainingSetImplToJson(this);
  }
}

abstract class _TrainingSet implements TrainingSet {
  const factory _TrainingSet({
    required final int setNumber,
    final int? reps,
    final double? weightKg,
    final int? restSeconds,
    final int? durationSeconds,
    final double? distanceMeters,
    final String? notes,
    final DateTime? completedAt,
    final DateTime? startedAt,
    final TrainingSetKind setKind,
    required final String clientUuid,
    final double? rpe,
    final double? suggestedWeightKg,
  }) = _$TrainingSetImpl;

  factory _TrainingSet.fromJson(Map<String, dynamic> json) =
      _$TrainingSetImpl.fromJson;

  @override
  int get setNumber;
  @override
  int? get reps;
  @override
  double? get weightKg;
  @override
  int? get restSeconds;
  @override
  int? get durationSeconds;
  @override
  double? get distanceMeters;
  @override
  String? get notes;
  @override
  DateTime? get completedAt;
  @override
  DateTime? get startedAt;
  @override
  TrainingSetKind get setKind;
  @override
  String get clientUuid;
  @override
  double? get rpe;
  @override
  double? get suggestedWeightKg;

  /// Create a copy of TrainingSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TrainingSetImplCopyWith<_$TrainingSetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TrainingExercise _$TrainingExerciseFromJson(Map<String, dynamic> json) {
  return _TrainingExercise.fromJson(json);
}

/// @nodoc
mixin _$TrainingExercise {
  int get exerciseId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String get exerciseType => throw _privateConstructorUsedError;

  /// 超级组标记：同一 `supersetId` 的动作视为一组超级组；null 表示普通动作。
  int? get supersetId => throw _privateConstructorUsedError;

  /// 徒手/自重动作：未填重量时预填并展示用户体重。
  bool get isBodyweight => throw _privateConstructorUsedError;
  List<TrainingSet> get sets => throw _privateConstructorUsedError;
  List<GhostSet> get ghostSets => throw _privateConstructorUsedError;
  DateTime? get ghostSessionDate => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  int? get restTargetSeconds => throw _privateConstructorUsedError;
  String get weightUnit => throw _privateConstructorUsedError;

  /// Serializes this TrainingExercise to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TrainingExercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TrainingExerciseCopyWith<TrainingExercise> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TrainingExerciseCopyWith<$Res> {
  factory $TrainingExerciseCopyWith(
    TrainingExercise value,
    $Res Function(TrainingExercise) then,
  ) = _$TrainingExerciseCopyWithImpl<$Res, TrainingExercise>;
  @useResult
  $Res call({
    int exerciseId,
    String name,
    String? imageUrl,
    String exerciseType,
    int? supersetId,
    bool isBodyweight,
    List<TrainingSet> sets,
    List<GhostSet> ghostSets,
    DateTime? ghostSessionDate,
    String? notes,
    int? restTargetSeconds,
    String weightUnit,
  });
}

/// @nodoc
class _$TrainingExerciseCopyWithImpl<$Res, $Val extends TrainingExercise>
    implements $TrainingExerciseCopyWith<$Res> {
  _$TrainingExerciseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TrainingExercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exerciseId = null,
    Object? name = null,
    Object? imageUrl = freezed,
    Object? exerciseType = null,
    Object? supersetId = freezed,
    Object? isBodyweight = null,
    Object? sets = null,
    Object? ghostSets = null,
    Object? ghostSessionDate = freezed,
    Object? notes = freezed,
    Object? restTargetSeconds = freezed,
    Object? weightUnit = null,
  }) {
    return _then(
      _value.copyWith(
            exerciseId: null == exerciseId
                ? _value.exerciseId
                : exerciseId // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            exerciseType: null == exerciseType
                ? _value.exerciseType
                : exerciseType // ignore: cast_nullable_to_non_nullable
                      as String,
            supersetId: freezed == supersetId
                ? _value.supersetId
                : supersetId // ignore: cast_nullable_to_non_nullable
                      as int?,
            isBodyweight: null == isBodyweight
                ? _value.isBodyweight
                : isBodyweight // ignore: cast_nullable_to_non_nullable
                      as bool,
            sets: null == sets
                ? _value.sets
                : sets // ignore: cast_nullable_to_non_nullable
                      as List<TrainingSet>,
            ghostSets: null == ghostSets
                ? _value.ghostSets
                : ghostSets // ignore: cast_nullable_to_non_nullable
                      as List<GhostSet>,
            ghostSessionDate: freezed == ghostSessionDate
                ? _value.ghostSessionDate
                : ghostSessionDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            restTargetSeconds: freezed == restTargetSeconds
                ? _value.restTargetSeconds
                : restTargetSeconds // ignore: cast_nullable_to_non_nullable
                      as int?,
            weightUnit: null == weightUnit
                ? _value.weightUnit
                : weightUnit // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TrainingExerciseImplCopyWith<$Res>
    implements $TrainingExerciseCopyWith<$Res> {
  factory _$$TrainingExerciseImplCopyWith(
    _$TrainingExerciseImpl value,
    $Res Function(_$TrainingExerciseImpl) then,
  ) = __$$TrainingExerciseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int exerciseId,
    String name,
    String? imageUrl,
    String exerciseType,
    int? supersetId,
    bool isBodyweight,
    List<TrainingSet> sets,
    List<GhostSet> ghostSets,
    DateTime? ghostSessionDate,
    String? notes,
    int? restTargetSeconds,
    String weightUnit,
  });
}

/// @nodoc
class __$$TrainingExerciseImplCopyWithImpl<$Res>
    extends _$TrainingExerciseCopyWithImpl<$Res, _$TrainingExerciseImpl>
    implements _$$TrainingExerciseImplCopyWith<$Res> {
  __$$TrainingExerciseImplCopyWithImpl(
    _$TrainingExerciseImpl _value,
    $Res Function(_$TrainingExerciseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TrainingExercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exerciseId = null,
    Object? name = null,
    Object? imageUrl = freezed,
    Object? exerciseType = null,
    Object? supersetId = freezed,
    Object? isBodyweight = null,
    Object? sets = null,
    Object? ghostSets = null,
    Object? ghostSessionDate = freezed,
    Object? notes = freezed,
    Object? restTargetSeconds = freezed,
    Object? weightUnit = null,
  }) {
    return _then(
      _$TrainingExerciseImpl(
        exerciseId: null == exerciseId
            ? _value.exerciseId
            : exerciseId // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        exerciseType: null == exerciseType
            ? _value.exerciseType
            : exerciseType // ignore: cast_nullable_to_non_nullable
                  as String,
        supersetId: freezed == supersetId
            ? _value.supersetId
            : supersetId // ignore: cast_nullable_to_non_nullable
                  as int?,
        isBodyweight: null == isBodyweight
            ? _value.isBodyweight
            : isBodyweight // ignore: cast_nullable_to_non_nullable
                  as bool,
        sets: null == sets
            ? _value._sets
            : sets // ignore: cast_nullable_to_non_nullable
                  as List<TrainingSet>,
        ghostSets: null == ghostSets
            ? _value._ghostSets
            : ghostSets // ignore: cast_nullable_to_non_nullable
                  as List<GhostSet>,
        ghostSessionDate: freezed == ghostSessionDate
            ? _value.ghostSessionDate
            : ghostSessionDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        restTargetSeconds: freezed == restTargetSeconds
            ? _value.restTargetSeconds
            : restTargetSeconds // ignore: cast_nullable_to_non_nullable
                  as int?,
        weightUnit: null == weightUnit
            ? _value.weightUnit
            : weightUnit // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TrainingExerciseImpl implements _TrainingExercise {
  const _$TrainingExerciseImpl({
    required this.exerciseId,
    required this.name,
    this.imageUrl,
    this.exerciseType = 'compound',
    this.supersetId,
    this.isBodyweight = false,
    final List<TrainingSet> sets = const [],
    final List<GhostSet> ghostSets = const [],
    this.ghostSessionDate,
    this.notes,
    this.restTargetSeconds,
    this.weightUnit = 'kg',
  }) : _sets = sets,
       _ghostSets = ghostSets;

  factory _$TrainingExerciseImpl.fromJson(Map<String, dynamic> json) =>
      _$$TrainingExerciseImplFromJson(json);

  @override
  final int exerciseId;
  @override
  final String name;
  @override
  final String? imageUrl;
  @override
  @JsonKey()
  final String exerciseType;

  /// 超级组标记：同一 `supersetId` 的动作视为一组超级组；null 表示普通动作。
  @override
  final int? supersetId;

  /// 徒手/自重动作：未填重量时预填并展示用户体重。
  @override
  @JsonKey()
  final bool isBodyweight;
  final List<TrainingSet> _sets;
  @override
  @JsonKey()
  List<TrainingSet> get sets {
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sets);
  }

  final List<GhostSet> _ghostSets;
  @override
  @JsonKey()
  List<GhostSet> get ghostSets {
    if (_ghostSets is EqualUnmodifiableListView) return _ghostSets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ghostSets);
  }

  @override
  final DateTime? ghostSessionDate;
  @override
  final String? notes;
  @override
  final int? restTargetSeconds;
  @override
  @JsonKey()
  final String weightUnit;

  @override
  String toString() {
    return 'TrainingExercise(exerciseId: $exerciseId, name: $name, imageUrl: $imageUrl, exerciseType: $exerciseType, supersetId: $supersetId, isBodyweight: $isBodyweight, sets: $sets, ghostSets: $ghostSets, ghostSessionDate: $ghostSessionDate, notes: $notes, restTargetSeconds: $restTargetSeconds, weightUnit: $weightUnit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TrainingExerciseImpl &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.exerciseType, exerciseType) ||
                other.exerciseType == exerciseType) &&
            (identical(other.supersetId, supersetId) ||
                other.supersetId == supersetId) &&
            (identical(other.isBodyweight, isBodyweight) ||
                other.isBodyweight == isBodyweight) &&
            const DeepCollectionEquality().equals(other._sets, _sets) &&
            const DeepCollectionEquality().equals(other._ghostSets, _ghostSets) &&
            (identical(other.ghostSessionDate, ghostSessionDate) ||
                other.ghostSessionDate == ghostSessionDate) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.restTargetSeconds, restTargetSeconds) ||
                other.restTargetSeconds == restTargetSeconds) &&
            (identical(other.weightUnit, weightUnit) ||
                other.weightUnit == weightUnit));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    exerciseId,
    name,
    imageUrl,
    exerciseType,
    supersetId,
    isBodyweight,
    const DeepCollectionEquality().hash(_sets),
    const DeepCollectionEquality().hash(_ghostSets),
    ghostSessionDate,
    notes,
    restTargetSeconds,
    weightUnit,
  );

  /// Create a copy of TrainingExercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TrainingExerciseImplCopyWith<_$TrainingExerciseImpl> get copyWith =>
      __$$TrainingExerciseImplCopyWithImpl<_$TrainingExerciseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TrainingExerciseImplToJson(this);
  }
}

abstract class _TrainingExercise implements TrainingExercise {
  const factory _TrainingExercise({
    required final int exerciseId,
    required final String name,
    final String? imageUrl,
    final String exerciseType,
    final int? supersetId,
    final bool isBodyweight,
    final List<TrainingSet> sets,
    final List<GhostSet> ghostSets,
    final DateTime? ghostSessionDate,
    final String? notes,
    final int? restTargetSeconds,
    final String weightUnit,
  }) = _$TrainingExerciseImpl;

  factory _TrainingExercise.fromJson(Map<String, dynamic> json) =
      _$TrainingExerciseImpl.fromJson;

  @override
  int get exerciseId;
  @override
  String get name;
  @override
  String? get imageUrl;
  @override
  String get exerciseType;

  /// 超级组标记：同一 `supersetId` 的动作视为一组超级组；null 表示普通动作。
  @override
  int? get supersetId;

  /// 徒手/自重动作：未填重量时预填并展示用户体重。
  @override
  bool get isBodyweight;
  @override
  List<TrainingSet> get sets;
  @override
  List<GhostSet> get ghostSets;
  @override
  DateTime? get ghostSessionDate;
  @override
  String? get notes;
  @override
  int? get restTargetSeconds;
  @override
  String get weightUnit;

  /// Create a copy of TrainingExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TrainingExerciseImplCopyWith<_$TrainingExerciseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ActiveTraining _$ActiveTrainingFromJson(Map<String, dynamic> json) {
  return _ActiveTraining.fromJson(json);
}

/// @nodoc
mixin _$ActiveTraining {
  int get sessionId => throw _privateConstructorUsedError;
  String get clientUuid => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  List<TrainingExercise> get exercises => throw _privateConstructorUsedError;

  /// 当前展开的动作 id（表示正在练的那一个）；null = 全部收起。
  int? get focusedExerciseId => throw _privateConstructorUsedError;
  int get restBonusSeconds => throw _privateConstructorUsedError;

  /// Serializes this ActiveTraining to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ActiveTraining
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ActiveTrainingCopyWith<ActiveTraining> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ActiveTrainingCopyWith<$Res> {
  factory $ActiveTrainingCopyWith(
    ActiveTraining value,
    $Res Function(ActiveTraining) then,
  ) = _$ActiveTrainingCopyWithImpl<$Res, ActiveTraining>;
  @useResult
  $Res call({
    int sessionId,
    String clientUuid,
    DateTime startedAt,
    String status,
    List<TrainingExercise> exercises,
    int? focusedExerciseId,
    int restBonusSeconds,
  });
}

/// @nodoc
class _$ActiveTrainingCopyWithImpl<$Res, $Val extends ActiveTraining>
    implements $ActiveTrainingCopyWith<$Res> {
  _$ActiveTrainingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ActiveTraining
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? clientUuid = null,
    Object? startedAt = null,
    Object? status = null,
    Object? exercises = null,
    Object? focusedExerciseId = freezed,
    Object? restBonusSeconds = null,
  }) {
    return _then(
      _value.copyWith(
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as int,
            clientUuid: null == clientUuid
                ? _value.clientUuid
                : clientUuid // ignore: cast_nullable_to_non_nullable
                      as String,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            exercises: null == exercises
                ? _value.exercises
                : exercises // ignore: cast_nullable_to_non_nullable
                      as List<TrainingExercise>,
            focusedExerciseId: freezed == focusedExerciseId
                ? _value.focusedExerciseId
                : focusedExerciseId // ignore: cast_nullable_to_non_nullable
                      as int?,
            restBonusSeconds: null == restBonusSeconds
                ? _value.restBonusSeconds
                : restBonusSeconds // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ActiveTrainingImplCopyWith<$Res>
    implements $ActiveTrainingCopyWith<$Res> {
  factory _$$ActiveTrainingImplCopyWith(
    _$ActiveTrainingImpl value,
    $Res Function(_$ActiveTrainingImpl) then,
  ) = __$$ActiveTrainingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int sessionId,
    String clientUuid,
    DateTime startedAt,
    String status,
    List<TrainingExercise> exercises,
    int? focusedExerciseId,
    int restBonusSeconds,
  });
}

/// @nodoc
class __$$ActiveTrainingImplCopyWithImpl<$Res>
    extends _$ActiveTrainingCopyWithImpl<$Res, _$ActiveTrainingImpl>
    implements _$$ActiveTrainingImplCopyWith<$Res> {
  __$$ActiveTrainingImplCopyWithImpl(
    _$ActiveTrainingImpl _value,
    $Res Function(_$ActiveTrainingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ActiveTraining
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? clientUuid = null,
    Object? startedAt = null,
    Object? status = null,
    Object? exercises = null,
    Object? focusedExerciseId = freezed,
    Object? restBonusSeconds = null,
  }) {
    return _then(
      _$ActiveTrainingImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as int,
        clientUuid: null == clientUuid
            ? _value.clientUuid
            : clientUuid // ignore: cast_nullable_to_non_nullable
                  as String,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        exercises: null == exercises
            ? _value._exercises
            : exercises // ignore: cast_nullable_to_non_nullable
                  as List<TrainingExercise>,
        focusedExerciseId: freezed == focusedExerciseId
            ? _value.focusedExerciseId
            : focusedExerciseId // ignore: cast_nullable_to_non_nullable
                  as int?,
        restBonusSeconds: null == restBonusSeconds
            ? _value.restBonusSeconds
            : restBonusSeconds // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ActiveTrainingImpl implements _ActiveTraining {
  const _$ActiveTrainingImpl({
    required this.sessionId,
    required this.clientUuid,
    required this.startedAt,
    this.status = 'in_progress',
    final List<TrainingExercise> exercises = const [],
    this.focusedExerciseId,
    this.restBonusSeconds = 0,
  }) : _exercises = exercises;

  factory _$ActiveTrainingImpl.fromJson(Map<String, dynamic> json) =>
      _$$ActiveTrainingImplFromJson(json);

  @override
  final int sessionId;
  @override
  final String clientUuid;
  @override
  final DateTime startedAt;
  @override
  @JsonKey()
  final String status;
  final List<TrainingExercise> _exercises;
  @override
  @JsonKey()
  List<TrainingExercise> get exercises {
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exercises);
  }

  /// 当前展开的动作 id（表示正在练的那一个）；null = 全部收起。
  @override
  final int? focusedExerciseId;
  @override
  @JsonKey()
  final int restBonusSeconds;

  @override
  String toString() {
    return 'ActiveTraining(sessionId: $sessionId, clientUuid: $clientUuid, startedAt: $startedAt, status: $status, exercises: $exercises, focusedExerciseId: $focusedExerciseId, restBonusSeconds: $restBonusSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ActiveTrainingImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.clientUuid, clientUuid) ||
                other.clientUuid == clientUuid) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(
              other._exercises,
              _exercises,
            ) &&
            (identical(other.focusedExerciseId, focusedExerciseId) ||
                other.focusedExerciseId == focusedExerciseId) &&
            (identical(other.restBonusSeconds, restBonusSeconds) ||
                other.restBonusSeconds == restBonusSeconds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    sessionId,
    clientUuid,
    startedAt,
    status,
    const DeepCollectionEquality().hash(_exercises),
    focusedExerciseId,
    restBonusSeconds,
  );

  /// Create a copy of ActiveTraining
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ActiveTrainingImplCopyWith<_$ActiveTrainingImpl> get copyWith =>
      __$$ActiveTrainingImplCopyWithImpl<_$ActiveTrainingImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ActiveTrainingImplToJson(this);
  }
}

abstract class _ActiveTraining implements ActiveTraining {
  const factory _ActiveTraining({
    required final int sessionId,
    required final String clientUuid,
    required final DateTime startedAt,
    final String status,
    final List<TrainingExercise> exercises,
    final int? focusedExerciseId,
    final int restBonusSeconds,
  }) = _$ActiveTrainingImpl;

  factory _ActiveTraining.fromJson(Map<String, dynamic> json) =
      _$ActiveTrainingImpl.fromJson;

  @override
  int get sessionId;
  @override
  String get clientUuid;
  @override
  DateTime get startedAt;
  @override
  String get status;
  @override
  List<TrainingExercise> get exercises;

  /// 当前展开的动作 id（表示正在练的那一个）；null = 全部收起。
  @override
  int? get focusedExerciseId;
  @override
  int get restBonusSeconds;

  /// Create a copy of ActiveTraining
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ActiveTrainingImplCopyWith<_$ActiveTrainingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
