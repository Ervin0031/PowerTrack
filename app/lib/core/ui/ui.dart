// UI 基础能力统一导出。
//
// feature 页面只需要 import `core/ui/ui.dart`，即可拿到圆角、间距与安全区扩展；
// 颜色一律走 `Theme.of(context).colorScheme`，不再单独导出。
export 'app_spacing.dart';
export 'app_radius.dart';
export 'app_theme.dart';
export 'fps_overlay.dart';
export 'safe_area_ext.dart';
