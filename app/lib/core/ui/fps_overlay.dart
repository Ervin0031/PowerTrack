import 'dart:collection';

import 'package:app_flutter/core/ui/app_radius.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// 右上角 FPS 浮层，基于 [SchedulerBinding.addTimingsCallback] 采样。
///
/// 仅用于本地性能优化；release / 未开启时不挂载回调，零开销。
class FpsOverlay extends StatefulWidget {
  const FpsOverlay({super.key, required this.child, this.enabled = kDebugMode});

  final Widget child;
  final bool enabled;

  @override
  State<FpsOverlay> createState() => _FpsOverlayState();
}

class _FpsOverlayState extends State<FpsOverlay> {
  static const _sampleSize = 32;

  final ListQueue<double> _frameMs = ListQueue<double>(_sampleSize);
  double _fps = 0;
  double _frameMsAvg = 0;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _syncListener();
  }

  @override
  void didUpdateWidget(covariant FpsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _syncListener();
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _syncListener() {
    if (widget.enabled) {
      _addListener();
    } else {
      _removeListener();
    }
  }

  void _addListener() {
    if (_listening) return;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _listening = true;
  }

  void _removeListener() {
    if (!_listening) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _listening = false;
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted || !widget.enabled) return;

    for (final timing in timings) {
      final ms = timing.totalSpan.inMicroseconds / 1000.0;
      if (ms <= 0) continue;
      _frameMs.addLast(ms);
      while (_frameMs.length > _sampleSize) {
        _frameMs.removeFirst();
      }
    }
    if (_frameMs.isEmpty) return;

    final avg = _frameMs.reduce((a, b) => a + b) / _frameMs.length;
    final fps = 1000.0 / avg;
    // 避免每帧 setState；数值变化够大再刷。
    if ((fps - _fps).abs() < 0.8 && (avg - _frameMsAvg).abs() < 0.3) return;

    setState(() {
      _fps = fps;
      _frameMsAvg = avg;
    });
  }

  Color get _badgeColor {
    if (_fps >= 55) return const Color(0xFF2E7D32);
    if (_fps >= 40) return const Color(0xFFF9A825);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _badgeColor.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '${_fps.toStringAsFixed(0)} FPS\n${_frameMsAvg.toStringAsFixed(1)} ms',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
