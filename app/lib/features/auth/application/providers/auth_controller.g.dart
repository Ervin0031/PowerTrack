// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authControllerHash() => r'6340f6c30bf126720d0e40a221b37b4442439d05';

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
///
/// Copied from [AuthController].
@ProviderFor(AuthController)
final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserProfile?>.internal(
      AuthController.new,
      name: r'authControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$authControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AuthController = AsyncNotifier<UserProfile?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
