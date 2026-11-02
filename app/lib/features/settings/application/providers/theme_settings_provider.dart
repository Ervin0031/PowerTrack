import 'package:app_flutter/features/settings/data/datasources/theme_settings_storage.dart';
import 'package:app_flutter/features/settings/domain/entities/theme_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/dio_provider.dart';

part 'theme_settings_provider.g.dart';

/// 主题设置存储 Provider（基础设施依赖，与应用同生命周期）。
final themeSettingsStorageProvider = Provider<ThemeSettingsStorage>(
  (ref) => ThemeSettingsStorage(ref.watch(sharedPreferencesProvider)),
);

/// 全局主题设置状态。
///
/// 由 `@riverpod` 生成 `themeSettingsProvider`（keepAlive），
/// 启动即从本地读取，修改后写回本地并刷新内存态，驱动整个 App 换肤。
@Riverpod(keepAlive: true)
class ThemeSettingsNotifier extends _$ThemeSettingsNotifier {
  @override
  ThemeSettings build() => ref.watch(themeSettingsStorageProvider).load();

  /// 应用并持久化新的主题设置。
  Future<void> update(ThemeSettings next) async {
    await ref.read(themeSettingsStorageProvider).save(next);
    state = next;
  }
}
