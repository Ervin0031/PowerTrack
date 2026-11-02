import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/features/stats/domain/entities/stats_overview.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

const _rankShapes = [Shapes.verySunny, Shapes.bun, Shapes.softBurst, Shapes.circle, Shapes.pill, Shapes.gem];

/// 周期内肌群容量横向条。
class StatsMuscleDistribution extends StatelessWidget {
  const StatsMuscleDistribution({super.key, required this.muscles});

  final List<StatsMuscleVolume> muscles;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (muscles.isEmpty) return const SizedBox.shrink();
    final top = muscles.take(6).toList();
    final maxV = top.first.volume;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('肌群容量分布', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            for (var i = 0; i < top.length; i++) ...[
              _MuscleRow(
                muscle: top[i],
                shape: _rankShapes[i % _rankShapes.length],
                fraction: maxV <= 0 ? 0 : (top[i].volume / maxV).clamp(0.0, 1.0),
                emphasize: i == 0,
              ),
              if (i < top.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  const _MuscleRow({required this.muscle, required this.shape, required this.fraction, required this.emphasize});

  final StatsMuscleVolume muscle;
  final Shapes shape;
  final double fraction;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final label = muscle.name.isEmpty ? '?' : muscle.name.substring(0, 1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        M3EContainer(
          shape,
          width: 36,
          height: 36,
          color: emphasize ? cs.primaryContainer : cs.secondaryContainer,
          child: Text(
            label,
            style: tt.labelLarge?.copyWith(
              color: emphasize ? cs.onPrimaryContainer : cs.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      muscle.name,
                      style: tt.labelLarge?.copyWith(fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${formatCount(muscle.volume.round())} kg',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              M3ELinearProgressIndicator(
                value: fraction,
                color: emphasize ? cs.primary : cs.secondary,
                backgroundColor: cs.surfaceContainerHighest,
                minHeight: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
