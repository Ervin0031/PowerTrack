import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 力竭后自动把本动作未完成组重量下调 10%。默认开启。
///
/// 持久化到 SharedPreferences；可在训练页左上角菜单 → 训练设置中关闭。
class FatigueAutoReduceController extends Notifier<bool> {
  static const _key = 'training.fatigue_auto_reduce_enabled';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(sharedPreferencesProvider).setBool(_key, enabled);
    state = enabled;
  }
}

final fatigueAutoReduceEnabledProvider =
    NotifierProvider<FatigueAutoReduceController, bool>(FatigueAutoReduceController.new);
