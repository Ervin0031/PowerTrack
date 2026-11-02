// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DeviceSessionImpl _$$DeviceSessionImplFromJson(Map<String, dynamic> json) =>
    _$DeviceSessionImpl(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      deviceName: json['device_name'] as String?,
      deviceType: json['device_type'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      isRevoked: json['is_revoked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastUsedAt: json['last_used_at'] == null
          ? null
          : DateTime.parse(json['last_used_at'] as String),
      ipAddress: json['ip_address'] as String?,
    );

Map<String, dynamic> _$$DeviceSessionImplToJson(_$DeviceSessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'device_name': instance.deviceName,
      'device_type': instance.deviceType,
      'expires_at': instance.expiresAt.toIso8601String(),
      'is_revoked': instance.isRevoked,
      'created_at': instance.createdAt.toIso8601String(),
      'last_used_at': instance.lastUsedAt?.toIso8601String(),
      'ip_address': instance.ipAddress,
    };
