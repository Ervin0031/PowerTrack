import 'dart:io';

import 'package:app_flutter/core/database/app_database.dart';
import 'package:app_flutter/features/exercises/data/repositories/exercise_repository.dart';
import 'package:app_flutter/features/settings/domain/entities/app_storage_info.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 本地缓存仓储：统计磁盘占用，并清除动作库与图片缓存。
///
/// 不触碰登录令牌、主题、健身档案等用户偏好。
class AppCacheRepository {
  AppCacheRepository(this._exercises);

  final ExerciseRepository _exercises;

  /// 读取当前可统计的本地占用（数据库 + 图片缓存 + 其它临时目录）。
  Future<AppStorageInfo> inspect() async {
    final imageDir = await _imageCacheDirectory();
    final tempDir = await getTemporaryDirectory();
    var cacheDir = tempDir;
    try {
      cacheDir = await getApplicationCacheDirectory();
    } catch (_) {
      // 部分平台无独立 Cache 目录，回退到临时目录即可。
    }

    final imageBytes = await _directorySize(imageDir);
    final otherBytes =
        await _directorySize(
          tempDir,
          skip: {if (imageDir != null) imageDir.path},
        ) +
        (p.equals(cacheDir.path, tempDir.path)
            ? 0
            : await _directorySize(
                cacheDir,
                skip: {if (imageDir != null) imageDir.path},
              ));

    return AppStorageInfo(
      databaseBytes: await _fileSize(await AppDatabase.filePath()),
      imageCacheBytes: imageBytes,
      otherCacheBytes: otherBytes,
      exerciseCount: await _exercises.cachedExerciseCount(),
      exerciseDetailCount: await _exercises.cachedExerciseDetailCount(),
    );
  }

  /// 清除动作库 SQLite 缓存与网络图片磁盘缓存。
  Future<void> clear() async {
    await _exercises.clearCache();
    await DefaultCacheManager().emptyCache();
  }

  Future<Directory?> _imageCacheDirectory() async {
    final temp = await getTemporaryDirectory();
    final dir = Directory(p.join(temp.path, DefaultCacheManager.key));
    if (await dir.exists()) return dir;
    try {
      final cache = await getApplicationCacheDirectory();
      final alt = Directory(p.join(cache.path, DefaultCacheManager.key));
      if (await alt.exists()) return alt;
    } catch (_) {}
    return dir;
  }

  Future<int> _fileSize(String path) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    return file.length();
  }

  Future<int> _directorySize(
    Directory? dir, {
    Set<String> skip = const {},
  }) async {
    if (dir == null || !await dir.exists()) return 0;
    var total = 0;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        if (skip.any(
          (root) =>
              p.isWithin(root, entity.path) || p.equals(root, entity.path),
        )) {
          continue;
        }
        try {
          total += await entity.length();
        } catch (_) {}
      }
    } catch (_) {
      return total;
    }
    return total;
  }
}

/// 应用缓存仓储 Provider。
final appCacheRepositoryProvider = Provider<AppCacheRepository>(
  (ref) => AppCacheRepository(ref.watch(exerciseRepositoryProvider)),
);
