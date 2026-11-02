// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DeviceSession _$DeviceSessionFromJson(Map<String, dynamic> json) {
  return _DeviceSession.fromJson(json);
}

/// @nodoc
mixin _$DeviceSession {
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  int get userId => throw _privateConstructorUsedError;

  /// 设备展示名（如 "iPhone 15"）；部分平台可能不上报，故可空。
  @JsonKey(name: 'device_name')
  String? get deviceName => throw _privateConstructorUsedError;

  /// 设备类型（如 "ios" / "android" / "web"）；可空。
  @JsonKey(name: 'device_type')
  String? get deviceType => throw _privateConstructorUsedError;
  @JsonKey(name: 'expires_at')
  DateTime get expiresAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_revoked')
  bool get isRevoked => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// 最近使用时间；从未使用过的会话为 `null`。
  @JsonKey(name: 'last_used_at')
  DateTime? get lastUsedAt => throw _privateConstructorUsedError;

  /// 登录 IP；可空。
  @JsonKey(name: 'ip_address')
  String? get ipAddress => throw _privateConstructorUsedError;

  /// Serializes this DeviceSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DeviceSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeviceSessionCopyWith<DeviceSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceSessionCopyWith<$Res> {
  factory $DeviceSessionCopyWith(
    DeviceSession value,
    $Res Function(DeviceSession) then,
  ) = _$DeviceSessionCopyWithImpl<$Res, DeviceSession>;
  @useResult
  $Res call({
    int id,
    @JsonKey(name: 'user_id') int userId,
    @JsonKey(name: 'device_name') String? deviceName,
    @JsonKey(name: 'device_type') String? deviceType,
    @JsonKey(name: 'expires_at') DateTime expiresAt,
    @JsonKey(name: 'is_revoked') bool isRevoked,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'last_used_at') DateTime? lastUsedAt,
    @JsonKey(name: 'ip_address') String? ipAddress,
  });
}

/// @nodoc
class _$DeviceSessionCopyWithImpl<$Res, $Val extends DeviceSession>
    implements $DeviceSessionCopyWith<$Res> {
  _$DeviceSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeviceSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceName = freezed,
    Object? deviceType = freezed,
    Object? expiresAt = null,
    Object? isRevoked = null,
    Object? createdAt = null,
    Object? lastUsedAt = freezed,
    Object? ipAddress = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as int,
            deviceName: freezed == deviceName
                ? _value.deviceName
                : deviceName // ignore: cast_nullable_to_non_nullable
                      as String?,
            deviceType: freezed == deviceType
                ? _value.deviceType
                : deviceType // ignore: cast_nullable_to_non_nullable
                      as String?,
            expiresAt: null == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            isRevoked: null == isRevoked
                ? _value.isRevoked
                : isRevoked // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            lastUsedAt: freezed == lastUsedAt
                ? _value.lastUsedAt
                : lastUsedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            ipAddress: freezed == ipAddress
                ? _value.ipAddress
                : ipAddress // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeviceSessionImplCopyWith<$Res>
    implements $DeviceSessionCopyWith<$Res> {
  factory _$$DeviceSessionImplCopyWith(
    _$DeviceSessionImpl value,
    $Res Function(_$DeviceSessionImpl) then,
  ) = __$$DeviceSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    @JsonKey(name: 'user_id') int userId,
    @JsonKey(name: 'device_name') String? deviceName,
    @JsonKey(name: 'device_type') String? deviceType,
    @JsonKey(name: 'expires_at') DateTime expiresAt,
    @JsonKey(name: 'is_revoked') bool isRevoked,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'last_used_at') DateTime? lastUsedAt,
    @JsonKey(name: 'ip_address') String? ipAddress,
  });
}

