import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/dynamic/domain/entities/workout_feed_item.dart';
import 'package:app_flutter/features/dynamic/domain/workout_feed.dart';
import 'package:app_flutter/features/training/domain/strength.dart';
import 'package:app_flutter/shared/widgets/app_network_image.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 详情里的一个动作：组表 + 相对上次。
class WorkoutExerciseBlock extends StatelessWidget {
  const WorkoutExerciseBlock({super.key, required this.exercise});

  final WorkoutExerciseSummary exercise;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final vs = exercise.vsLast;
    final vsLine = vs == null ? null : formatVsLast(currentVolume: exercise.volume, last: vs);
    final prevTop = vs == null ? null : formatPreviousTopSet(vs);
    final volumeUp = vs != null && exercise.volume - vs.previousVolume > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppNetworkImage(url: exercise.imageUrl, size: 48, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name, style: tt.titleSmall),
                  Text('${exercise.setCount} 组', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  if (vsLine != null)
                    Text(
                      vsLine,
                      style: tt.labelSmall?.copyWith(
                        color: volumeUp ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: volumeUp ? FontWeight.w600 : null,
                      ),
                    ),
                  if (prevTop != null) Text(prevTop, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),

        Visibility(
          visible: exercise.sets.isNotEmpty,
          child: M3ESegmentedColumn(
            margin: EdgeInsets.only(top: 12),
            color: cs.surfaceContainerLowest,
            children: [
              for (final set in exercise.sets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('${set.setNumber}', style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                      ),
                      Expanded(child: Text(formatLoggedSet(set), style: tt.bodyMedium)),
                      if (isHardSet(set.rpe))
                        Container(
                          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.chip)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: Text('有效', style: tt.labelSmall?.copyWith(color: cs.onPrimaryContainer)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
