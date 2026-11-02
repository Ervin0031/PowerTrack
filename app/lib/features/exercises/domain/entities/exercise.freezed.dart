// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exercise.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Exercise _$ExerciseFromJson(Map<String, dynamic> json) {
  return _Exercise.fromJson(json);
}

/// @nodoc
mixin _$Exercise {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'name_en')
  String? get nameEn => throw _privateConstructorUsedError;
  @JsonKey(name: 'exercise_type')
  String get exerciseType => throw _privateConstructorUsedError;
  @JsonKey(name: 'equipment_id')
  int? get equipmentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String? get imageUrl => throw _privateConstructorUsedError;

  /// Serializes this Exercise to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Exercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExerciseCopyWith<Exercise> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExerciseCopyWith<$Res> {
  factory $ExerciseCopyWith(Exercise value, $Res Function(Exercise) then) =
      _$ExerciseCopyWithImpl<$Res, Exercise>;
  @useResult
  $Res call({
    int id,
    String name,
    @JsonKey(name: 'name_en') String? nameEn,
    @JsonKey(name: 'exercise_type') String exerciseType,
    @JsonKey(name: 'equipment_id') int? equipmentId,
    @JsonKey(name: 'image_url') String? imageUrl,
  });
}

/// @nodoc
class _$ExerciseCopyWithImpl<$Res, $Val extends Exercise>
    implements $ExerciseCopyWith<$Res> {
  _$ExerciseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Exercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? nameEn = freezed,
    Object? exerciseType = null,
    Object? equipmentId = freezed,
    Object? imageUrl = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            nameEn: freezed == nameEn
                ? _value.nameEn
                : nameEn // ignore: cast_nullable_to_non_nullable
                      as String?,
            exerciseType: null == exerciseType
                ? _value.exerciseType
                : exerciseType // ignore: cast_nullable_to_non_nullable
                      as String,
            equipmentId: freezed == equipmentId
                ? _value.equipmentId
                : equipmentId // ignore: cast_nullable_to_non_nullable
                      as int?,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ExerciseImplCopyWith<$Res>
    implements $ExerciseCopyWith<$Res> {
  factory _$$ExerciseImplCopyWith(
    _$ExerciseImpl value,
    $Res Function(_$ExerciseImpl) then,
  ) = __$$ExerciseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    @JsonKey(name: 'name_en') String? nameEn,
    @JsonKey(name: 'exercise_type') String exerciseType,
    @JsonKey(name: 'equipment_id') int? equipmentId,
    @JsonKey(name: 'image_url') String? imageUrl,
  });
}

