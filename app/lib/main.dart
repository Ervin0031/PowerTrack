import 'package:app_flutter/core/ui/app_scroll_behavior.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/providers/dio_provider.dart';
import 'core/router/app_router.dart';
import 'core/storage/token_storage.dart';
import 'core/ui/app_theme.dart';
import 'features/settings/application/providers/theme_data_providers.dart';
import 'features/training/application/rest_alert_service.dart';

/// 应用入口。
///
/// 启动流程：
/// 1. 绑定 Flutter 引擎，确保插件和 SystemChrome 可用。
/// 2. 初始化本地存储。
/// 3. 用 ProviderContainer 注入异步依赖。
/// 4. 交给 UncontrolledProviderScope 承载整个应用。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // 全局兜底：任意 widget 构建失败时展示友好提示而非灰色空白。
  ErrorWidget.builder = _friendlyErrorBuilder;

  // SharedPreferences 是异步依赖，提前初始化可让 Provider 保持同步读取。
  final prefs = await SharedPreferences.getInstance();

  // 令牌从安全存储读进内存：路由守卫与拦截器要在同步链路上读到它，必须赶在首帧前。
  final tokenStorage = TokenStorage(prefs);
  await tokenStorage.hydrate();

  // 本地通知插件尽早初始化，训练休息闹钟才能调度。
  await RestAlertService.instance.ensureInitialized();

  // 使用 ProviderContainer 是为了把启动期拿到的依赖 override 到 Riverpod 依赖图里。
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      tokenStorageProvider.overrideWithValue(tokenStorage),
    ],
  );

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

/// 根组件。
///
/// 职责：
/// - 监听 appRouterProvider 获取全局路由。
/// - 配置 Material 3 亮暗主题（跟随系统）。
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final lightTheme = ref.watch(appLightThemeProvider);
    final darkTheme = ref.watch(appDarkThemeProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: AppConfig.showPerformanceOverlay,
      // 提供 Material / Widgets / Cupertino 本地化，支撑 CupertinoTimerPicker 等组件。
      // material_ui 自带的 delegates 用的是 cupertino_ui 分支类型，
      // 需再补 Flutter 官方的 GlobalCupertinoLocalizations 让
      // package:flutter/cupertino.dart 的组件（如 CupertinoTimerPicker）能解析到。
      localizationsDelegates: [...GlobalMaterialLocalizations.delegates, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      scrollBehavior: AppScrollBehavior(),
      // 大字体模式下限制缩放上限，避免布局溢出崩坏。
      builder: (context, child) {
        final content = MediaQuery.withClampedTextScaling(maxScaleFactor: 1.4, child: child ?? const SizedBox.shrink());
        // return FpsOverlay(enabled: AppConfig.showFps, child: content);
        return content;
      },
    );
  }
}

/// 构建失败时展示与主题同色的友好提示，而非灰色空白。
///
/// ErrorWidget.builder 是全局回调拿不到出现错误的 context，这里只能按
/// 平台亮度取默认主题（Baseline Purple），无法跟随用户自定义种子色。
Widget _friendlyErrorBuilder(FlutterErrorDetails details) {
  final theme = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark
      ? AppTheme.darkTheme
      : AppTheme.lightTheme;
  final colorScheme = theme.colorScheme;
  return Material(
    color: colorScheme.surface,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('页面出现了一点问题', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('请稍后重试。', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    ),
  );
}