/// @nodoc
class __$$DeviceSessionImplCopyWithImpl<$Res>
    extends _$DeviceSessionCopyWithImpl<$Res, _$DeviceSessionImpl>
    implements _$$DeviceSessionImplCopyWith<$Res> {
  __$$DeviceSessionImplCopyWithImpl(
    _$DeviceSessionImpl _value,
    $Res Function(_$DeviceSessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DeviceSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceName = freezed,
    Object? deviceType = freezed,
    Object? expiresAt = null,
    Object? isRevoked = null,
    Object? createdAt = null,
    Object? lastUsedAt = freezed,
    Object? ipAddress = freezed,
  }) {
    return _then(
      _$DeviceSessionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as int,
        deviceName: freezed == deviceName
            ? _value.deviceName
            : deviceName // ignore: cast_nullable_to_non_nullable
                  as String?,
        deviceType: freezed == deviceType
            ? _value.deviceType
            : deviceType // ignore: cast_nullable_to_non_nullable
                  as String?,
        expiresAt: null == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        isRevoked: null == isRevoked
            ? _value.isRevoked
            : isRevoked // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        lastUsedAt: freezed == lastUsedAt
            ? _value.lastUsedAt
            : lastUsedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        ipAddress: freezed == ipAddress
            ? _value.ipAddress
            : ipAddress // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DeviceSessionImpl implements _DeviceSession {
  const _$DeviceSessionImpl({
    required this.id,
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'device_name') this.deviceName,
    @JsonKey(name: 'device_type') this.deviceType,
    @JsonKey(name: 'expires_at') required this.expiresAt,
    @JsonKey(name: 'is_revoked') this.isRevoked = false,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'last_used_at') this.lastUsedAt,
    @JsonKey(name: 'ip_address') this.ipAddress,
  });

  factory _$DeviceSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$DeviceSessionImplFromJson(json);

  @override
  final int id;
  @override
  @JsonKey(name: 'user_id')
  final int userId;

  /// 设备展示名（如 "iPhone 15"）；部分平台可能不上报，故可空。
  @override
  @JsonKey(name: 'device_name')
  final String? deviceName;

  /// 设备类型（如 "ios" / "android" / "web"）；可空。
  @override
  @JsonKey(name: 'device_type')
  final String? deviceType;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @override
  @JsonKey(name: 'is_revoked')
  final bool isRevoked;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  /// 最近使用时间；从未使用过的会话为 `null`。
  @override
  @JsonKey(name: 'last_used_at')
  final DateTime? lastUsedAt;

  /// 登录 IP；可空。
  @override
  @JsonKey(name: 'ip_address')
  final String? ipAddress;

  @override
  String toString() {
    return 'DeviceSession(id: $id, userId: $userId, deviceName: $deviceName, deviceType: $deviceType, expiresAt: $expiresAt, isRevoked: $isRevoked, createdAt: $createdAt, lastUsedAt: $lastUsedAt, ipAddress: $ipAddress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceSessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.deviceName, deviceName) ||
                other.deviceName == deviceName) &&
            (identical(other.deviceType, deviceType) ||
                other.deviceType == deviceType) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.isRevoked, isRevoked) ||
                other.isRevoked == isRevoked) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastUsedAt, lastUsedAt) ||
                other.lastUsedAt == lastUsedAt) &&
            (identical(other.ipAddress, ipAddress) ||
                other.ipAddress == ipAddress));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    deviceName,
    deviceType,
    expiresAt,
    isRevoked,
    createdAt,
    lastUsedAt,
    ipAddress,
  );

  /// Create a copy of DeviceSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceSessionImplCopyWith<_$DeviceSessionImpl> get copyWith =>
      __$$DeviceSessionImplCopyWithImpl<_$DeviceSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DeviceSessionImplToJson(this);
  }
}

abstract class _DeviceSession implements DeviceSession {
  const factory _DeviceSession({
    required final int id,
    @JsonKey(name: 'user_id') required final int userId,
    @JsonKey(name: 'device_name') final String? deviceName,
    @JsonKey(name: 'device_type') final String? deviceType,
    @JsonKey(name: 'expires_at') required final DateTime expiresAt,
    @JsonKey(name: 'is_revoked') final bool isRevoked,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'last_used_at') final DateTime? lastUsedAt,
    @JsonKey(name: 'ip_address') final String? ipAddress,
  }) = _$DeviceSessionImpl;

  factory _DeviceSession.fromJson(Map<String, dynamic> json) =
      _$DeviceSessionImpl.fromJson;

  @override
  int get id;
  @override
  @JsonKey(name: 'user_id')
  int get userId;

  /// 设备展示名（如 "iPhone 15"）；部分平台可能不上报，故可空。
  @override
  @JsonKey(name: 'device_name')
  String? get deviceName;

  /// 设备类型（如 "ios" / "android" / "web"）；可空。
  @override
  @JsonKey(name: 'device_type')
  String? get deviceType;
  @override
  @JsonKey(name: 'expires_at')
  DateTime get expiresAt;
  @override
  @JsonKey(name: 'is_revoked')
  bool get isRevoked;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// 最近使用时间；从未使用过的会话为 `null`。
  @override
  @JsonKey(name: 'last_used_at')
  DateTime? get lastUsedAt;

  /// 登录 IP；可空。
  @override
  @JsonKey(name: 'ip_address')
  String? get ipAddress;

  /// Create a copy of DeviceSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeviceSessionImplCopyWith<_$DeviceSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