/// @nodoc
class __$$ExerciseImplCopyWithImpl<$Res>
    extends _$ExerciseCopyWithImpl<$Res, _$ExerciseImpl>
    implements _$$ExerciseImplCopyWith<$Res> {
  __$$ExerciseImplCopyWithImpl(
    _$ExerciseImpl _value,
    $Res Function(_$ExerciseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Exercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? nameEn = freezed,
    Object? exerciseType = null,
    Object? equipmentId = freezed,
    Object? imageUrl = freezed,
  }) {
    return _then(
      _$ExerciseImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        nameEn: freezed == nameEn
            ? _value.nameEn
            : nameEn // ignore: cast_nullable_to_non_nullable
                  as String?,
        exerciseType: null == exerciseType
            ? _value.exerciseType
            : exerciseType // ignore: cast_nullable_to_non_nullable
                  as String,
        equipmentId: freezed == equipmentId
            ? _value.equipmentId
            : equipmentId // ignore: cast_nullable_to_non_nullable
                  as int?,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ExerciseImpl implements _Exercise {
  const _$ExerciseImpl({
    required this.id,
    required this.name,
    @JsonKey(name: 'name_en') this.nameEn,
    @JsonKey(name: 'exercise_type') required this.exerciseType,
    @JsonKey(name: 'equipment_id') this.equipmentId,
    @JsonKey(name: 'image_url') this.imageUrl,
  });

  factory _$ExerciseImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExerciseImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  @JsonKey(name: 'name_en')
  final String? nameEn;
  @override
  @JsonKey(name: 'exercise_type')
  final String exerciseType;
  @override
  @JsonKey(name: 'equipment_id')
  final int? equipmentId;
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;

  @override
  String toString() {
    return 'Exercise(id: $id, name: $name, nameEn: $nameEn, exerciseType: $exerciseType, equipmentId: $equipmentId, imageUrl: $imageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExerciseImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.nameEn, nameEn) || other.nameEn == nameEn) &&
            (identical(other.exerciseType, exerciseType) ||
                other.exerciseType == exerciseType) &&
            (identical(other.equipmentId, equipmentId) ||
                other.equipmentId == equipmentId) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    nameEn,
    exerciseType,
    equipmentId,
    imageUrl,
  );

  /// Create a copy of Exercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExerciseImplCopyWith<_$ExerciseImpl> get copyWith =>
      __$$ExerciseImplCopyWithImpl<_$ExerciseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExerciseImplToJson(this);
  }
}

abstract class _Exercise implements Exercise {
  const factory _Exercise({
    required final int id,
    required final String name,
    @JsonKey(name: 'name_en') final String? nameEn,
    @JsonKey(name: 'exercise_type') required final String exerciseType,
    @JsonKey(name: 'equipment_id') final int? equipmentId,
    @JsonKey(name: 'image_url') final String? imageUrl,
  }) = _$ExerciseImpl;

  factory _Exercise.fromJson(Map<String, dynamic> json) =
      _$ExerciseImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'name_en')
  String? get nameEn;
  @override
  @JsonKey(name: 'exercise_type')
  String get exerciseType;
  @override
  @JsonKey(name: 'equipment_id')
  int? get equipmentId;
  @override
  @JsonKey(name: 'image_url')
  String? get imageUrl;

  /// Create a copy of Exercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExerciseImplCopyWith<_$ExerciseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MuscleGroup _$MuscleGroupFromJson(Map<String, dynamic> json) {
  return _MuscleGroup.fromJson(json);
}

/// @nodoc
mixin _$MuscleGroup {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'name_en')
  String get nameEn => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;

  /// Serializes this MuscleGroup to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MuscleGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MuscleGroupCopyWith<MuscleGroup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MuscleGroupCopyWith<$Res> {
  factory $MuscleGroupCopyWith(
    MuscleGroup value,
    $Res Function(MuscleGroup) then,
  ) = _$MuscleGroupCopyWithImpl<$Res, MuscleGroup>;
  @useResult
  $Res call({
    int id,
    String name,
    @JsonKey(name: 'name_en') String nameEn,
    String category,
  });
}

/// @nodoc
class _$MuscleGroupCopyWithImpl<$Res, $Val extends MuscleGroup>
    implements $MuscleGroupCopyWith<$Res> {
  _$MuscleGroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MuscleGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? nameEn = null,
    Object? category = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            nameEn: null == nameEn
                ? _value.nameEn
                : nameEn // ignore: cast_nullable_to_non_nullable
                      as String,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MuscleGroupImplCopyWith<$Res>
    implements $MuscleGroupCopyWith<$Res> {
  factory _$$MuscleGroupImplCopyWith(
    _$MuscleGroupImpl value,
    $Res Function(_$MuscleGroupImpl) then,
  ) = __$$MuscleGroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    @JsonKey(name: 'name_en') String nameEn,
    String category,
  });
}

