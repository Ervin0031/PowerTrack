import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/training/application/providers/exercise_stats_provider.dart';
import 'package:app_flutter/features/training/domain/entities/one_rm.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/domain/strength.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 动作「数据」Tab 的估算 1RM 卡片：当前值 + 建议校准提示 + 历史曲线。
class ExerciseOneRmCard extends ConsumerWidget {
  const ExerciseOneRmCard({super.key, required this.exerciseId, this.weightUnit = 'kg'});

  final int exerciseId;
  final String weightUnit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final unit = weightUnitLabel(weightUnit);
    final estimate = ref.watch(exerciseOneRmProvider(exerciseId));
    final history = ref.watch(exerciseOneRmHistoryProvider(exerciseId));

    return M3ESegmentedColumn(
      outerRadius: AppRadius.card,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('估算 1RM', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text('融合历史组的表现推算单次极限', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (estimate.value case final value?)
                  Text(
                    '${formatWeight(value.estimatedKg, unit: weightUnit)}$unit',
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (estimate.value case final value?) ...[
              Text(
                value.samplesCount > 0 ? '基于 ${value.samplesCount} 组样本' : '样本较少，仅供参考',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (value.needsRecalibrate) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Symbols.error_rounded, size: 16, color: cs.tertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('近期表现与估算偏离，建议做一组大重量重新校准', style: tt.labelSmall?.copyWith(color: cs.tertiary)),
                    ),
                  ],
                ),
              ],
            ] else
              Text(
                estimate.hasError ? '1RM 加载失败' : '暂无估算，记录几组带重量的训练后出现',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: _OneRmLineChart(points: history.value ?? const [], weightUnit: weightUnit),
            ),
          ],
        ),
      ],
    );
  }
}

/// 1RM 走势折线。样本点少（≤ 几十），x 轴直接按序号等距排布。
class _OneRmLineChart extends StatelessWidget {
  const _OneRmLineChart({required this.points, required this.weightUnit});

  final List<OneRmPoint> points;
  final String weightUnit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (points.length < 2) {
      return Center(
        child: Text(
          '历史样本不足，无法绘制曲线',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    final spots = [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].estimatedKg)];
    final values = spots.map((s) => s.y);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxV - minV).abs() < 1 ? maxV * 0.1 : (maxV - minV) * 0.25).clamp(1.0, 40.0).toDouble();
    final minY = (minV - pad).clamp(0, minV).toDouble();
    final maxY = maxV + pad;
    final yInterval = ((maxY - minY) / 3).clamp(0.5, 200).toDouble();
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: minY + 4,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: yInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                space: 12,
                child: Text(formatWeight(value, unit: weightUnit), style: labelStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (points.length / 3).clamp(1, 100).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.round().clamp(0, points.length - 1);
                final d = points[i].date.toLocal();
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text('${d.month}/${d.day}', style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            fitInsideHorizontally: true,
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${_mdLabel(points[spot.x.round().clamp(0, points.length - 1)].date)}\n'
                  '${formatWeight(spot.y, unit: weightUnit)}${weightUnitLabel(weightUnit)}',
                  TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w600, fontSize: 12),
                ),
            ],
          ),
        ),

        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: cs.tertiary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: cs.tertiary,
                strokeWidth: 2,
                strokeColor: cs.surfaceContainerLowest,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _mdLabel(DateTime date) {
    final d = date.toLocal();
    return '${d.month}月${d.day}日';
  }
}
