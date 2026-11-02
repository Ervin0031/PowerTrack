import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/features/stats/domain/entities/stats_overview.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_stats_page.dart';
import 'package:app_flutter/features/stats/presentation/widgets/exercise_thumb.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 周期内常练动作（按容量排序）。
class StatsTopExercises extends StatelessWidget {
  const StatsTopExercises({super.key, required this.items});

  final List<StatsTopExercise> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              M3EContainer(
                Shapes.circle,
                width: 32,
                height: 32,
                color: cs.primaryContainer,
                child: Icon(Symbols.fitness_center_rounded, size: 18, color: cs.onPrimaryContainer, fill: 1),
              ),
              const SizedBox(width: 10),
              Text('常练动作', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        M3ESegmentedColumn(
          color: cs.surfaceContainer,
          onTap: (index) {
            final item = items[index];
            context.push(
              AppRoutes.exerciseStatsOf(item.exerciseId),
              extra: ExerciseStatsArgs(name: item.name),
            );
          },
          children: [
            for (var i = 0; i < items.length; i++)
              Row(
                children: [
                  ExerciseThumb(exerciseId: items[i].exerciseId, fallback: Symbols.fitness_center_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].name, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          '${items[i].sessions} 次 · ${formatCount(items[i].volume.round())} kg',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (items[i].estimated1rmKg case final rm?)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('${rm.round()} kg', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
