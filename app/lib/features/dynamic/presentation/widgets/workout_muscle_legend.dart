import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/dynamic/domain/entities/workout_feed_item.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_anatomy.dart';
import 'package:material_ui/material_ui.dart';

class WorkoutMuscleChip extends StatelessWidget {
  const WorkoutMuscleChip({super.key, required this.label, this.color, this.filled = false});

  final String label;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = filled ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = filled ? cs.onPrimaryContainer : cs.onSurface;
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.field)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

class WorkoutMuscleLegend extends StatelessWidget {
  const WorkoutMuscleLegend({
    super.key,
    required this.primary,
    required this.secondary,
    this.maxPrimary = 3,
    this.maxSecondary = 2,
  });

  final List<WorkoutMuscleHit> primary;
  final List<WorkoutMuscleHit> secondary;
  final int? maxPrimary;
  final int? maxSecondary;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final palette = anatomyPalette(cs);
    final shownPrimary = maxPrimary == null ? primary : primary.take(maxPrimary!).toList();
    final shownSecondary = maxSecondary == null ? secondary : secondary.take(maxSecondary!).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primary.isNotEmpty) ...[
          Text('主要', style: tt.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < shownPrimary.length; i++)
                WorkoutMuscleChip(label: shownPrimary[i].name, filled: true, color: palette[i % palette.length]),
              if (maxPrimary != null && primary.length > maxPrimary!)
                WorkoutMuscleChip(label: '+${primary.length - maxPrimary!}'),
            ],
          ),
        ],
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('次要', style: tt.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < shownSecondary.length; i++)
                WorkoutMuscleChip(
                  label: shownSecondary[i].name,
                  color: palette[(i + 2) % palette.length].withValues(alpha: 0.55),
                ),
              if (maxSecondary != null && secondary.length > maxSecondary!)
                WorkoutMuscleChip(label: '+${secondary.length - maxSecondary!}'),
            ],
          ),
        ],
      ],
    );
  }
}
