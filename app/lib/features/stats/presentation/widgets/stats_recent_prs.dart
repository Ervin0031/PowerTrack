import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/features/stats/domain/entities/stats_overview.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_stats_page.dart';
import 'package:app_flutter/features/stats/presentation/widgets/exercise_thumb.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 周期内新破的最大重量 PR 列表。
class StatsRecentPrs extends StatelessWidget {
  const StatsRecentPrs({super.key, required this.prs});

  final List<StatsRecentPr> prs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dateFmt = DateFormat('M/d');

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
                color: cs.tertiaryContainer,
                child: Icon(Symbols.trophy_rounded, size: 18, color: cs.onTertiaryContainer, fill: 1),
              ),
              const SizedBox(width: 10),
              Text('近期个人纪录', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        M3ESegmentedColumn(
          color: cs.surfaceContainer,
          onTap: (index) {
            final pr = prs[index];
            context.push(
              AppRoutes.exerciseStatsOf(pr.exerciseId),
              extra: ExerciseStatsArgs(name: pr.name),
            );
          },
          children: [
            for (final pr in prs)
              Row(
                children: [
                  ExerciseThumb(exerciseId: pr.exerciseId, fallback: Symbols.emoji_events_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pr.name, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          '${pr.kindLabel} · ${dateFmt.format(pr.at.toLocal())}',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${pr.value % 1 == 0 ? pr.value.toInt() : pr.value} kg',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
