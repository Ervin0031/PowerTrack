import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 弹出 RPE 收集面板；确认返回 0.5–10.0，取消/下拉返回 null。
Future<double?> showRpeCollectSheet(BuildContext context, {double initial = 8.0}) {
  return showM3EModalBottomSheet<double>(
    context: context,
    builder: (_) => RpeCollectSheet(initial: normalizeRpe(initial)),
  );
}

/// 完成本组后的 RPE 滑块：6.0–10.0，0.5 步进。
class RpeCollectSheet extends StatefulWidget {
  const RpeCollectSheet({super.key, this.initial = 8.0});

  final double initial;

  @override
  State<RpeCollectSheet> createState() => _RpeCollectSheetState();
}

class _RpeCollectSheetState extends State<RpeCollectSheet> {
  static const _min = 6.0;
  static const _max = 10.0;
  late double _rpe;

  @override
  void initState() {
    super.initState();
    _rpe = normalizeRpe(widget.initial.clamp(_min, _max));
  }

  Color _zoneColor(ColorScheme cs) {
    if (_rpe >= kRpeFailure) return cs.error;
    if (_rpe >= kRpeRedZone) return Color.lerp(cs.error, cs.primary, 0.25)!;
    if (_rpe >= kRpeSweetMin) return cs.primary;
    return cs.tertiary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zone = _zoneColor(cs);
    return M3EBottomSheet(
      title: const Text('这组感觉如何？'),
      padding: EdgeInsets.zero,
      actions: [
        M3EButton(
          style: M3EButtonStyle.filled,
          size: M3EButtonSize.sm,
          onPressed: () => Navigator.pop(context, _rpe),
          child: const Text('确认'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatRpe(_rpe),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: zone,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(rpeZoneLabel(_rpe), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: zone)),
            const SizedBox(height: 12),

            M3ESlider(
              min: _min,
              max: _max,
              divisions: 8,
              label: formatRpe(_rpe),
              value: _rpe,
              onChanged: (v) => setState(() => _rpe = normalizeRpe(v)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('轻松', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.outline)),
                  const Spacer(),
                  Icon(Symbols.favorite_rounded, size: 14, color: cs.primary.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  Text('甜蜜区', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.primary)),
                  const Spacer(),
                  Text('力竭', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
