/// 登录设备会话响应实体。
///
/// 由 `freezed` + `json_serializable` 代码生成，字段与后端 `RefreshTokenResponse`
/// Schema 对应（backend/app/schemas/token.py）。用于「我的设备」列表展示。
///
/// `invalid_annotation_target`：`@JsonKey` 标注在 freezed 构造参数上，freezed 会
/// 将其复制到生成的字段上；分析器不感知这一行为而误报，故文件级忽略。
// ignore_for_file: invalid_annotation_target
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_model.freezed.dart';
part 'device_model.g.dart';

/// 单个登录设备的会话信息。
@freezed
abstract class DeviceSession with _$DeviceSession {
  const factory DeviceSession({
    required int id,
    @JsonKey(name: 'user_id') required int userId,

    /// 设备展示名（如 "iPhone 15"）；部分平台可能不上报，故可空。
    @JsonKey(name: 'device_name') String? deviceName,

    /// 设备类型（如 "ios" / "android" / "web"）；可空。
    @JsonKey(name: 'device_type') String? deviceType,

    @JsonKey(name: 'expires_at') required DateTime expiresAt,
    @JsonKey(name: 'is_revoked') @Default(false) bool isRevoked,
    @JsonKey(name: 'created_at') required DateTime createdAt,

    /// 最近使用时间；从未使用过的会话为 `null`。
    @JsonKey(name: 'last_used_at') DateTime? lastUsedAt,

    /// 登录 IP；可空。
    @JsonKey(name: 'ip_address') String? ipAddress,
  }) = _DeviceSession;

  factory DeviceSession.fromJson(Map<String, dynamic> json) => _$DeviceSessionFromJson(json);
}
