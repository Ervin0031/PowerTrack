import 'dart:math' show max;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// Fade Forwards 页面，并支持从左缘滑动返回。
///
/// 按钮触发的进出场与 [FadeForwardsPageTransitionsBuilder] 一致。
/// 手指拖动期间改为线性，页面跟着手指走。
class FadeForwardsPage<T> extends Page<T> {
  const FadeForwardsPage({
    required this.child,
    this.popGesture = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;

  /// 为 false 时不响应左缘返回，把这段手势留给页面自己（例如聊天抽屉）。
  final bool popGesture;

  @override
  Route<T> createRoute(BuildContext context) => _FadeForwardsRoute<T>(this);
}

class _FadeForwardsRoute<T> extends PageRoute<T> {
  _FadeForwardsRoute(FadeForwardsPage<T> page) : super(settings: page);

  FadeForwardsPage<T> get _page => settings as FadeForwardsPage<T>;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(
    milliseconds: FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
  );

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  bool get popGestureEnabled =>
      _page.popGesture && !fullscreenDialog && super.popGestureEnabled;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _delegatedTransition;

  static Widget? _delegatedTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    return _outgoing(context, secondaryAnimation, child);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _page.child,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final page = DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (context, animation, child) {
        return _fadeSlide(
          context: context,
          animation: animation,
          fadeIn: true,
          from: const Offset(0.25, 0),
          to: Offset.zero,
          child: child,
        );
      },
      reverseBuilder: (context, animation, child) {
        return IgnorePointer(
          ignoring: animation.status == AnimationStatus.forward,
          child: _fadeSlide(
            context: context,
            animation: animation,
            fadeIn: false,
            from: Offset.zero,
            to: const Offset(0.25, 0),
            child: child,
          ),
        );
      },
      child: _outgoing(context, secondaryAnimation, child),
    );
    if (!_page.popGesture) return page;
    return _EdgeBackDetector<T>(
      enabled: () => popGestureEnabled,
      onStart: () {
        return _BackController<T>(
          navigator: navigator!,
          controller: controller!,
          isCurrent: () => isCurrent,
          isActive: () => isActive,
        );
      },
      child: page,
    );
  }
}

Widget _outgoing(
  BuildContext context,
  Animation<double> secondaryAnimation,
  Widget? child,
) {
  final body = DualTransitionBuilder(
    animation: ReverseAnimation(secondaryAnimation),
    forwardBuilder: (context, animation, child) {
      return _fadeSlide(
        context: context,
        animation: animation,
        fadeIn: true,
        from: const Offset(-0.25, 0),
        to: Offset.zero,
        child: child,
      );
    },
    reverseBuilder: (context, animation, child) {
      return _fadeSlide(
        context: context,
        animation: animation,
        fadeIn: false,
        from: Offset.zero,
        to: const Offset(-0.25, 0),
        child: child,
      );
    },
    child: child,
  );

  final opaque = ModalRoute.opaqueOf(context) ?? true;
  if (!opaque) return body;
  // 底下的页面向左滑时，右边会露出一块。这里铺上页面底色，避免透出窗口的纯黑。
  return ColoredBox(
    color: secondaryAnimation.isAnimating
        ? Theme.of(context).colorScheme.surface
        : const Color(0x00000000),
    child: body,
  );
}

Widget _fadeSlide({
  required BuildContext context,
  required Animation<double> animation,
  required bool fadeIn,
  required Offset from,
  required Offset to,
  required Widget? child,
}) {
  final tracking = ModalRoute.of(context)?.popGestureInProgress ?? false;
  final Animatable<double> fade = tracking
      ? Tween<double>(begin: fadeIn ? 0 : 1, end: fadeIn ? 1 : 0)
      : Tween<double>(
          begin: fadeIn ? 0 : 1,
          end: fadeIn ? 1 : 0,
        ).chain(CurveTween(curve: Interval(0, fadeIn ? 0.75 : 0.25)));
  final slide = Tween<Offset>(begin: from, end: to);
  final Animatable<Offset> move = tracking
      ? slide
      : slide.chain(CurveTween(curve: Curves.easeInOutCubicEmphasized));
  return FadeTransition(
    opacity: fade.animate(animation),
    child: SlideTransition(position: move.animate(animation), child: child),
  );
}

const double _kBackGestureWidth = 20;
const double _kMinFlingVelocity = 1;
const Duration _kDroppedSwipeDuration = Duration(milliseconds: 350);

class _EdgeBackDetector<T> extends StatefulWidget {
  const _EdgeBackDetector({
    required this.enabled,
    required this.onStart,
    required this.child,
  });

  final Widget child;
  final ValueGetter<bool> enabled;
  final ValueGetter<_BackController<T>> onStart;

  @override
  State<_EdgeBackDetector<T>> createState() => _EdgeBackDetectorState<T>();
}

class _EdgeBackDetectorState<T> extends State<_EdgeBackDetector<T>> {
  _BackController<T>? _controller;
  late final HorizontalDragGestureRecognizer _recognizer =
      HorizontalDragGestureRecognizer(debugOwner: this)
        ..onStart = _onStart
        ..onUpdate = _onUpdate
        ..onEnd = _onEnd
        ..onCancel = _onCancel;

  @override
  void dispose() {
    _recognizer.dispose();
    final pending = _controller;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pending.navigator.mounted) pending.navigator.didStopUserGesture();
      });
    }
    super.dispose();
  }

  void _onStart(DragStartDetails details) {
    _controller = widget.onStart();
  }

  void _onUpdate(DragUpdateDetails details) {
    final width = context.size?.width ?? 1;
    _controller?.dragUpdate(_logical((details.primaryDelta ?? 0) / width));
  }

  void _onEnd(DragEndDetails details) {
    final width = context.size?.width ?? 1;
    _controller?.dragEnd(_logical(details.velocity.pixelsPerSecond.dx / width));
    _controller = null;
  }

  void _onCancel() {
    _controller?.dragEnd(0);
    _controller = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.enabled()) _recognizer.addPointer(event);
  }

  double _logical(double value) {
    return switch (Directionality.of(context)) {
      TextDirection.rtl => -value,
      TextDirection.ltr => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final inset = switch (Directionality.of(context)) {
      TextDirection.rtl => padding.right,
      TextDirection.ltr => padding.left,
    };
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          width: max(inset, _kBackGestureWidth),
          top: 0,
          bottom: 0,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onPointerDown,
          ),
        ),
      ],
    );
  }
}

class _BackController<T> {
  _BackController({
    required this.navigator,
    required this.controller,
    required this.isCurrent,
    required this.isActive,
  }) {
    navigator.didStartUserGesture();
  }

  final NavigatorState navigator;
  final AnimationController controller;
  final ValueGetter<bool> isCurrent;
  final ValueGetter<bool> isActive;

  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  void dragEnd(double velocity) {
    final current = isCurrent();
    final bool forward;
    if (!current) {
      forward = isActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      forward = velocity <= 0;
    } else {
      forward = controller.value > 0.5;
    }

    if (forward) {
      controller.animateTo(
        1,
        duration: _kDroppedSwipeDuration,
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    } else {
      if (current) navigator.pop();
      if (controller.isAnimating) {
        controller.animateBack(
          0,
          duration: _kDroppedSwipeDuration,
          curve: Curves.fastEaseInToSlowEaseOut,
        );
      }
    }

    if (controller.isAnimating) {
      late AnimationStatusListener listener;
      listener = (status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          navigator.didStopUserGesture();
          controller.removeStatusListener(listener);
        }
      };
      controller.addStatusListener(listener);
    } else {
      navigator.didStopUserGesture();
    }
  }
}
