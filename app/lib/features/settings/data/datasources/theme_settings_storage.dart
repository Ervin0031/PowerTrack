import 'package:app_flutter/features/settings/domain/entities/theme_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题设置的本地持久化。
///
/// 职责：
/// - 把 [ThemeSettings] 序列化为少量 SharedPreferences 键值。
/// - 启动时同步读取默认值，避免 Widget 层再做异步等待。
class ThemeSettingsStorage {
  ThemeSettingsStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _primaryColorKey = 'settings.theme.primary_color';
  static const _modeKey = 'settings.theme.mode';
  static const _toneKey = 'settings.theme.tone';
  // 旧版自定义字体键；读取时顺带清掉，避免残留。
  static const _legacyFontFamilyKey = 'settings.theme.font_family';

  /// 读取当前设置；任意字段缺失时回退到 [ThemeSettings] 默认值。
  ThemeSettings load() {
    // 不再捆绑第三方字体，遗留偏好直接丢弃。
    if (_prefs.containsKey(_legacyFontFamilyKey)) {
      _prefs.remove(_legacyFontFamilyKey);
    }
    final primaryColor = _prefs.getInt(_primaryColorKey);
    final modeIndex = _prefs.getInt(_modeKey);
    final toneIndex = _prefs.getInt(_toneKey);
    return ThemeSettings(
      primaryColor: primaryColor ?? ThemeSettings.defaultPrimaryColor,
      mode: AppThemeMode.values[modeIndex ?? AppThemeMode.system.index],
      tone: ToneStrategy.values[toneIndex ?? ToneStrategy.vibrant.index],
    );
  }

  /// 全量写入；调用方负责更新内存态（Provider state）。
  Future<void> save(ThemeSettings settings) async {
    await _prefs.setInt(_primaryColorKey, settings.primaryColor);
    await _prefs.setInt(_modeKey, settings.mode.index);
    await _prefs.setInt(_toneKey, settings.tone.index);
    await _prefs.remove(_legacyFontFamilyKey);
  }
}
