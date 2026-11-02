import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/features/auth/data/repositories/auth_repository.dart';
import 'package:app_flutter/features/auth/data/models/user_model.dart';
import 'package:app_flutter/features/auth/application/providers/auth_providers.dart';
import 'package:app_flutter/features/coach/application/coach_provider.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/settings/application/providers/ai_settings_provider.dart';
import 'package:app_flutter/features/settings/application/providers/app_cache_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_controller.g.dart';

/// 登录会话控制器。
///
/// 由 `@riverpod` 代码生成 `authControllerProvider`（keepAlive，与旧手写声明等价）。
///
/// 职责：
/// - `build`：启动时按本地令牌自动恢复会话。
/// - [login]：登录 → 写令牌 → 拉取用户资料。
/// - [logout]：登出（服务端撤销 + 本地清理）→ 回到未登录态。
///
/// ⚠️ 路由跳转由调用方（页面）负责；本控制器只维护状态。
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<UserProfile?> build() async {
    // 未登录直接返回 null；已登录才触发网络请求恢复用户资料。
    if (!ref.read(tokenStorageProvider).hasToken) return null;
    return ref.read(authRepositoryProvider).fetchCurrentUser();
  }

  /// 登录入口。
  ///
  /// 1. 状态置为加载中。
  /// 2. 调 [AuthRepository.login] 拿令牌并写入本地。
  /// 3. 拉取当前用户资料，作为登录成功的最终状态。
  ///
  /// 任一步失败都会进入 `AsyncError`，页面用 `userFacingErrorMessage` 展示。
  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      // 用 guard 包裹后续拉取，失败也会进入 AsyncError 而不是让异常外溢。
      state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).fetchCurrentUser(),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// 登出入口。
  ///
  /// 即使服务端撤销失败，`finally` 也会把本地状态清为未登录，
  /// 并清除动作库 / 图片缓存，保证用户在任何情况下都能退出当前会话。
  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      await ref.read(fitnessProfileProvider.notifier).clearLocal();
      try {
        await ref.read(appCacheControllerProvider).clear();
      } catch (_) {
        // 清缓存失败不阻塞登出。
      }
      ref.invalidate(onboardingProvider);
      await _clearAi();
      state = const AsyncData(null);
    }
  }

  /// 登出时清掉本机 AI Key 和旧对话，避免换账号后残留。
  Future<void> _clearAi() async {
    try {
      await ref.read(aiSettingsRepositoryProvider).clearApiKey();
    } catch (_) {
      // 安全存储不可用或测试环境未注入依赖时不阻断登出。
    }
    ref.invalidate(aiSettingsProvider);
    ref.invalidate(coachControllerProvider);
  }

  /// 更新账号资料（用户名 / 邮箱）。
  ///
  /// 成功后把新资料写入会话态（页面无需再拉一次）；失败抛异常由页面提示。
  Future<UserProfile> updateAccount({String? username, String? email}) async {
    final updated = await ref
        .read(authRepositoryProvider)
        .updateMe(username: username, email: email);
    state = AsyncData(updated);
    return updated;
  }

  /// 注销账号（不可恢复）。
  ///
  /// 服务端删除成功后复用 [logout] 的本地清理路径回到未登录态；
  /// 账号已不存在，其中的服务端登出调用失败也无妨（Repository 已吞掉）。
  Future<void> deleteAccount() async {
    await ref.read(authRepositoryProvider).deleteMe();
    await logout();
  }

  /// 注册新用户。
  ///
  /// 仅做网络请求（写服务端），**不写入本地令牌、不切换登录态**——
  /// 后端要求邮箱验证后才能登录，上层应跳转验证页等待校验。
  /// 失败抛出 [ApiException]，由页面用 `userFacingErrorMessage` 展示。
  Future<UserProfile> register({
    required String username,
    required String email,
    required String password,
  }) {
    return ref
        .read(authRepositoryProvider)
        .register(username: username, email: email, password: password);
  }

  /// 验证邮箱（验证码）。失败抛异常，由页面处理。
  Future<void> verifyEmail({required String email, required String code}) {
    return ref
        .read(authRepositoryProvider)
        .verifyEmail(email: email, code: code);
  }

  /// 重发验证邮件。失败抛异常，由页面处理。
  Future<void> resendVerification({required String email}) {
    return ref.read(authRepositoryProvider).resendVerification(email: email);
  }

  /// 申请重置密码（发送验证码邮件）。失败抛异常，由页面处理。
  Future<void> forgotPassword({required String email}) {
    return ref.read(authRepositoryProvider).forgotPassword(email: email);
  }

  /// 用验证码重置密码。失败抛异常，由页面处理。
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return ref
        .read(authRepositoryProvider)
        .resetPassword(email: email, code: code, newPassword: newPassword);
  }

  /// 已登录用户修改密码（需旧密码）。失败抛异常，由页面处理。
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return ref
        .read(authRepositoryProvider)
        .changePassword(oldPassword: oldPassword, newPassword: newPassword);
  }

  /// 登出所有设备。
  ///
  /// 复用 Repository 的登出逻辑（撤销全部 token + 清本地），
  /// 随后把会话态清为未登录，并令设备列表缓存失效。
  Future<void> logoutAll() async {
    try {
      await ref.read(authRepositoryProvider).logoutAll();
    } finally {
      await ref.read(fitnessProfileProvider.notifier).clearLocal();
      try {
        await ref.read(appCacheControllerProvider).clear();
      } catch (_) {
        // 清缓存失败不阻塞登出。
      }
      ref.invalidate(onboardingProvider);
      ref.invalidate(devicesProvider);
      await _clearAi();
      state = const AsyncData(null);
    }
  }
}
