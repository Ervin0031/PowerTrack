import 'package:material_ui/material_ui.dart';
import 'package:heroine/heroine.dart';

/// 对 [HeroineController] 的防御性包装。
///
/// GoRouter 在重定向或快速切换时，可能产生 [Route.animation] 尚未就绪的
/// [PageRoute]。原生的 [HeroineController] 在这些情况下访问
/// `toRoute.animation!` / `fromRoute.animation!` 会抛出
/// "Null check operator used on a null value"。
///
/// 本包装在将事件转发给 [HeroineController] 前先检查 animation 是否为 null，
/// 若为 null 则跳过本次转场动画，避免启动崩溃。
class SafeHeroineController extends HeroineController {
  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (!_hasValidAnimations(topRoute, previousTopRoute)) return;
    super.didChangeTop(topRoute, previousTopRoute);
  }

  @override
  void didStartUserGesture(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_hasValidAnimations(route, previousRoute)) return;
    super.didStartUserGesture(route, previousRoute);
  }

  bool _hasValidAnimations(Route<dynamic>? toRoute, Route<dynamic>? fromRoute) {
    if (toRoute == null) return false;
    if (toRoute is! PageRoute<dynamic>) return false;
    if (toRoute.animation == null) return false;

    if (fromRoute != null) {
      if (fromRoute is! PageRoute<dynamic>) return false;
      if (fromRoute.animation == null) return false;
    }

    return true;
  }
}