/// @nodoc
class __$$MuscleGroupImplCopyWithImpl<$Res>
    extends _$MuscleGroupCopyWithImpl<$Res, _$MuscleGroupImpl>
    implements _$$MuscleGroupImplCopyWith<$Res> {
  __$$MuscleGroupImplCopyWithImpl(
    _$MuscleGroupImpl _value,
    $Res Function(_$MuscleGroupImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MuscleGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? nameEn = null,
    Object? category = null,
  }) {
    return _then(
      _$MuscleGroupImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        nameEn: null == nameEn
            ? _value.nameEn
            : nameEn // ignore: cast_nullable_to_non_nullable
                  as String,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MuscleGroupImpl implements _MuscleGroup {
  const _$MuscleGroupImpl({
    required this.id,
    required this.name,
    @JsonKey(name: 'name_en') required this.nameEn,
    required this.category,
  });

  factory _$MuscleGroupImpl.fromJson(Map<String, dynamic> json) =>
      _$$MuscleGroupImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  @JsonKey(name: 'name_en')
  final String nameEn;
  @override
  final String category;

  @override
  String toString() {
    return 'MuscleGroup(id: $id, name: $name, nameEn: $nameEn, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MuscleGroupImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.nameEn, nameEn) || other.nameEn == nameEn) &&
            (identical(other.category, category) ||
                other.category == category));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, nameEn, category);

  /// Create a copy of MuscleGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MuscleGroupImplCopyWith<_$MuscleGroupImpl> get copyWith =>
      __$$MuscleGroupImplCopyWithImpl<_$MuscleGroupImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MuscleGroupImplToJson(this);
  }
}

abstract class _MuscleGroup implements MuscleGroup {
  const factory _MuscleGroup({
    required final int id,
    required final String name,
    @JsonKey(name: 'name_en') required final String nameEn,
    required final String category,
  }) = _$MuscleGroupImpl;

  factory _MuscleGroup.fromJson(Map<String, dynamic> json) =
      _$MuscleGroupImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'name_en')
  String get nameEn;
  @override
  String get category;

  /// Create a copy of MuscleGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MuscleGroupImplCopyWith<_$MuscleGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Equipment _$EquipmentFromJson(Map<String, dynamic> json) {
  return _Equipment.fromJson(json);
}

/// @nodoc
mixin _$Equipment {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'name_en')
  String get nameEn => throw _privateConstructorUsedError;

  /// Serializes this Equipment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Equipment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EquipmentCopyWith<Equipment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EquipmentCopyWith<$Res> {
  factory $EquipmentCopyWith(Equipment value, $Res Function(Equipment) then) =
      _$EquipmentCopyWithImpl<$Res, Equipment>;
  @useResult
  $Res call({int id, String name, @JsonKey(name: 'name_en') String nameEn});
}

/// @nodoc
class _$EquipmentCopyWithImpl<$Res, $Val extends Equipment>
    implements $EquipmentCopyWith<$Res> {
  _$EquipmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Equipment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? name = null, Object? nameEn = null}) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            nameEn: null == nameEn
                ? _value.nameEn
                : nameEn // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EquipmentImplCopyWith<$Res>
    implements $EquipmentCopyWith<$Res> {
  factory _$$EquipmentImplCopyWith(
    _$EquipmentImpl value,
    $Res Function(_$EquipmentImpl) then,
  ) = __$$EquipmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int id, String name, @JsonKey(name: 'name_en') String nameEn});
}

