import 'package:app_flutter/core/router/router_names.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_client.dart';
import '../router/app_router.dart';
import '../storage/app_launch_storage.dart';
import '../storage/token_storage.dart';

/// 应用级 SharedPreferences Provider。
///
/// Riverpod 语义：
/// - `keepAlive: true`：作为基础设施依赖，生命周期跟随应用。
/// - 默认抛错：提醒调用方必须在 `runApp` 前通过 ProviderScope override 注入异步初始化结果。
///
/// ⚠️ 注意：
/// 如果忘记 override，本 Provider 被读取时会立即抛错；这能尽早暴露启动流程问题。
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden before runApp.'),
);

/// TokenStorage Provider。
///
/// 职责：
/// - 封装 access/refresh token 的本地读写。
/// - 给路由守卫和网络拦截器提供同一份登录态来源。
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage(ref.watch(sharedPreferencesProvider)));

/// 首次启动状态 Provider。
///
/// Welcome/Splash/Router 都通过它判断是否需要展示引导页。
final appLaunchStorageProvider = Provider<AppLaunchStorage>(
  (ref) => AppLaunchStorage(ref.watch(sharedPreferencesProvider)),
);

/// 全局 Dio Provider。
///
/// 职责：
/// - 创建统一配置的 HTTP 客户端。
/// - 复用同一套鉴权、日志与错误转换拦截器。
///
/// 401 处理：
/// 拦截器在「刷新令牌失效 / 无刷新令牌」时会清空本地令牌并触发 [onUnauthorized]，
/// 这里接线到路由统一回到登录页，与 `appRouterProvider` 的 redirect 守卫保持一致
/// （否则 token 失效后用户会一直停在当前页面）。
///
/// ⚠️ 与 `appRouterProvider` 存在循环引用：两者均为 lazy 求值的 Provider，
/// 运行时按需读取，无初始化顺序问题（Dart 允许库间循环 import）。
final dioProvider = Provider<Dio>(
  (ref) => DioClient.create(
    tokenStorage: ref.watch(tokenStorageProvider),
    onUnauthorized: () {
      // 令牌已被拦截器清空，redirect 守卫会把 /login 之外的路径派回登录页。
      ref.read(appRouterProvider).go(AppRoutes.login);
    },
  ),
);
