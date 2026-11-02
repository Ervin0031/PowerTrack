/// 主题设置领域模型（纯 Dart，零依赖）。
///
/// 仅描述「用户想怎样的主题」，不含任何构建 ThemeData 或持久化的逻辑，
/// 保证 Domain 层不被 Flutter / Riverpod / FlexSeedScheme 污染。
class ThemeSettings {
  const ThemeSettings({
    this.primaryColor = defaultPrimaryColor,
    this.mode = AppThemeMode.system,
    this.tone = ToneStrategy.tonalSpot,
  });

  /// 主种子色（驱动整条 Material 3 色板），以 ARGB int 存储便于序列化。
  final int primaryColor;

  /// 亮 / 暗 / 跟随系统。
  final AppThemeMode mode;

  /// 调色策略：决定色板的鲜艳度与对比度。
  final ToneStrategy tone;

  /// 默认主色：与原 AppTheme 的 Baseline Purple 保持一致。
  static const defaultPrimaryColor = 0xFF6750A4;

  ThemeSettings copyWith({int? primaryColor, AppThemeMode? mode, ToneStrategy? tone}) =>
      ThemeSettings(primaryColor: primaryColor ?? this.primaryColor, mode: mode ?? this.mode, tone: tone ?? this.tone);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeSettings && primaryColor == other.primaryColor && mode == other.mode && tone == other.tone;

  @override
  int get hashCode => Object.hash(primaryColor, mode, tone);
}

/// 主题明暗模式。
enum AppThemeMode { system, light, dark }

/// 调色策略，对应 m3e_core 的 M3EColorVariant（AOSP ColorSpec2026 色板）。
enum ToneStrategy {
  /// 保留种子色原色相的 M3 默认色板。
  tonalSpot,

  /// 提高饱和度，保留原色相。
  vibrant,

  /// 尽量贴近种子色本身，适合严格品牌色。
  fidelity,

  /// 补色色相偏移（如黄变粉），M3 Expressive 标志性色板。
  expressive,

  /// 灰度色板。
  monochrome,

  /// 低彩度安静色板。
  neutral,

  /// 多色相偏移色板。
  rainbow,

  /// 水果拼盘式多彩色板。
  fruitSalad,
}