/// @nodoc
class __$$EquipmentImplCopyWithImpl<$Res>
    extends _$EquipmentCopyWithImpl<$Res, _$EquipmentImpl>
    implements _$$EquipmentImplCopyWith<$Res> {
  __$$EquipmentImplCopyWithImpl(
    _$EquipmentImpl _value,
    $Res Function(_$EquipmentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Equipment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? name = null, Object? nameEn = null}) {
    return _then(
      _$EquipmentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        nameEn: null == nameEn
            ? _value.nameEn
            : nameEn // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EquipmentImpl implements _Equipment {
  const _$EquipmentImpl({
    required this.id,
    required this.name,
    @JsonKey(name: 'name_en') required this.nameEn,
  });

  factory _$EquipmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$EquipmentImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  @JsonKey(name: 'name_en')
  final String nameEn;

  @override
  String toString() {
    return 'Equipment(id: $id, name: $name, nameEn: $nameEn)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EquipmentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.nameEn, nameEn) || other.nameEn == nameEn));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, nameEn);

  /// Create a copy of Equipment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EquipmentImplCopyWith<_$EquipmentImpl> get copyWith =>
      __$$EquipmentImplCopyWithImpl<_$EquipmentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EquipmentImplToJson(this);
  }
}

abstract class _Equipment implements Equipment {
  const factory _Equipment({
    required final int id,
    required final String name,
    @JsonKey(name: 'name_en') required final String nameEn,
  }) = _$EquipmentImpl;

  factory _Equipment.fromJson(Map<String, dynamic> json) =
      _$EquipmentImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'name_en')
  String get nameEn;

  /// Create a copy of Equipment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EquipmentImplCopyWith<_$EquipmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ExerciseDetail _$ExerciseDetailFromJson(Map<String, dynamic> json) {
  return _ExerciseDetail.fromJson(json);
}

/// @nodoc
mixin _$ExerciseDetail {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'name_en')
  String? get nameEn => throw _privateConstructorUsedError;
  @JsonKey(name: 'exercise_type')
  String get exerciseType => throw _privateConstructorUsedError;
  @JsonKey(name: 'primary_muscle_group_id')
  int get primaryMuscleGroupId => throw _privateConstructorUsedError;
  @JsonKey(name: 'equipment_id')
  int? get equipmentId => throw _privateConstructorUsedError;
  String? get instructions => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_custom')
  bool get isCustom => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_key')
  String? get imageKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String? get imageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'primary_muscle_name')
  String? get primaryMuscleName => throw _privateConstructorUsedError;
  @JsonKey(name: 'primary_muscle_name_en')
  String? get primaryMuscleNameEn => throw _privateConstructorUsedError;
  @JsonKey(name: 'equipment_name')
  String? get equipmentName => throw _privateConstructorUsedError;
  @JsonKey(name: 'equipment_name_en')
  String? get equipmentNameEn => throw _privateConstructorUsedError;
  @JsonKey(name: 'secondary_muscles')
  List<MuscleGroup> get secondaryMuscles => throw _privateConstructorUsedError;

  /// Serializes this ExerciseDetail to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExerciseDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExerciseDetailCopyWith<ExerciseDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExerciseDetailCopyWith<$Res> {
  factory $ExerciseDetailCopyWith(
    ExerciseDetail value,
    $Res Function(ExerciseDetail) then,
  ) = _$ExerciseDetailCopyWithImpl<$Res, ExerciseDetail>;
  @useResult
  $Res call({
    int id,
    String name,
    @JsonKey(name: 'name_en') String? nameEn,
    @JsonKey(name: 'exercise_type') String exerciseType,
    @JsonKey(name: 'primary_muscle_group_id') int primaryMuscleGroupId,
    @JsonKey(name: 'equipment_id') int? equipmentId,
    String? instructions,
    @JsonKey(name: 'is_custom') bool isCustom,
    @JsonKey(name: 'image_key') String? imageKey,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'primary_muscle_name') String? primaryMuscleName,
    @JsonKey(name: 'primary_muscle_name_en') String? primaryMuscleNameEn,
    @JsonKey(name: 'equipment_name') String? equipmentName,
    @JsonKey(name: 'equipment_name_en') String? equipmentNameEn,
    @JsonKey(name: 'secondary_muscles') List<MuscleGroup> secondaryMuscles,
  });
}

