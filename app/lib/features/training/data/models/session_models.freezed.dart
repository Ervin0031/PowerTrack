// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SessionCreate _$SessionCreateFromJson(Map<String, dynamic> json) {
  return _SessionCreate.fromJson(json);
}

/// @nodoc
mixin _$SessionCreate {
  String get clientUuid => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;

  /// Serializes this SessionCreate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SessionCreate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionCreateCopyWith<SessionCreate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionCreateCopyWith<$Res> {
  factory $SessionCreateCopyWith(
    SessionCreate value,
    $Res Function(SessionCreate) then,
  ) = _$SessionCreateCopyWithImpl<$Res, SessionCreate>;
  @useResult
  $Res call({String clientUuid, DateTime startedAt});
}

/// @nodoc
class _$SessionCreateCopyWithImpl<$Res, $Val extends SessionCreate>
    implements $SessionCreateCopyWith<$Res> {
  _$SessionCreateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionCreate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? clientUuid = null, Object? startedAt = null}) {
    return _then(
      _value.copyWith(
            clientUuid: null == clientUuid
                ? _value.clientUuid
                : clientUuid // ignore: cast_nullable_to_non_nullable
                      as String,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SessionCreateImplCopyWith<$Res>
    implements $SessionCreateCopyWith<$Res> {
  factory _$$SessionCreateImplCopyWith(
    _$SessionCreateImpl value,
    $Res Function(_$SessionCreateImpl) then,
  ) = __$$SessionCreateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String clientUuid, DateTime startedAt});
}

/// @nodoc
class __$$SessionCreateImplCopyWithImpl<$Res>
    extends _$SessionCreateCopyWithImpl<$Res, _$SessionCreateImpl>
    implements _$$SessionCreateImplCopyWith<$Res> {
  __$$SessionCreateImplCopyWithImpl(
    _$SessionCreateImpl _value,
    $Res Function(_$SessionCreateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionCreate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? clientUuid = null, Object? startedAt = null}) {
    return _then(
      _$SessionCreateImpl(
        clientUuid: null == clientUuid
            ? _value.clientUuid
            : clientUuid // ignore: cast_nullable_to_non_nullable
                  as String,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SessionCreateImpl implements _SessionCreate {
  const _$SessionCreateImpl({
    required this.clientUuid,
    required this.startedAt,
  });

  factory _$SessionCreateImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionCreateImplFromJson(json);

  @override
  final String clientUuid;
  @override
  final DateTime startedAt;

  @override
  String toString() {
    return 'SessionCreate(clientUuid: $clientUuid, startedAt: $startedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionCreateImpl &&
            (identical(other.clientUuid, clientUuid) ||
                other.clientUuid == clientUuid) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, clientUuid, startedAt);

  /// Create a copy of SessionCreate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionCreateImplCopyWith<_$SessionCreateImpl> get copyWith =>
      __$$SessionCreateImplCopyWithImpl<_$SessionCreateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionCreateImplToJson(this);
  }
}

abstract class _SessionCreate implements SessionCreate {
  const factory _SessionCreate({
    required final String clientUuid,
    required final DateTime startedAt,
  }) = _$SessionCreateImpl;

  factory _SessionCreate.fromJson(Map<String, dynamic> json) =
      _$SessionCreateImpl.fromJson;

  @override
  String get clientUuid;
  @override
  DateTime get startedAt;

  /// Create a copy of SessionCreate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionCreateImplCopyWith<_$SessionCreateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WorkoutSetCreate _$WorkoutSetCreateFromJson(Map<String, dynamic> json) {
  return _WorkoutSetCreate.fromJson(json);
}

/// @nodoc
mixin _$WorkoutSetCreate {
  int get exerciseId => throw _privateConstructorUsedError;
  int get setNumber => throw _privateConstructorUsedError;
  int? get reps => throw _privateConstructorUsedError;
  double? get weightKg => throw _privateConstructorUsedError;
  int? get durationSeconds => throw _privateConstructorUsedError;
  double? get distanceMeters => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  String get clientUuid => throw _privateConstructorUsedError;
  double? get rpe => throw _privateConstructorUsedError;

  /// Serializes this WorkoutSetCreate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkoutSetCreate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkoutSetCreateCopyWith<WorkoutSetCreate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkoutSetCreateCopyWith<$Res> {
  factory $WorkoutSetCreateCopyWith(
    WorkoutSetCreate value,
    $Res Function(WorkoutSetCreate) then,
  ) = _$WorkoutSetCreateCopyWithImpl<$Res, WorkoutSetCreate>;
  @useResult
  $Res call({
    int exerciseId,
    int setNumber,
    int? reps,
    double? weightKg,
    int? durationSeconds,
    double? distanceMeters,
    String? notes,
    DateTime? completedAt,
    String clientUuid,
    double? rpe,
  });
}

/// @nodoc
class _$WorkoutSetCreateCopyWithImpl<$Res, $Val extends WorkoutSetCreate>
    implements $WorkoutSetCreateCopyWith<$Res> {
  _$WorkoutSetCreateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WorkoutSetCreate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exerciseId = null,
    Object? setNumber = null,
    Object? reps = freezed,
    Object? weightKg = freezed,
    Object? durationSeconds = freezed,
    Object? distanceMeters = freezed,
    Object? notes = freezed,
    Object? completedAt = freezed,
    Object? clientUuid = null,
    Object? rpe = freezed,
  }) {
    return _then(
      _value.copyWith(
            exerciseId: null == exerciseId
                ? _value.exerciseId
                : exerciseId // ignore: cast_nullable_to_non_nullable
                      as int,
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
            clientUuid: null == clientUuid
                ? _value.clientUuid
                : clientUuid // ignore: cast_nullable_to_non_nullable
                      as String,
            rpe: freezed == rpe
                ? _value.rpe
                : rpe // ignore: cast_nullable_to_non_nullable
                      as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WorkoutSetCreateImplCopyWith<$Res>
    implements $WorkoutSetCreateCopyWith<$Res> {
  factory _$$WorkoutSetCreateImplCopyWith(
    _$WorkoutSetCreateImpl value,
    $Res Function(_$WorkoutSetCreateImpl) then,
  ) = __$$WorkoutSetCreateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int exerciseId,
    int setNumber,
    int? reps,
    double? weightKg,
    int? durationSeconds,
    double? distanceMeters,
    String? notes,
    DateTime? completedAt,
    String clientUuid,
    double? rpe,
  });
}

/// @nodoc
class __$$WorkoutSetCreateImplCopyWithImpl<$Res>
    extends _$WorkoutSetCreateCopyWithImpl<$Res, _$WorkoutSetCreateImpl>
    implements _$$WorkoutSetCreateImplCopyWith<$Res> {
  __$$WorkoutSetCreateImplCopyWithImpl(
    _$WorkoutSetCreateImpl _value,
    $Res Function(_$WorkoutSetCreateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WorkoutSetCreate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exerciseId = null,
    Object? setNumber = null,
    Object? reps = freezed,
    Object? weightKg = freezed,
    Object? durationSeconds = freezed,
    Object? distanceMeters = freezed,
    Object? notes = freezed,
    Object? completedAt = freezed,
    Object? clientUuid = null,
    Object? rpe = freezed,
  }) {
    return _then(
      _$WorkoutSetCreateImpl(
        exerciseId: null == exerciseId
            ? _value.exerciseId
            : exerciseId // ignore: cast_nullable_to_non_nullable
                  as int,
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
        clientUuid: null == clientUuid
            ? _value.clientUuid
            : clientUuid // ignore: cast_nullable_to_non_nullable
                  as String,
        rpe: freezed == rpe
            ? _value.rpe
            : rpe // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkoutSetCreateImpl implements _WorkoutSetCreate {
  const _$WorkoutSetCreateImpl({
    required this.exerciseId,
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceMeters,
    this.notes,
    this.completedAt,
    required this.clientUuid,
    this.rpe,
  });

  factory _$WorkoutSetCreateImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkoutSetCreateImplFromJson(json);

  @override
  final int exerciseId;
  @override
  final int setNumber;
  @override
  final int? reps;
  @override
  final double? weightKg;
  @override
  final int? durationSeconds;
  @override
  final double? distanceMeters;
  @override
  final String? notes;
  @override
  final DateTime? completedAt;
  @override
  final String clientUuid;
  @override
  final double? rpe;

  @override
  String toString() {
    return 'WorkoutSetCreate(exerciseId: $exerciseId, setNumber: $setNumber, reps: $reps, weightKg: $weightKg, durationSeconds: $durationSeconds, distanceMeters: $distanceMeters, notes: $notes, completedAt: $completedAt, clientUuid: $clientUuid, rpe: $rpe)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkoutSetCreateImpl &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.setNumber, setNumber) ||
                other.setNumber == setNumber) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.distanceMeters, distanceMeters) ||
                other.distanceMeters == distanceMeters) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.clientUuid, clientUuid) ||
                other.clientUuid == clientUuid) &&
            (identical(other.rpe, rpe) || other.rpe == rpe));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    exerciseId,
    setNumber,
    reps,
    weightKg,
    durationSeconds,
    distanceMeters,
    notes,
    completedAt,
    clientUuid,
    rpe,
  );

  /// Create a copy of WorkoutSetCreate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkoutSetCreateImplCopyWith<_$WorkoutSetCreateImpl> get copyWith =>
      __$$WorkoutSetCreateImplCopyWithImpl<_$WorkoutSetCreateImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkoutSetCreateImplToJson(this);
  }
}

