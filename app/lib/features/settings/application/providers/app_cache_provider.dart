import 'package:app_flutter/features/exercises/application/providers/exercises_provider.dart';
import 'package:app_flutter/features/settings/data/repositories/app_cache_repository.dart';
import 'package:app_flutter/features/settings/domain/entities/app_storage_info.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前 App 磁盘占用快照。
final appStorageInfoProvider = FutureProvider.autoDispose<AppStorageInfo>((
  ref,
) {
  return ref.watch(appCacheRepositoryProvider).inspect();
});

/// 缓存操作入口（清除动作库 / 图片缓存并刷新相关状态）。
final appCacheControllerProvider = Provider<AppCacheController>(
  AppCacheController.new,
);

/// 清除本地缓存并让动作列表、存储占用等 Provider 失效。
class AppCacheController {
  AppCacheController(this._ref);

  final Ref _ref;

  /// 删除动作库 SQLite 缓存与网络图片缓存，并清空内存图片。
  Future<void> clear() async {
    await _ref.read(appCacheRepositoryProvider).clear();
    imageCache
      ..clear()
      ..clearLiveImages();
    _ref.invalidate(appStorageInfoProvider);
    _ref.invalidate(exercisesControllerProvider);
    _ref.invalidate(muscleGroupsProvider);
    _ref.invalidate(equipmentListProvider);
    _ref.invalidate(exercisesFilterProvider);
  }
}