/// @nodoc
class _$ExerciseDetailCopyWithImpl<$Res, $Val extends ExerciseDetail>
    implements $ExerciseDetailCopyWith<$Res> {
  _$ExerciseDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExerciseDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? nameEn = freezed,
    Object? exerciseType = null,
    Object? primaryMuscleGroupId = null,
    Object? equipmentId = freezed,
    Object? instructions = freezed,
    Object? isCustom = null,
    Object? imageKey = freezed,
    Object? imageUrl = freezed,
    Object? createdAt = null,
    Object? primaryMuscleName = freezed,
    Object? primaryMuscleNameEn = freezed,
    Object? equipmentName = freezed,
    Object? equipmentNameEn = freezed,
    Object? secondaryMuscles = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            nameEn: freezed == nameEn
                ? _value.nameEn
                : nameEn // ignore: cast_nullable_to_non_nullable
                      as String?,
            exerciseType: null == exerciseType
                ? _value.exerciseType
                : exerciseType // ignore: cast_nullable_to_non_nullable
                      as String,
            primaryMuscleGroupId: null == primaryMuscleGroupId
                ? _value.primaryMuscleGroupId
                : primaryMuscleGroupId // ignore: cast_nullable_to_non_nullable
                      as int,
            equipmentId: freezed == equipmentId
                ? _value.equipmentId
                : equipmentId // ignore: cast_nullable_to_non_nullable
                      as int?,
            instructions: freezed == instructions
                ? _value.instructions
                : instructions // ignore: cast_nullable_to_non_nullable
                      as String?,
            isCustom: null == isCustom
                ? _value.isCustom
                : isCustom // ignore: cast_nullable_to_non_nullable
                      as bool,
            imageKey: freezed == imageKey
                ? _value.imageKey
                : imageKey // ignore: cast_nullable_to_non_nullable
                      as String?,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            primaryMuscleName: freezed == primaryMuscleName
                ? _value.primaryMuscleName
                : primaryMuscleName // ignore: cast_nullable_to_non_nullable
                      as String?,
            primaryMuscleNameEn: freezed == primaryMuscleNameEn
                ? _value.primaryMuscleNameEn
                : primaryMuscleNameEn // ignore: cast_nullable_to_non_nullable
                      as String?,
            equipmentName: freezed == equipmentName
                ? _value.equipmentName
                : equipmentName // ignore: cast_nullable_to_non_nullable
                      as String?,
            equipmentNameEn: freezed == equipmentNameEn
                ? _value.equipmentNameEn
                : equipmentNameEn // ignore: cast_nullable_to_non_nullable
                      as String?,
            secondaryMuscles: null == secondaryMuscles
                ? _value.secondaryMuscles
                : secondaryMuscles // ignore: cast_nullable_to_non_nullable
                      as List<MuscleGroup>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ExerciseDetailImplCopyWith<$Res>
    implements $ExerciseDetailCopyWith<$Res> {
  factory _$$ExerciseDetailImplCopyWith(
    _$ExerciseDetailImpl value,
    $Res Function(_$ExerciseDetailImpl) then,
  ) = __$$ExerciseDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    @JsonKey(name: 'name_en') String? nameEn,
    @JsonKey(name: 'exercise_type') String exerciseType,
    @JsonKey(name: 'primary_muscle_group_id') int primaryMuscleGroupId,
    @JsonKey(name: 'equipment_id') int? equipmentId,
    String? instructions,
    @JsonKey(name: 'is_custom') bool isCustom,
    @JsonKey(name: 'image_key') String? imageKey,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'primary_muscle_name') String? primaryMuscleName,
    @JsonKey(name: 'primary_muscle_name_en') String? primaryMuscleNameEn,
    @JsonKey(name: 'equipment_name') String? equipmentName,
    @JsonKey(name: 'equipment_name_en') String? equipmentNameEn,
    @JsonKey(name: 'secondary_muscles') List<MuscleGroup> secondaryMuscles,
  });
}

