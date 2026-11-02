import 'package:app_flutter/features/training/application/providers/weekly_volume_provider.dart';
import 'package:app_flutter/features/training/data/repositories/session_repository.dart';
import 'package:app_flutter/features/training/domain/volume_delta.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 近 8 周容量柱状图（含 deload 提示）。
class StatsWeeklyVolumeChart extends ConsumerWidget {
  const StatsWeeklyVolumeChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(weeklyVolumeProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            async.when(
              loading: () => const SizedBox(height: 220, child: Center(child: M3ELoadingIndicator())),
              error: (_, _) => Text('容量加载失败', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              data: (summary) {
                final previous = summary.weeks.length >= 2 ? summary.weeks[summary.weeks.length - 2].volume : null;
                final current = summary.thisWeek?.volume ?? 0;
                final delta = weekVolumeDeltaLabel(
                  weekVolumeDeltaPercent(previousWeek: previous, thisWeek: current),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppShapeIcon(icon: Symbols.bar_chart_rounded, shape: Shapes.circle, iconSize: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('周容量趋势', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              Text(
                                delta == null ? '近 8 周' : '比上周 $delta',
                                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (summary.suggestDeload && summary.deloadReason != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Symbols.health_and_safety_rounded, size: 18, color: cs.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              summary.deloadReason!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: summary.weeks.every((w) => w.volume <= 0)
                          ? Center(child: Text('暂无数据', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)))
                          : _VolumeBars(weeks: summary.weeks),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Color _barColor(ColorScheme cs, List<WeekVolume> weeks, int index) {
  if (weeks[index].volume <= 0) return cs.surfaceContainerHighest;
  final isCurrent = index == weeks.length - 1;
  return isCurrent ? cs.primary : cs.primary.withValues(alpha: 0.4);
}

class _VolumeBars extends StatelessWidget {
  const _VolumeBars({required this.weeks});

  final List<WeekVolume> weeks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxV = weeks.map((w) => w.volume).fold<double>(0, (a, b) => a > b ? a : b);
    final groups = <BarChartGroupData>[
      for (var i = 0; i < weeks.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: weeks[i].volume <= 0 ? 0.01 : weeks[i].volume,
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              color: _barColor(cs, weeks, i),
            ),
          ],
        ),
    ];

    final maxY = maxV <= 0 ? 1.0 : maxV * 1.15;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: groups,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= weeks.length) return const SizedBox.shrink();
                final raw = DateTime.tryParse(weeks[i].weekStart);
                final label = raw == null ? '' : DateFormat('M/d').format(raw);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label, style: Theme.of(context).textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
