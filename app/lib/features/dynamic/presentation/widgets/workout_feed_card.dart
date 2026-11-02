import 'package:app_flutter/features/dynamic/domain/entities/workout_feed_item.dart';
import 'package:app_flutter/features/dynamic/domain/workout_feed.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_anatomy.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_legend.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_stat_strip.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 动态流里的一次训练：零阴影 Card + 形状指标，贴合训练首页。
class WorkoutFeedCard extends StatelessWidget {
  const WorkoutFeedCard({
    super.key,
    required this.item,
    required this.username,
    required this.female,
    this.onTap,
    this.footer,
  });

  final WorkoutFeedItem item;
  final String username;
  final bool female;
  final VoidCallback? onTap;

  /// 卡片底部的附加区（关注流的点赞/评论操作行）；普通训练流不传。
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  M3EContainer.puffy(
                    width: 44,
                    height: 40,
                    color: cs.primaryContainer,
                    child: Center(
                      child: Text(
                        username.isEmpty ? '?' : username.substring(0, 1),
                        style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username, style: tt.titleMedium),
                        Text(
                          formatFeedTimestamp(item.startedAt),
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 16),
              Text(item.title, style: tt.titleMedium),
              const SizedBox(height: 16),
              WorkoutStatStrip(duration: item.duration, volumeKg: item.volumeKg, kcal: item.estimatedKcal),
              if (item.hasIntensity) ...[
                const SizedBox(height: 12),
                Text(
                  formatIntensityLine(hardSets: item.hardSetCount, averageRpe: item.averageRpe),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              if (item.highlights.isNotEmpty) ...[
                const SizedBox(height: 16),
                M3ESegmentedColumn(
                  color: cs.tertiaryContainer,
                  children: [
                    for (final ex in item.highlights)
                      Row(
                        children: [
                          Icon(Symbols.trophy_rounded, size: 20, color: cs.onTertiaryContainer, fill: 1),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(ex.name, style: tt.bodyMedium?.copyWith(color: cs.onTertiaryContainer)),
                          ),
                          Text(
                            '${ex.maxWeightKg!.round()} kg',
                            style: tt.titleSmall?.copyWith(color: cs.onTertiaryContainer),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
              if (item.primaryMuscles.isNotEmpty || item.secondaryMuscles.isNotEmpty) ...[
                const SizedBox(height: 16),
                WorkoutMuscleLegend(primary: item.primaryMuscles, secondary: item.secondaryMuscles),
                const SizedBox(height: 12),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: WorkoutMuscleAnatomy(
                      female: female,
                      primary: item.primaryMuscles,
                      secondary: item.secondaryMuscles,
                      height: 176,
                    ),
                  ),
                ),
              ],
              if (footer != null) ...[const SizedBox(height: 8), footer!],
            ],
          ),
        ),
      ),
    );
  }
}
