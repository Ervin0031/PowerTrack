// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$themeSettingsNotifierHash() =>
    r'3771a3c6be7299d1cf324ba262371eadc9175f2d';

/// 全局主题设置状态。
///
/// 由 `@riverpod` 生成 `themeSettingsProvider`（keepAlive），
/// 启动即从本地读取，修改后写回本地并刷新内存态，驱动整个 App 换肤。
///
/// Copied from [ThemeSettingsNotifier].
@ProviderFor(ThemeSettingsNotifier)
final themeSettingsNotifierProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettings>.internal(
      ThemeSettingsNotifier.new,
      name: r'themeSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$themeSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ThemeSettingsNotifier = Notifier<ThemeSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
