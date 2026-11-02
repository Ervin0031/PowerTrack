import 'package:material_ui/material_ui.dart';
import 'package:heroine/heroine.dart';
import 'package:motor/motor.dart';

/// 仅响应屏幕边缘拖动的 DragDismissable。
///
/// 与 [DragDismissable] 不同，本 widget 只在手势起始于屏幕边缘的窄条内时才
/// 进入拖拽解散流程，因此不会与页面内部的 [ListView]、横向滑动卡片等滚动
/// 组件争夺垂直/水平手势。
///
/// 边缘区域由 [edgeInsets] 控制，默认覆盖：
/// - 左侧 24px
/// - 右侧 24px
/// - 底部 24px
/// - 顶部 120px（足以覆盖 AppBar，保留现有的“按住 AppBar 下拉返回”体验）
///
/// 拖拽时同样会通过 [HeroinePageRoute.updateDismiss] 更新解散进度，因此
/// [ReactToHeroineDismiss] 的缩放/圆角/阴影效果会继续生效。
class EdgeDragDismissable extends StatefulWidget {
  const EdgeDragDismissable({
    super.key,
    required this.child,
    this.edgeInsets = const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 120),
    this.threshold = DragDismissable.defaultDismissThreshold,
    this.velocityThreshold = DragDismissable.defaultVelocityThreshold,
    this.motion = const CupertinoMotion.interactive(),
  });

  final Widget child;

  /// 触发边缘拖拽的各边宽度/高度。
  final EdgeInsets edgeInsets;

  /// 拖拽距离超过此阈值时触发返回。
  final double threshold;

  /// 拖拽速度超过此阈值时触发返回。
  final double velocityThreshold;

  /// 取消拖拽后回弹的动画效果。
  final Motion motion;

  @override
  State<EdgeDragDismissable> createState() => _EdgeDragDismissableState();
}

class _EdgeDragDismissableState extends State<EdgeDragDismissable> {
  Offset? _dragStartOffset;
  Axis? _dragAxis;
  Offset _offset = Offset.zero;
  Velocity _velocity = Velocity.zero;

  double get progress => _offset.distance / widget.threshold;

  VoidCallback get onDismiss =>
      () => Navigator.maybePop(context);

  void _start(Axis axis, DragStartDetails details) {
    HeroinePageRoute.maybeOf<dynamic>(context)?.updateDismiss(0, Offset.zero);
    setState(() {
      _dragAxis = axis;
      _dragStartOffset = details.globalPosition;
    });
  }

  void _update(DragUpdateDetails details) {
    if (_dragStartOffset case final startOffset?) {
      switch (_dragAxis) {
        case Axis.horizontal:
          _offset = Offset(details.globalPosition.dx - startOffset.dx, 0);
        case Axis.vertical:
          _offset = Offset(0, details.globalPosition.dy - startOffset.dy);
        case null:
          _offset = details.globalPosition - startOffset;
      }
      HeroinePageRoute.maybeOf<dynamic>(context)?.updateDismiss(progress.clamp(0, 1), _offset);
      setState(() {});
    }
  }

  void _cancel() {
    HeroinePageRoute.maybeOf<dynamic>(context)?.cancelDismiss();
    setState(() {
      _dragStartOffset = null;
      _dragAxis = null;
      _offset = Offset.zero;
    });
  }

  void _end(DragEndDetails details) {
    if (ModalRoute.of(context)?.popDisposition == RoutePopDisposition.doNotPop) {
      _cancel();
      return;
    }

    final velocity = details.velocity.pixelsPerSecond.distance;
    if (progress >= 1 || velocity > widget.velocityThreshold) {
      setState(() {
        _velocity = details.velocity;
        _dragStartOffset = null;
        _dragAxis = null;
      });
      onDismiss();
    } else {
      _cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            MotionBuilder(
              active: _dragStartOffset == null,
              motion: widget.motion,
              converter: const OffsetMotionConverter(),
              value: _offset,
              builder: (context, value, child) {
                return Transform.translate(offset: value, child: child);
              },
              child: HeroineVelocity(velocity: _velocity, child: widget.child),
            ),
            // 左侧边缘
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: widget.edgeInsets.left,
              child: _EdgeDragStrip(
                axis: Axis.horizontal,
                onStart: (details) => _start(Axis.horizontal, details),
                onUpdate: _update,
                onEnd: _end,
                onCancel: _cancel,
              ),
            ),
            // 右侧边缘
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: widget.edgeInsets.right,
              child: _EdgeDragStrip(
                axis: Axis.horizontal,
                onStart: (details) => _start(Axis.horizontal, details),
                onUpdate: _update,
                onEnd: _end,
                onCancel: _cancel,
              ),
            ),
            // 顶部边缘（覆盖 AppBar，保留下拉返回）
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: widget.edgeInsets.top,
              child: _EdgeDragStrip(
                axis: Axis.vertical,
                onStart: (details) => _start(Axis.vertical, details),
                onUpdate: _update,
                onEnd: _end,
                onCancel: _cancel,
              ),
            ),
            // 底部边缘
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: widget.edgeInsets.bottom,
              child: _EdgeDragStrip(
                axis: Axis.vertical,
                onStart: (details) => _start(Axis.vertical, details),
                onUpdate: _update,
                onEnd: _end,
                onCancel: _cancel,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EdgeDragStrip extends StatelessWidget {
  const _EdgeDragStrip({
    required this.axis,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  final Axis axis;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final GestureDragCancelCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: axis == Axis.horizontal ? onStart : null,
      onHorizontalDragUpdate: axis == Axis.horizontal ? onUpdate : null,
      onHorizontalDragEnd: axis == Axis.horizontal ? onEnd : null,
      onHorizontalDragCancel: axis == Axis.horizontal ? onCancel : null,
      onVerticalDragStart: axis == Axis.vertical ? onStart : null,
      onVerticalDragUpdate: axis == Axis.vertical ? onUpdate : null,
      onVerticalDragEnd: axis == Axis.vertical ? onEnd : null,
      onVerticalDragCancel: axis == Axis.vertical ? onCancel : null,
      child: const SizedBox.expand(),
    );
  }
}
