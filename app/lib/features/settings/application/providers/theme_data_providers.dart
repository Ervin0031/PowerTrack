import 'package:app_flutter/core/ui/app_theme.dart';
import 'package:app_flutter/features/settings/application/providers/theme_settings_provider.dart';
import 'package:app_flutter/features/settings/domain/entities/theme_settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前亮暗模式（驱动 [MaterialApp.themeMode]）。
final appThemeModeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(themeSettingsNotifierProvider).mode;
  return switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
});

/// 当前用户设置下的亮色 [ThemeData]。
final appLightThemeProvider = Provider<ThemeData>(
  (ref) => AppTheme.fromSettings(ref.watch(themeSettingsNotifierProvider), Brightness.light),
);

/// 当前用户设置下的暗色 [ThemeData]。
final appDarkThemeProvider = Provider<ThemeData>(
  (ref) => AppTheme.fromSettings(ref.watch(themeSettingsNotifierProvider), Brightness.dark),
);
