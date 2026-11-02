import 'package:flutter/cupertino.dart' show CupertinoScrollbar;
import 'package:material_ui/material_ui.dart';

/// 全局滚动行为：纵向列表显示滚动条；横向滚动不加滚动条，避免和外层 ListView 抢惯性。
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (axisDirectionToAxis(details.direction) == Axis.horizontal) {
      return child;
    }
    return switch (getPlatform(context)) {
      TargetPlatform.iOS => CupertinoScrollbar(controller: details.controller, child: child),
      TargetPlatform.macOS => CupertinoScrollbar(controller: details.controller, child: child),
      _ => Scrollbar(controller: details.controller, child: child),
    };
  }

  /// 全局关闭 overscroll 指示器（光晕 / 拉伸效果）。
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// 嵌套在纵向 ListView 里的横向滚动（PageView / CarouselView）：
/// 关闭回弹和滚动条，避免松手后和外层列表互抢 ballistic、上下抽搐。
class NestedHorizontalScrollBehavior extends MaterialScrollBehavior {
  const NestedHorizontalScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
