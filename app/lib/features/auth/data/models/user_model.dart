/// 认证相关数据实体（登录令牌 + 当前用户）。
///
/// 由 `freezed` + `json_serializable` 代码生成实现，字段与后端 Schema 对应
/// （backend/app/schemas/user.py 中的 `Token` / `UserResponse`）。
///
/// `invalid_annotation_target`：`@JsonKey` 标注在 freezed 构造参数上，freezed
/// 会将其复制到生成的字段上；分析器不感知这一行为而误报，故文件级忽略。
// ignore_for_file: invalid_annotation_target
library;

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// 登录成功返回的令牌对实体。
///
/// 字段使用后端 snake_case 命名（如 `access_token`），通过 `@JsonKey` 映射。
@freezed
abstract class AuthToken with _$AuthToken {
  const factory AuthToken({
    /// 访问令牌（短期凭证，随请求头 `Authorization: Bearer` 发送）。
    @JsonKey(name: 'access_token') required String accessToken,

    /// 刷新令牌（长期凭证，仅用于换取新的访问令牌）；登录接口可能不返回。
    @JsonKey(name: 'refresh_token') String? refreshToken,

    /// 令牌类型，后端固定返回 `bearer`；缺省时按惯例兜底为 `bearer`。
    @JsonKey(name: 'token_type') @Default('bearer') String tokenType,
  }) = _AuthToken;

  factory AuthToken.fromJson(Map<String, dynamic> json) => _$AuthTokenFromJson(json);
}

/// 当前登录用户信息实体。
@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required int id,
    required String username,
    required String email,
    @JsonKey(name: 'is_active') @Default(false) bool isActive,
    @JsonKey(name: 'is_verified') @Default(false) bool isVerified,
    @JsonKey(name: 'is_superuser') @Default(false) bool isSuperuser,

    /// 时间字段后端统一为 ISO-8601 字符串（如 `2019-08-24T14:15:22Z`）。
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,

    /// 最近一次登录时间；从未登录过的用户为 `null`。
    @JsonKey(name: 'last_login_at') DateTime? lastLoginAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
}