/// @nodoc
class __$$ExerciseDetailImplCopyWithImpl<$Res>
    extends _$ExerciseDetailCopyWithImpl<$Res, _$ExerciseDetailImpl>
    implements _$$ExerciseDetailImplCopyWith<$Res> {
  __$$ExerciseDetailImplCopyWithImpl(
    _$ExerciseDetailImpl _value,
    $Res Function(_$ExerciseDetailImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ExerciseDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? nameEn = freezed,
    Object? exerciseType = null,
    Object? primaryMuscleGroupId = null,
    Object? equipmentId = freezed,
    Object? instructions = freezed,
    Object? isCustom = null,
    Object? imageKey = freezed,
    Object? imageUrl = freezed,
    Object? createdAt = null,
    Object? primaryMuscleName = freezed,
    Object? primaryMuscleNameEn = freezed,
    Object? equipmentName = freezed,
    Object? equipmentNameEn = freezed,
    Object? secondaryMuscles = null,
  }) {
    return _then(
      _$ExerciseDetailImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        nameEn: freezed == nameEn
            ? _value.nameEn
            : nameEn // ignore: cast_nullable_to_non_nullable
                  as String?,
        exerciseType: null == exerciseType
            ? _value.exerciseType
            : exerciseType // ignore: cast_nullable_to_non_nullable
                  as String,
        primaryMuscleGroupId: null == primaryMuscleGroupId
            ? _value.primaryMuscleGroupId
            : primaryMuscleGroupId // ignore: cast_nullable_to_non_nullable
                  as int,
        equipmentId: freezed == equipmentId
            ? _value.equipmentId
            : equipmentId // ignore: cast_nullable_to_non_nullable
                  as int?,
        instructions: freezed == instructions
            ? _value.instructions
            : instructions // ignore: cast_nullable_to_non_nullable
                  as String?,
        isCustom: null == isCustom
            ? _value.isCustom
            : isCustom // ignore: cast_nullable_to_non_nullable
                  as bool,
        imageKey: freezed == imageKey
            ? _value.imageKey
            : imageKey // ignore: cast_nullable_to_non_nullable
                  as String?,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        primaryMuscleName: freezed == primaryMuscleName
            ? _value.primaryMuscleName
            : primaryMuscleName // ignore: cast_nullable_to_non_nullable
                  as String?,
        primaryMuscleNameEn: freezed == primaryMuscleNameEn
            ? _value.primaryMuscleNameEn
            : primaryMuscleNameEn // ignore: cast_nullable_to_non_nullable
                  as String?,
        equipmentName: freezed == equipmentName
            ? _value.equipmentName
            : equipmentName // ignore: cast_nullable_to_non_nullable
                  as String?,
        equipmentNameEn: freezed == equipmentNameEn
            ? _value.equipmentNameEn
            : equipmentNameEn // ignore: cast_nullable_to_non_nullable
                  as String?,
        secondaryMuscles: null == secondaryMuscles
            ? _value._secondaryMuscles
            : secondaryMuscles // ignore: cast_nullable_to_non_nullable
                  as List<MuscleGroup>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ExerciseDetailImpl implements _ExerciseDetail {
  const _$ExerciseDetailImpl({
    required this.id,
    required this.name,
    @JsonKey(name: 'name_en') this.nameEn,
    @JsonKey(name: 'exercise_type') required this.exerciseType,
    @JsonKey(name: 'primary_muscle_group_id')
    required this.primaryMuscleGroupId,
    @JsonKey(name: 'equipment_id') this.equipmentId,
    this.instructions,
    @JsonKey(name: 'is_custom') this.isCustom = false,
    @JsonKey(name: 'image_key') this.imageKey,
    @JsonKey(name: 'image_url') this.imageUrl,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'primary_muscle_name') this.primaryMuscleName,
    @JsonKey(name: 'primary_muscle_name_en') this.primaryMuscleNameEn,
    @JsonKey(name: 'equipment_name') this.equipmentName,
    @JsonKey(name: 'equipment_name_en') this.equipmentNameEn,
    @JsonKey(name: 'secondary_muscles')
    final List<MuscleGroup> secondaryMuscles = const [],
  }) : _secondaryMuscles = secondaryMuscles;

  factory _$ExerciseDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExerciseDetailImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  @JsonKey(name: 'name_en')
  final String? nameEn;
  @override
  @JsonKey(name: 'exercise_type')
  final String exerciseType;
  @override
  @JsonKey(name: 'primary_muscle_group_id')
  final int primaryMuscleGroupId;
  @override
  @JsonKey(name: 'equipment_id')
  final int? equipmentId;
  @override
  final String? instructions;
  @override
  @JsonKey(name: 'is_custom')
  final bool isCustom;
  @override
  @JsonKey(name: 'image_key')
  final String? imageKey;
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'primary_muscle_name')
  final String? primaryMuscleName;
  @override
  @JsonKey(name: 'primary_muscle_name_en')
  final String? primaryMuscleNameEn;
  @override
  @JsonKey(name: 'equipment_name')
  final String? equipmentName;
  @override
  @JsonKey(name: 'equipment_name_en')
  final String? equipmentNameEn;
  final List<MuscleGroup> _secondaryMuscles;
  @override
  @JsonKey(name: 'secondary_muscles')
  List<MuscleGroup> get secondaryMuscles {
    if (_secondaryMuscles is EqualUnmodifiableListView)
      return _secondaryMuscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_secondaryMuscles);
  }

  @override
  String toString() {
    return 'ExerciseDetail(id: $id, name: $name, nameEn: $nameEn, exerciseType: $exerciseType, primaryMuscleGroupId: $primaryMuscleGroupId, equipmentId: $equipmentId, instructions: $instructions, isCustom: $isCustom, imageKey: $imageKey, imageUrl: $imageUrl, createdAt: $createdAt, primaryMuscleName: $primaryMuscleName, primaryMuscleNameEn: $primaryMuscleNameEn, equipmentName: $equipmentName, equipmentNameEn: $equipmentNameEn, secondaryMuscles: $secondaryMuscles)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExerciseDetailImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.nameEn, nameEn) || other.nameEn == nameEn) &&
            (identical(other.exerciseType, exerciseType) ||
                other.exerciseType == exerciseType) &&
            (identical(other.primaryMuscleGroupId, primaryMuscleGroupId) ||
                other.primaryMuscleGroupId == primaryMuscleGroupId) &&
            (identical(other.equipmentId, equipmentId) ||
                other.equipmentId == equipmentId) &&
            (identical(other.instructions, instructions) ||
                other.instructions == instructions) &&
            (identical(other.isCustom, isCustom) ||
                other.isCustom == isCustom) &&
            (identical(other.imageKey, imageKey) ||
                other.imageKey == imageKey) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.primaryMuscleName, primaryMuscleName) ||
                other.primaryMuscleName == primaryMuscleName) &&
            (identical(other.primaryMuscleNameEn, primaryMuscleNameEn) ||
                other.primaryMuscleNameEn == primaryMuscleNameEn) &&
            (identical(other.equipmentName, equipmentName) ||
                other.equipmentName == equipmentName) &&
            (identical(other.equipmentNameEn, equipmentNameEn) ||
                other.equipmentNameEn == equipmentNameEn) &&
            const DeepCollectionEquality().equals(
              other._secondaryMuscles,
              _secondaryMuscles,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    nameEn,
    exerciseType,
    primaryMuscleGroupId,
    equipmentId,
    instructions,
    isCustom,
    imageKey,
    imageUrl,
    createdAt,
    primaryMuscleName,
    primaryMuscleNameEn,
    equipmentName,
    equipmentNameEn,
    const DeepCollectionEquality().hash(_secondaryMuscles),
  );

  /// Create a copy of ExerciseDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExerciseDetailImplCopyWith<_$ExerciseDetailImpl> get copyWith =>
      __$$ExerciseDetailImplCopyWithImpl<_$ExerciseDetailImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ExerciseDetailImplToJson(this);
  }
}