abstract class _WorkoutSetCreate implements WorkoutSetCreate {
  const factory _WorkoutSetCreate({
    required final int exerciseId,
    required final int setNumber,
    final int? reps,
    final double? weightKg,
    final int? durationSeconds,
    final double? distanceMeters,
    final String? notes,
    final DateTime? completedAt,
    required final String clientUuid,
    final double? rpe,
  }) = _$WorkoutSetCreateImpl;

  factory _WorkoutSetCreate.fromJson(Map<String, dynamic> json) =
      _$WorkoutSetCreateImpl.fromJson;

  @override
  int get exerciseId;
  @override
  int get setNumber;
  @override
  int? get reps;
  @override
  double? get weightKg;
  @override
  int? get durationSeconds;
  @override
  double? get distanceMeters;
  @override
  String? get notes;
  @override
  DateTime? get completedAt;
  @override
  String get clientUuid;
  @override
  double? get rpe;

  /// Create a copy of WorkoutSetCreate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkoutSetCreateImplCopyWith<_$WorkoutSetCreateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SessionComplete _$SessionCompleteFromJson(Map<String, dynamic> json) {
  return _SessionComplete.fromJson(json);
}

/// @nodoc
mixin _$SessionComplete {
  String get clientUuid => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;
  DateTime get completedAt => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  List<WorkoutSetCreate> get sets => throw _privateConstructorUsedError;

  /// Serializes this SessionComplete to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SessionComplete
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionCompleteCopyWith<SessionComplete> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionCompleteCopyWith<$Res> {
  factory $SessionCompleteCopyWith(
    SessionComplete value,
    $Res Function(SessionComplete) then,
  ) = _$SessionCompleteCopyWithImpl<$Res, SessionComplete>;
  @useResult
  $Res call({
    String clientUuid,
    DateTime startedAt,
    DateTime completedAt,
    String? notes,
    List<WorkoutSetCreate> sets,
  });
}

/// @nodoc
class _$SessionCompleteCopyWithImpl<$Res, $Val extends SessionComplete>
    implements $SessionCompleteCopyWith<$Res> {
  _$SessionCompleteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionComplete
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? clientUuid = null,
    Object? startedAt = null,
    Object? completedAt = null,
    Object? notes = freezed,
    Object? sets = null,
  }) {
    return _then(
      _value.copyWith(
            clientUuid: null == clientUuid
                ? _value.clientUuid
                : clientUuid // ignore: cast_nullable_to_non_nullable
                      as String,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            completedAt: null == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            sets: null == sets
                ? _value.sets
                : sets // ignore: cast_nullable_to_non_nullable
                      as List<WorkoutSetCreate>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SessionCompleteImplCopyWith<$Res>
    implements $SessionCompleteCopyWith<$Res> {
  factory _$$SessionCompleteImplCopyWith(
    _$SessionCompleteImpl value,
    $Res Function(_$SessionCompleteImpl) then,
  ) = __$$SessionCompleteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String clientUuid,
    DateTime startedAt,
    DateTime completedAt,
    String? notes,
    List<WorkoutSetCreate> sets,
  });
}

/// @nodoc
class __$$SessionCompleteImplCopyWithImpl<$Res>
    extends _$SessionCompleteCopyWithImpl<$Res, _$SessionCompleteImpl>
    implements _$$SessionCompleteImplCopyWith<$Res> {
  __$$SessionCompleteImplCopyWithImpl(
    _$SessionCompleteImpl _value,
    $Res Function(_$SessionCompleteImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionComplete
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? clientUuid = null,
    Object? startedAt = null,
    Object? completedAt = null,
    Object? notes = freezed,
    Object? sets = null,
  }) {
    return _then(
      _$SessionCompleteImpl(
        clientUuid: null == clientUuid
            ? _value.clientUuid
            : clientUuid // ignore: cast_nullable_to_non_nullable
                  as String,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        completedAt: null == completedAt
            ? _value.completedAt
            : completedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        sets: null == sets
            ? _value._sets
            : sets // ignore: cast_nullable_to_non_nullable
                  as List<WorkoutSetCreate>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SessionCompleteImpl implements _SessionComplete {
  const _$SessionCompleteImpl({
    required this.clientUuid,
    required this.startedAt,
    required this.completedAt,
    this.notes,
    final List<WorkoutSetCreate> sets = const [],
  }) : _sets = sets;

  factory _$SessionCompleteImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionCompleteImplFromJson(json);

  @override
  final String clientUuid;
  @override
  final DateTime startedAt;
  @override
  final DateTime completedAt;
  @override
  final String? notes;
  final List<WorkoutSetCreate> _sets;
  @override
  @JsonKey()
  List<WorkoutSetCreate> get sets {
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sets);
  }

  @override
  String toString() {
    return 'SessionComplete(clientUuid: $clientUuid, startedAt: $startedAt, completedAt: $completedAt, notes: $notes, sets: $sets)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionCompleteImpl &&
            (identical(other.clientUuid, clientUuid) ||
                other.clientUuid == clientUuid) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            const DeepCollectionEquality().equals(other._sets, _sets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    clientUuid,
    startedAt,
    completedAt,
    notes,
    const DeepCollectionEquality().hash(_sets),
  );

  /// Create a copy of SessionComplete
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionCompleteImplCopyWith<_$SessionCompleteImpl> get copyWith =>
      __$$SessionCompleteImplCopyWithImpl<_$SessionCompleteImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionCompleteImplToJson(this);
  }
}

abstract class _SessionComplete implements SessionComplete {
  const factory _SessionComplete({
    required final String clientUuid,
    required final DateTime startedAt,
    required final DateTime completedAt,
    final String? notes,
    final List<WorkoutSetCreate> sets,
  }) = _$SessionCompleteImpl;

  factory _SessionComplete.fromJson(Map<String, dynamic> json) =
      _$SessionCompleteImpl.fromJson;

  @override
  String get clientUuid;
  @override
  DateTime get startedAt;
  @override
  DateTime get completedAt;
  @override
  String? get notes;
  @override
  List<WorkoutSetCreate> get sets;

  /// Create a copy of SessionComplete
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionCompleteImplCopyWith<_$SessionCompleteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
