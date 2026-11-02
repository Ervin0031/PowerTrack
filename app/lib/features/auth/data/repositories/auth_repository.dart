import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/device_model.dart';
import '../models/user_model.dart';

part 'auth_repository.g.dart';

/// [AuthRepository] 组装 Provider。
///
/// 直接挂在文件头部，与 Repository 同文件维护：改动请求逻辑或依赖时
/// 无需跨目录跳转。由 `@riverpod` 代码生成 `authRepositoryProvider`。
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(ref.watch(dioProvider), ref.watch(tokenStorageProvider));
}

/// 认证数据仓库：负责登录 / 登出 / 拉取当前用户信息。
///
/// **职责边界**：只做「网络请求 + 本地令牌读写」，不涉及 UI 与状态管理；
/// 依赖（[Dio]、[TokenStorage]）由上方 Provider 注入。
///
/// **路径说明**：后端路由挂在 `/api/v1` 前缀下（backend/app/main.py），
/// 登录/登出在 `/auth/*`，当前用户在 `/users/me`。
class AuthRepository {
  /// [dio]：全局配置好的 HTTP 客户端；[tokenStorage]：本地令牌读写。
  /// 采用位置参数 + initializing formal，与 [TokenStorage] 的构造风格保持一致。
  AuthRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// 登录：`POST /api/v1/auth/login`。
  ///
  /// 成功后把返回的令牌写入本地存储（供路由守卫、鉴权拦截器复用），
  /// 返回令牌对象供上层决定是否继续拉取用户资料。
  ///
  /// 失败会抛出经过 [ErrorInterceptor] 转换后的 [ApiException] 子类
  /// （如 [UnauthorizedException]），由上层统一转成用户可读文案。
  Future<AuthToken> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('登录响应缺少数据');
    }

    final token = AuthToken.fromJson(data);
    // 后端 `refresh_token` 可能缺省；缺省时保留本地旧值，避免误清会话。
    await _tokenStorage.save(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken ?? _tokenStorage.refreshToken ?? '',
    );
    return token;
  }

  /// 登出：`POST /api/v1/auth/logout`。
  ///
  /// 1. 通知服务端撤销当前 refresh token（尽力而为：网络失败不阻塞本地登出）。
  /// 2. 无论服务端调用结果如何，都清除本地令牌，保证用户一定能够登出。
  Future<void> logout() async {
    final refreshToken = _tokenStorage.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _dio.post('/api/v1/auth/logout', data: {'refresh_token': refreshToken});
      } catch (_) {
        // 忽略：登出是幂等操作，服务端不可达时也应放行本地登出。
      }
    }
    await _tokenStorage.clear();
  }

  /// 获取当前登录用户信息：`GET /api/v1/users/me`。
  ///
  /// 需要有效访问令牌（由 [AuthInterceptor] 自动附带）。
  Future<UserProfile> fetchCurrentUser() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/users/me');
    final data = response.data;
    if (data == null) {
      throw const FormatException('用户信息响应缺少数据');
    }
    return UserProfile.fromJson(data);
  }

  /// 更新当前用户资料：`PUT /api/v1/users/me`。
  ///
  /// 只提交传入的字段；用户名/邮箱被占用时后端返回 400。
  /// 不提交 `password`（改密走 [changePassword]）与 `is_active`（自锁无意义）。
  Future<UserProfile> updateMe({String? username, String? email}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/users/me',
      data: {'username': ?username, 'email': ?email},
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('更新用户信息响应缺少数据');
    }
    return UserProfile.fromJson(data);
  }

  /// 注销当前账号：`DELETE /api/v1/users/me`（204，不可恢复）。
  ///
  /// 服务端会级联删除训练数据；本地令牌由调用方随后清理。
  Future<void> deleteMe() async {
    await _dio.delete<void>('/api/v1/users/me');
  }

  /// 注册：`POST /api/v1/auth/register`。
  ///
  /// 成功后后端会发送验证邮件，用户需验证邮箱后才能登录；
  /// 因此本方法仅返回创建成功的用户资料，由上层决定跳转（验证页）。
  Future<UserProfile> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/register',
      data: {'username': username, 'email': email, 'password': password},
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('注册响应缺少数据');
    }
    return UserProfile.fromJson(data);
  }

  /// 验证邮箱：`POST /api/v1/auth/verify-email`。
  ///
  /// 使用注册/重发邮件后收到的验证码校验邮箱。失败（验证码无效或过期）
  /// 会抛出 [BadRequestException] 等，由上层转成用户可读文案。
  Future<void> verifyEmail({required String email, required String code}) async {
    await _dio.post(
      '/api/v1/auth/verify-email',
      data: {'email': email, 'code': code},
    );
  }

  /// 重发验证邮件：`POST /api/v1/auth/resend-verification`。
  Future<void> resendVerification({required String email}) async {
    await _dio.post(
      '/api/v1/auth/resend-verification',
      data: {'email': email},
    );
  }

  /// 申请重置密码：`POST /api/v1/auth/forgot-password`。
  ///
  /// 后端向该邮箱发送含验证码的重置邮件。无论邮箱是否存在，
  /// 接口通常都返回成功以避免账户枚举，故不在此区分结果。
  Future<void> forgotPassword({required String email}) async {
    await _dio.post(
      '/api/v1/auth/forgot-password',
      data: {'email': email},
    );
  }

  /// 重置密码：`POST /api/v1/auth/reset-password`。
  ///
  /// 使用邮件验证码 + 新密码完成重置。失败（验证码无效/过期）抛异常。
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _dio.post(
      '/api/v1/auth/reset-password',
      data: {'email': email, 'code': code, 'new_password': newPassword},
    );
  }

  /// 修改密码：`POST /api/v1/auth/change-password`。
  ///
  /// 已登录用户用旧密码校验后修改；需有效访问令牌（由拦截器附带）。
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.post(
      '/api/v1/auth/change-password',
      data: {'old_password': oldPassword, 'new_password': newPassword},
    );
  }

  /// 登出所有设备：`POST /api/v1/auth/logout-all`。
  ///
  /// 撤销当前用户全部 refresh token；即使服务端调用失败，
  /// 也清空本地令牌保证登出。
  Future<void> logoutAll() async {
    try {
      await _dio.post('/api/v1/auth/logout-all');
    } finally {
      await _tokenStorage.clear();
    }
  }

  /// 登录设备列表：`GET /api/v1/auth/devices`。
  ///
  /// 返回当前用户所有活跃登录会话（含已撤销），用于「我的设备」管理。
  Future<List<DeviceSession>> listDevices() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/auth/devices');
    final data = response.data;
    if (data == null) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(DeviceSession.fromJson)
        .toList();
  }
}
