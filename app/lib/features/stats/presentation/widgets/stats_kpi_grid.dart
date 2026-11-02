import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/features/stats/domain/entities/stats_overview.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 周期总容量，下面三个小事实：次数、时长、平均 RPE。
class StatsKpiGrid extends StatelessWidget {
  const StatsKpiGrid({super.key, required this.stats});

  final StatsOverview stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final duration = formatSessionDuration(Duration(seconds: stats.totalDurationSeconds));

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stats.periodLabel.isEmpty ? '总容量' : stats.periodLabel,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                M3EContainer(
                  Shapes.circle,
                  width: 44,
                  height: 44,
                  color: cs.primaryContainer,
                  child: Icon(Symbols.monitoring_rounded, color: cs.onPrimaryContainer, size: 22, fill: 1),
                ),
                const SizedBox(width: 12),
                Text(
                  formatCount(stats.totalVolumeKg.round()),
                  style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('kg', style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Fact(icon: Symbols.fitness_center_rounded, value: '${stats.sessionsCount}', label: '训练次数'),
                ),
                Expanded(
                  child: _Fact(icon: Symbols.timer_rounded, value: duration, label: '总时长'),
                ),
                Expanded(
                  child: _Fact(
                    icon: Symbols.speed_rounded,
                    value: stats.avgRpe?.toStringAsFixed(1) ?? '—',
                    label: '平均 RPE',
                    caption: stats.hardSets > 0 ? '有效组 ${stats.hardSets}' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.value, required this.label, this.caption});

  final IconData icon;
  final String value;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        M3EContainer(
          Shapes.circle,
          width: 36,
          height: 36,
          color: cs.primaryContainer,
          child: Icon(icon, color: cs.onPrimaryContainer, size: 18, fill: 1),
        ),
        const SizedBox(height: 6),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        if (caption != null)
          Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}
