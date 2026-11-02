import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/settings/domain/entities/theme_settings.dart';
import 'app_radius.dart';

/// [ToneStrategy] → [M3EColorVariant] 的映射。
extension ToneStrategyX on ToneStrategy {
  M3EColorVariant toColorVariant() {
    switch (this) {
      case ToneStrategy.tonalSpot:
        return M3EColorVariant.tonalSpot;
      case ToneStrategy.vibrant:
        return M3EColorVariant.vibrant;
      case ToneStrategy.fidelity:
        return M3EColorVariant.fidelity;
      case ToneStrategy.expressive:
        return M3EColorVariant.expressive;
      case ToneStrategy.monochrome:
        return M3EColorVariant.monochrome;
      case ToneStrategy.neutral:
        return M3EColorVariant.neutral;
      case ToneStrategy.rainbow:
        return M3EColorVariant.rainbow;
      case ToneStrategy.fruitSalad:
        return M3EColorVariant.fruitSalad;
    }
  }
}

/// 页面转场与 BunPod 相同：Android、iOS 都是 Fade Forwards。
///
/// 新页面从右侧约 25% 淡入，底页向左淡出。时长 450ms。
const PageTransitionsTheme _fadeForwardsTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
  },
);

/// 应用主题工厂。
///
/// 使用 m3e_core 的 [M3EColorScheme]（AOSP ColorSpec2026 算法）替代 Flutter 原生
/// [ColorScheme.fromSeed] 与 FlexSeedScheme：由单个种子色按所选 [M3EColorVariant]
/// 派生整条 M3E 色板，保证与 M3E 组件库的取色风格一致。
///
/// 静态 [lightTheme] / [darkTheme] 用于测试等无需动态换肤的场景；
/// 运行期主题交由 `theme_data_providers.dart` 的 Provider 按用户设置实时生成。
abstract final class AppTheme {
  /// 由用户 [ThemeSettings] 派生指定亮度的 [ThemeData]。
  static ThemeData fromSettings(ThemeSettings settings, Brightness brightness) {
    final colorScheme = M3EColorScheme.generate(
      seedColor: Color(settings.primaryColor),
      brightness: brightness,
      variant: settings.tone.toColorVariant(),
    );
    // 与框架默认一致：Typography + ColorScheme 推导 TextTheme，
    // 不依赖 context，供主题内各组件（如 listTileTheme）引用。
    // 不指定 fontFamily，走平台原生字体（iOS San Francisco / Android Roboto 等）。
    final textTheme = brightness == Brightness.dark
        ? M3ETypography.emphasized(
            ThemeData.dark().textTheme.apply(fontFamily: 'GoogleSansFlex'),
          )
        : M3ETypography.emphasized(
            ThemeData.light().textTheme.apply(fontFamily: 'GoogleSansFlex'),
          );
    //         .toEmphasized();
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _fadeForwardsTransitions,
      colorScheme: colorScheme,
      fontFamily: 'GoogleSansFlex',
      textTheme: textTheme,
      // 选中 / 输入框光标颜色跟随主色。
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: colorScheme.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(borderSide: BorderSide.none),
      ),

      // 卡片默认值收口：业务代码不再传 elevation/margin/color。
      // 基色 surfaceContainer 与 M3ESegmentedColumn 默认一致。
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(iconSize: WidgetStatePropertyAll(28)),
      ),
      // AppBar 官方取色：背景统一由主题 AppBarTheme 提供（surface 实色，
      // 滚动不换色、不抬升、不叠 surfaceTint），页面层不再硬编码背景或画分割线。
      appBarTheme: AppBarThemeData(
        backgroundColor: colorScheme.surface,
        // foregroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        actionsPadding: EdgeInsets.only(right: 12),
        // leadingWidth: 60,
        // titleSpacing: 24,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        clipBehavior: .hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(42),
        ),
      ),
    );
  }

  /// 亮色模式：默认设置（Baseline Purple）。
  static ThemeData get lightTheme =>
      fromSettings(const ThemeSettings(), Brightness.light);

  /// 暗色模式：默认设置。
  static ThemeData get darkTheme =>
      fromSettings(const ThemeSettings(), Brightness.dark);
}