abstract class _ExerciseDetail implements ExerciseDetail {
  const factory _ExerciseDetail({
    required final int id,
    required final String name,
    @JsonKey(name: 'name_en') final String? nameEn,
    @JsonKey(name: 'exercise_type') required final String exerciseType,
    @JsonKey(name: 'primary_muscle_group_id')
    required final int primaryMuscleGroupId,
    @JsonKey(name: 'equipment_id') final int? equipmentId,
    final String? instructions,
    @JsonKey(name: 'is_custom') final bool isCustom,
    @JsonKey(name: 'image_key') final String? imageKey,
    @JsonKey(name: 'image_url') final String? imageUrl,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'primary_muscle_name') final String? primaryMuscleName,
    @JsonKey(name: 'primary_muscle_name_en') final String? primaryMuscleNameEn,
    @JsonKey(name: 'equipment_name') final String? equipmentName,
    @JsonKey(name: 'equipment_name_en') final String? equipmentNameEn,
    @JsonKey(name: 'secondary_muscles')
    final List<MuscleGroup> secondaryMuscles,
  }) = _$ExerciseDetailImpl;

  factory _ExerciseDetail.fromJson(Map<String, dynamic> json) =
      _$ExerciseDetailImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'name_en')
  String? get nameEn;
  @override
  @JsonKey(name: 'exercise_type')
  String get exerciseType;
  @override
  @JsonKey(name: 'primary_muscle_group_id')
  int get primaryMuscleGroupId;
  @override
  @JsonKey(name: 'equipment_id')
  int? get equipmentId;
  @override
  String? get instructions;
  @override
  @JsonKey(name: 'is_custom')
  bool get isCustom;
  @override
  @JsonKey(name: 'image_key')
  String? get imageKey;
  @override
  @JsonKey(name: 'image_url')
  String? get imageUrl;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'primary_muscle_name')
  String? get primaryMuscleName;
  @override
  @JsonKey(name: 'primary_muscle_name_en')
  String? get primaryMuscleNameEn;
  @override
  @JsonKey(name: 'equipment_name')
  String? get equipmentName;
  @override
  @JsonKey(name: 'equipment_name_en')
  String? get equipmentNameEn;
  @override
  @JsonKey(name: 'secondary_muscles')
  List<MuscleGroup> get secondaryMuscles;

  /// Create a copy of ExerciseDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExerciseDetailImplCopyWith<_$ExerciseDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
