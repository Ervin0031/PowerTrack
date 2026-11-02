import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Apple Intelligence Siri 式边缘光：从底部沿屏幕圆角爬到顶部，随后绕边流动。
class SiriEdgeGlow extends StatefulWidget {
  const SiriEdgeGlow({super.key, required this.active, this.onCompleted});

  final bool active;
  final VoidCallback? onCompleted;

  @override
  State<SiriEdgeGlow> createState() => _SiriEdgeGlowState();
}

class _SiriEdgeGlowState extends State<SiriEdgeGlow>
    with TickerProviderStateMixin {
  static const _revealDuration = Duration(milliseconds: 900);
  static const _fadeDuration = Duration(milliseconds: 420);

  late final AnimationController _reveal;
  late final AnimationController _flow;
  late final AnimationController _pulse;
  late final AnimationController _fade;
  int _cycle = 0;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: _revealDuration);
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _fade = AnimationController(vsync: this, duration: _fadeDuration);
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) _start();
      });
    }
  }

  @override
  void didUpdateWidget(SiriEdgeGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _start();
    } else if (!widget.active && oldWidget.active) {
      _fade.reverse();
      _flow.stop();
      _pulse.stop();
    }
  }

  Future<void> _start() async {
    final token = ++_cycle;
    _reveal
      ..stop()
      ..value = 0;
    _fade.forward(from: 0);
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
    _flow.repeat();
    _pulse.repeat(reverse: true);
    if (reduce) return;
    while (mounted && token == _cycle && widget.active) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  void dispose() {
    _cycle++;
    _reveal.dispose();
    _flow.dispose();
    _pulse.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active && _fade.value <= 0) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final radius = _displayCornerRadius(size);
    return IgnorePointer(
      child: SizedBox.expand(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_reveal, _flow, _pulse, _fade]),
            builder: (context, _) {
              if (_fade.value <= 0) return const SizedBox.shrink();
              return CustomPaint(
                painter: _SiriEdgeGlowPainter(
                  progress: Curves.easeOutCubic.transform(_reveal.value),
                  flow: _flow.value,
                  pulse: 0.72 + 0.28 * _pulse.value,
                  opacity: _fade.value,
                  cornerRadius: radius,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
  }
}

double _displayCornerRadius(Size size) {
  if (size.shortestSide >= 600) return 28;
  return (size.shortestSide * 0.12).clamp(40.0, 56.0);
}

/// [Path.computeMetrics] 是一次性迭代器：先读 `isEmpty` 再读 `first` 会抛 No element。
ui.PathMetric? firstPathMetric(Path path) {
  final iterator = path.computeMetrics().iterator;
  if (!iterator.moveNext()) return null;
  return iterator.current;
}

class _SiriEdgeGlowPainter extends CustomPainter {
  _SiriEdgeGlowPainter({
    required this.progress,
    required this.flow,
    required this.pulse,
    required this.opacity,
    required this.cornerRadius,
  });

  final double progress;
  final double flow;
  final double pulse;
  final double opacity;
  final double cornerRadius;

  static const _colors = [
    Color(0xFF38BDF8),
    Color(0xFF818CF8),
    Color(0xFFE879F9),
    Color(0xFFFB7185),
    Color(0xFFFDBA74),
    Color(0xFF22D3EE),
    Color(0xFF38BDF8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || size.width < 8 || size.height < 8) return;
    const inset = 8.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    if (rect.width <= 0 || rect.height <= 0) return;
    final radius = math.min(cornerRadius, rect.shortestSide / 2);
    final loop = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final metric = firstPathMetric(loop);
    if (metric == null || metric.length <= 0) return;

    final total = metric.length;
    final bottomCenter = Offset(size.width / 2, size.height - inset);
    final bottom = _offsetNearest(metric, bottomCenter, total);
    final shown = progress.clamp(0.0, 1.0) * total;
    if (shown <= 0) {
      canvas.saveLayer(
        (Offset.zero & size).inflate(48),
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity)
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      );
      _drawBloom(canvas, bottomCenter);
      canvas.restore();
      return;
    }

    final start = bottom - shown / 2;
    final band = _extractWrapped(metric, start, shown);
    final ribbon = _innerWaveRibbon(metric, start, shown, size);
    final shader = SweepGradient(
      colors: _colors,
      transform: GradientRotation(flow * math.pi * 2 - math.pi / 2),
    ).createShader(rect.inflate(32));

    canvas.saveLayer(
      (Offset.zero & size).inflate(48),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
    );
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18 * pulse
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = shader,
    );
    if (ribbon != null) {
      canvas.drawPath(ribbon, Paint()..shader = shader);
    }
    if (progress < 0.98) {
      _drawTips(canvas, metric, total, bottom, shown / 2);
    }
    _drawBloom(canvas, bottomCenter);
    canvas.restore();
  }

  Path? _innerWaveRibbon(
    ui.PathMetric metric,
    double start,
    double length,
    Size size,
  ) {
    if (length <= 0) return null;
    const steps = 96;
    final outer = <Offset>[];
    final inner = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final tangent = metric.getTangentForOffset(
        _wrap(start + length * t, metric.length),
      );
      if (tangent == null) continue;
      final pos = tangent.position;
      final inward = _inward(pos, size);
      final depth = (8 + 22 * _innerWave(t)) * pulse;
      outer.add(pos);
      inner.add(pos + inward * depth);
    }
    if (outer.length < 2) return null;
    final path = Path()..moveTo(outer.first.dx, outer.first.dy);
    for (var i = 1; i < outer.length; i++) {
      path.lineTo(outer[i].dx, outer[i].dy);
    }
    for (var i = inner.length - 1; i >= 0; i--) {
      path.lineTo(inner[i].dx, inner[i].dy);
    }
    path.close();
    return path;
  }

  double _innerWave(double t) {
    final a = math.sin((t * 7.2 + flow * 2.0) * math.pi * 2);
    final b = math.sin((t * 12.6 - flow * 3.3) * math.pi * 2);
    final c = math.sin((t * 3.4 + flow * 1.1) * math.pi * 2);
    final rnd = _hash(t * 19.0 + flow * 11.0);
    return ((0.36 * a + 0.26 * b + 0.18 * c + 0.20 * rnd) + 1) * 0.5;
  }

  double _hash(double x) {
    final n = math.sin(x * 12.9898) * 43758.5453;
    return (n - n.floorToDouble()) * 2 - 1;
  }

  void _drawBloom(Canvas canvas, Offset origin) {
    final bloom = (1.15 - progress).clamp(0.2, 1.15) * pulse;
    canvas.drawCircle(
      origin,
      80 * bloom,
      Paint()
        ..shader = ui.Gradient.radial(
          origin,
          80 * bloom,
          const [Color(0x66FFFFFF), Color(0x55818CF8), Color(0x00FFFFFF)],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  void _drawTips(
    Canvas canvas,
    ui.PathMetric metric,
    double total,
    double bottom,
    double half,
  ) {
    final paint = Paint()..color = const Color(0x55FFFFFF);
    for (final offset in [bottom - half, bottom + half]) {
      final tangent = metric.getTangentForOffset(_wrap(offset, total));
      if (tangent == null) continue;
      canvas.drawCircle(tangent.position, 10 * pulse, paint);
    }
  }

  Path _extractWrapped(ui.PathMetric metric, double start, double length) {
    final total = metric.length;
    if (total <= 0 || length <= 0) return Path();
    final from = _wrap(start, total);
    final to = from + length.clamp(0, total);
    if (to <= total) return metric.extractPath(from, to);
    return Path()
      ..addPath(metric.extractPath(from, total), Offset.zero)
      ..addPath(
        metric.extractPath(0, math.min(to - total, total)),
        Offset.zero,
      );
  }

  Offset _inward(Offset pos, Size size) {
    final v = Offset(size.width / 2 - pos.dx, size.height / 2 - pos.dy);
    final len = v.distance;
    if (len < 1) return Offset.zero;
    return v / len;
  }

  double _offsetNearest(ui.PathMetric metric, Offset target, double total) {
    const steps = 96;
    var best = 0.0;
    var bestDist = double.infinity;
    for (var i = 0; i <= steps; i++) {
      final d = total * i / steps;
      final pos = metric.getTangentForOffset(d)?.position;
      if (pos == null) continue;
      final dist = (pos - target).distanceSquared;
      if (dist < bestDist) {
        bestDist = dist;
        best = d;
      }
    }
    return best;
  }

  double _wrap(double value, double total) {
    if (total <= 0) return 0;
    final mod = value % total;
    return mod < 0 ? mod + total : mod;
  }

  @override
  bool shouldRepaint(covariant _SiriEdgeGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.flow != flow ||
        oldDelegate.pulse != pulse ||
        oldDelegate.opacity != opacity ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}
