import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 休息结束「音频/通知提示」开关，默认开启。
///
/// 与 [restTimerSettingsProvider] 独立：可关提示但保留倒计时条，反之亦然。
class RestAudioCueController extends Notifier<bool> {
  static const _key = 'training.rest_audio_cue_enabled';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(sharedPreferencesProvider).setBool(_key, enabled);
    state = enabled;
  }
}

final restAudioCueEnabledProvider =
    NotifierProvider<RestAudioCueController, bool>(RestAudioCueController.new);
