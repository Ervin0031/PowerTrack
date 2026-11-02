import 'package:app_flutter/core/ui/format.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 时长 / 容量 / 热量。
class WorkoutStatStrip extends StatelessWidget {
  const WorkoutStatStrip({
    super.key,
    required this.duration,
    required this.volumeKg,
    required this.kcal,
  });

  final Duration? duration;
  final double volumeKg;
  final double? kcal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Stat(
            shape: Shapes.circle,
            icon: Symbols.timer_rounded,
            value: duration == null ? '—' : formatSessionDuration(duration!),
            label: '时长',
          ),
        ),
        Expanded(
          child: _Stat(
            shape: Shapes.bun,
            icon: Symbols.fitness_center_rounded,
            value: '${formatCount(volumeKg.round())} kg',
            label: '容量',
          ),
        ),
        Expanded(
          child: _Stat(
            shape: Shapes.verySunny,
            icon: Symbols.local_fire_department_rounded,
            value: kcal == null ? '—' : formatKcal(kcal!),
            label: '热量',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.shape,
    required this.icon,
    required this.value,
    required this.label,
  });

  final Shapes shape;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        M3EContainer(
          shape,
          width: 48,
          height: 48,
          color: cs.primaryContainer,
          child: Icon(icon, color: cs.onPrimaryContainer, size: 24, fill: 1),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}
