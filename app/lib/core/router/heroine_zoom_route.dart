import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:heroine/heroine.dart';

import 'edge_drag_dismissable.dart';

/// Heroine Zoom Transition 专用的 [Page] / [PageRoute]。
///
/// 复刻官方 example 中的 `HeroineZoomRoute`：
/// - 透明背景（`opaque: false`），展开时能看到下层页面
/// - 整个页面内容用 [Heroine] + [EdgeDragDismissable] 包裹，支持从屏幕
///   左/右/底边缘以及 AppBar 区域拖拽关闭
/// - 拖拽时页面内容轻微缩小、圆角和阴影出现，呈现“卡片被拉走”的视觉效果
/// - 使用 [FadeShuttleBuilder] 完成飞行过程中的淡入淡出
class HeroineZoomPage<T> extends Page<T> {
  const HeroineZoomPage({
    required this.tag,
    required this.builder,
    this.fullscreenDialog = false,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Object tag;
  final Widget Function(BuildContext context) builder;
  final bool fullscreenDialog;

  @override
  Route<T> createRoute(BuildContext context) =>
      HeroineZoomRoute<T>(tag: tag, builder: builder, settings: this, fullscreenDialog: fullscreenDialog);
}

class HeroineZoomRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin, HeroinePageRouteMixin {
  HeroineZoomRoute({
    required this.tag,
    required this.builder,
    required RouteSettings settings,
    required this._fullscreenDialog,
  }) : super(settings: settings);

  final Object tag;
  final Widget Function(BuildContext context) builder;

  @override
  bool get fullscreenDialog => _fullscreenDialog;
  final bool _fullscreenDialog;

  @override
  bool get maintainState => false;

  @override
  String? get title => null;

  @override
  Widget buildContent(BuildContext context) {
    final topEdge = MediaQuery.of(context).padding.top + kToolbarHeight + 16;
    return HeroMode(
      // 禁用 Flutter 默认 Hero，完全由 Heroine 接管
      enabled: false,
      child: EdgeDragDismissable(
        edgeInsets: EdgeInsets.only(left: 24, right: 24, bottom: 24, top: topEdge),
        child: ReactToHeroineDismiss(
          builder: (context, progress, offset, child) => Transform.scale(
            scale: 1 - progress * 0.2,
            alignment: Alignment.center,
            child: Heroine(
              tag: tag,
              motion: CupertinoMotion.smooth(),
              flightShuttleBuilder: const FadeShuttleBuilder(),
              child: Material(
                clipBehavior: Clip.hardEdge,
                elevation: progress > 0 ? 24 : 0,
                borderRadius: BorderRadius.circular(progress > 0 ? 32 : 0),
                child: child,
              ),
            ),
          ),
          child: builder(context),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => null;
}
