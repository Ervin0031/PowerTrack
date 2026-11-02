import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rest_timer_settings_provider.g.dart';

/// 全局组间休息目标时长（秒）。
///
/// 每完成一组，底部的休息计时条按此目标计时：未到目标为正常色进度条，
/// 超过目标继续计时且进度条变红提示休息过头。
/// 持久化到 SharedPreferences，重启保持。
///
/// `null` 表示休息计时已关闭（计时条隐藏）；非 null 为开启的秒数。
@Riverpod(keepAlive: true)
class RestTimerSettings extends _$RestTimerSettings {
  static const _enabledKey = 'training.rest_timer_enabled';
  static const _secondsKey = 'training.rest_target_seconds';

  /// 默认组间休息时长（秒）。
  static const defaultSeconds = 90;

  @override
  int? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs.getBool(_enabledKey) == false) return null;
    return prefs.getInt(_secondsKey) ?? defaultSeconds;
  }

  /// 开启并设置目标秒数。
  Future<void> setSeconds(int seconds) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_secondsKey, seconds);
    state = seconds;
  }

  /// 关闭休息计时。
  Future<void> disable() async {
    await ref.read(sharedPreferencesProvider).setBool(_enabledKey, false);
    state = null;
  }
}