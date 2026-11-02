import 'dart:math' as math;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

/// 适配渐变模糊 AppBar 的下拉刷新。
///
/// [M3EPullToRefreshIndicator] 把 [edgeOffset] 做成 Column 占位，滚动视口从
/// AppBar 底边才开始，背后没有内容，BackdropFilter 出不了渐变模糊。
/// 这里列表始终铺满 body，只有下拉时才下移；指示器仍出现在 [edgeOffset] 处。
class GlassPullToRefresh extends StatefulWidget {
  const GlassPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 0,
    this.notificationPredicate,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double edgeOffset;
  final bool Function(ScrollNotification notification)? notificationPredicate;

  @override
  State<GlassPullToRefresh> createState() => _GlassPullToRefreshState();
}

class _GlassPullToRefreshState extends State<GlassPullToRefresh> with SingleTickerProviderStateMixin {
  static const List<Shapes> _shapes = [
    Shapes.softBurst,
    Shapes.pentagon,
    Shapes.pill,
    Shapes.arch,
    Shapes.c6SidedCookie,
  ];

  late final SingleMotionController _motionCtrl;

  double _rawDistancePulled = 0;
  double _dragOffset = 0;
  bool _isRefreshing = false;
  bool _isDragging = false;
  bool _hasTriggeredHaptic = false;
  bool _isAnimating = false;

  static const _triggerDistance = 80.0;
  static const _indicatorHeight = 70.0;

  @override
  void initState() {
    super.initState();
    _motionCtrl = SingleMotionController(vsync: this, motion: M3EMotion.expressiveSpatialDefault.toMotion());
    _motionCtrl.addListener(() {
      if (_isAnimating && mounted) setState(() => _dragOffset = _motionCtrl.value);
    });
  }

  @override
  void dispose() {
    _motionCtrl.dispose();
    super.dispose();
  }

  bool _defaultPredicate(ScrollNotification notification) => notification.depth == 0;

  void _handleScrollNotification(ScrollNotification notification) {
    final predicate = widget.notificationPredicate ?? _defaultPredicate;
    if (!predicate(notification) || _isRefreshing) return;

    if (notification is ScrollStartNotification) {
      if (notification.metrics.extentBefore == 0 && notification.dragDetails != null) {
        _isDragging = true;
        _hasTriggeredHaptic = false;
      }
    } else if (notification is OverscrollNotification && _isDragging) {
      if (notification.dragDetails == null) {
        _isDragging = false;
        _onDragEnd();
        return;
      }
      if (notification.overscroll < 0) {
        _updateDragDistance(_rawDistancePulled + -notification.overscroll * 0.55);
      }
    } else if (notification is ScrollUpdateNotification && _isDragging) {
      if (notification.dragDetails == null) {
        _isDragging = false;
        _onDragEnd();
        return;
      }
      final delta = notification.scrollDelta;
      if (notification.metrics.extentBefore == 0 && delta != null && delta < 0) {
        _updateDragDistance(_rawDistancePulled + -delta * 0.55);
      } else if (_rawDistancePulled > 0 && delta != null && delta > 0) {
        _updateDragDistance(math.max(0, _rawDistancePulled - delta * 0.55));
      }
    } else if (notification is ScrollEndNotification && _isDragging) {
      _isDragging = false;
      _onDragEnd();
    }
  }

  double _verticalOffset(double distance) {
    if (distance <= _triggerDistance) return distance;
    final linearTension = (distance / _triggerDistance - 1).clamp(0.0, 2.0);
    final tension = linearTension - (linearTension * linearTension / 4);
    return _triggerDistance + _triggerDistance * tension;
  }

  void _updateDragDistance(double newDistance) {
    final clamped = newDistance.clamp(0.0, _triggerDistance * 1.8);
    setState(() {
      _rawDistancePulled = clamped;
      _dragOffset = _verticalOffset(clamped);
      _isAnimating = false;
      _motionCtrl.value = _dragOffset;
    });
    if (_rawDistancePulled >= _triggerDistance && !_hasTriggeredHaptic) {
      _hasTriggeredHaptic = true;
      applyHaptic(M3EHapticFeedback.medium);
    } else if (_rawDistancePulled < _triggerDistance) {
      _hasTriggeredHaptic = false;
    }
  }

  void _onDragEnd() {
    if (_isRefreshing) return;
    if (_rawDistancePulled >= _triggerDistance) {
      _motionCtrl.motion = M3EMotion.expressiveSpatialDefault.toMotion();
      _startRefresh();
    } else if (_dragOffset > 0) {
      _motionCtrl.motion = M3EMotion.expressiveEffectsFast.toMotion();
      _isAnimating = true;
      _rawDistancePulled = 0;
      _motionCtrl.animateTo(0);
    }
  }

  Future<void> _startRefresh() async {
    setState(() {
      _isRefreshing = true;
      _isAnimating = true;
    });
    _motionCtrl.motion = M3EMotion.expressiveSpatialDefault.toMotion();
    _motionCtrl.animateTo(_indicatorHeight);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _isAnimating = true;
          _rawDistancePulled = 0;
        });
        _motionCtrl.motion = M3EMotion.expressiveSpatialDefault.toMotion();
        _motionCtrl.animateTo(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerHeight = math.max(0.0, _dragOffset);
    final progress = (headerHeight / _triggerDistance).clamp(0.0, 2.0);
    final visualProgress = _isRefreshing
        ? 1.0
        : _rawDistancePulled > 0
        ? (headerHeight / _triggerDistance).clamp(0.0, 1.0)
        : (headerHeight / _indicatorHeight).clamp(0.0, 1.0);

    Widget indicator = M3EContainedLoadingIndicator(
      shapes: _shapes,
      width: 48,
      height: 48,
      progress: _isRefreshing ? null : progress.clamp(0.0, 1.0),
      semanticsLabel: 'Refreshing',
      semanticsValue: _isRefreshing ? 'In progress' : null,
    );
    if (!_isRefreshing && progress > 1) {
      indicator = Transform.rotate(angle: -(progress - 1) * math.pi, child: indicator);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleScrollNotification(notification);
        return false;
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: headerHeight,
            left: 0,
            right: 0,
            bottom: -headerHeight,
            child: widget.child,
          ),
          if (headerHeight > 0.5)
            Positioned(
              top: widget.edgeOffset,
              left: 0,
              right: 0,
              height: headerHeight,
              child: IgnorePointer(
                child: ClipRect(
                  child: Center(
                    child: Opacity(
                      opacity: visualProgress,
                      child: Transform.scale(scale: 0.6 + 0.4 * visualProgress, child: indicator),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
