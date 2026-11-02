import 'package:material_ui/material_ui.dart';

/// 底部导航各 Tab 页的主滚动控制器注册表。
///
/// 各 Tab 页在 [initState] 注册自身的主 [ScrollController]，离开时注销；
/// 根页面据此在「再次点击当前 Tab」时把对应页滚回顶部（原生交互习惯）。
class TabScrollRegistry {
  static final Map<int, ScrollController> _controllers = {};

  static void register(int index, ScrollController controller) => _controllers[index] = controller;

  static void unregister(int index, ScrollController controller) {
    if (_controllers[index] == controller) _controllers.remove(index);
  }

  static ScrollController? of(int index) => _controllers[index];
}
