import 'package:app_flutter/features/auth/data/repositories/auth_repository.dart';
import 'package:app_flutter/features/auth/data/models/device_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 登录设备列表 Provider。
///
/// 直接拉取 [AuthRepository.listDevices]；以 `FutureProvider` 函数式写法声明，
/// 免去 `@riverpod` 代码生成。登出所有设备（[AuthController.logoutAll]）后
/// 会 `invalidate` 本 Provider 以触发刷新。
final devicesProvider = FutureProvider<List<DeviceSession>>(
  (ref) => ref.watch(authRepositoryProvider).listDevices(),
);
