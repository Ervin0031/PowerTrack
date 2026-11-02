import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

/// 展开/收起：高度按 [M3EMotion.standardSpatialFast] 弹簧裁切，和 M3E 可展开卡片一致。
///
/// 收起动画结束前保留 [child]，内容是被裁掉的，不是先消失再缩高度。
class M3EExpand extends StatefulWidget {
  const M3EExpand({super.key, required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  State<M3EExpand> createState() => _M3EExpandState();
}

class _M3EExpandState extends State<M3EExpand> {
  bool _keepChild = false;

  @override
  void initState() {
    super.initState();
    _keepChild = widget.expanded;
  }

  @override
  void didUpdateWidget(M3EExpand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded) _keepChild = true;
  }

  void _onStatus(AnimationStatus status) {
    if (widget.expanded || !_keepChild || !mounted) return;
    // 弹簧停在 0 时，起点若不是 0，状态是 completed 而不是 dismissed。
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      setState(() => _keepChild = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      motion: M3EMotion.standardSpatialFast.toMotion(),
      value: widget.expanded ? 1 : 0,
      onAnimationStatusChanged: _onStatus,
      builder: (context, t, child) {
        if (!_keepChild) return const SizedBox.shrink();
        return ClipRect(
          child: Align(alignment: Alignment.topCenter, heightFactor: math.max(0, t), child: child),
        );
      },
      child: _keepChild ? M3ESpringSize(child: widget.child) : const SizedBox.shrink(key: ValueKey('collapsed')),
    );
  }
}

/// 子组件高度变化（追加/删除一组、备注出现）用同一套空间弹簧跟上。
class M3ESpringSize extends StatefulWidget {
  const M3ESpringSize({super.key, required this.child});

  final Widget child;

  @override
  State<M3ESpringSize> createState() => _M3ESpringSizeState();
}

class _M3ESpringSizeState extends State<M3ESpringSize> with SingleTickerProviderStateMixin {
  SingleMotionController? _height;
  double? _goal;

  @override
  void dispose() {
    _height?.dispose();
    super.dispose();
  }

  void _report(double height) {
    if (!mounted) return;
    if (_goal != null && (height - _goal!).abs() < 0.5) return;
    _goal = height;
    final current = _height;
    if (current == null) {
      final controller = SingleMotionController(
        motion: M3EMotion.standardSpatialFast.toMotion(),
        vsync: this,
        initialValue: height,
      )..addListener(_onTick);
      setState(() => _height = controller);
      return;
    }
    current.animateTo(height);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final measured = _MeasureHeight(onChange: _report, child: widget.child);
    final height = _height;
    if (height == null) return measured;
    return ClipRect(
      child: SizedBox(
        width: double.infinity,
        height: math.max(0, height.value),
        child: OverflowBox(alignment: Alignment.topCenter, minHeight: 0, maxHeight: double.infinity, child: measured),
      ),
    );
  }
}

/// 列表项进场/退场：高度弹簧 + 透明度。退场停稳后回调 [onDismissed]。
class M3EMotionReveal extends StatelessWidget {
  const M3EMotionReveal({super.key, required this.show, required this.child, this.appear = false, this.onDismissed});

  final bool show;
  final bool appear;
  final Widget child;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      motion: M3EMotion.standardSpatialFast.toMotion(),
      from: appear ? 0 : null,
      value: show ? 1 : 0,
      onAnimationStatusChanged: (status) {
        if (show) return;
        if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
          onDismissed?.call();
        }
      },
      builder: (context, t, child) {
        final p = math.max(0.0, t);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: p,
            child: Opacity(opacity: p.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: child,
    );
  }
}

class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onChange, required super.child});

  final ValueChanged<double> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasureHeight(onChange);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasureHeight renderObject) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onChange);

  ValueChanged<double> onChange;
  double? _sent;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_sent != null && (height - _sent!).abs() < 0.5) return;
    _sent = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!attached) return;
      onChange(height);
    });
  }
}
