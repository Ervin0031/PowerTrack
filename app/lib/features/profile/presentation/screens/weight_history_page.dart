import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/profile/domain/entities/weight_history.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 体重趋势：体重流水 + 7 日移动平均 + 窗口变化量。
///
/// 体重只在档案值变化时写入，点稀疏属正常；与 e1RM 曲线对照可判断增肌/减脂质量。
class WeightHistoryPage extends ConsumerStatefulWidget {
  const WeightHistoryPage({super.key});

  @override
  ConsumerState<WeightHistoryPage> createState() => _WeightHistoryPageState();
}

class _WeightHistoryPageState extends ConsumerState<WeightHistoryPage> {
  static const _windows = <(int, String)>[(30, '30 天'), (90, '3 个月'), (365, '1 年')];

  int _days = 90;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(weightHistoryProvider(_days));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('体重趋势')),
      body: ListView(
        padding: const EdgeInsets.all(16).add(EdgeInsets.only(top: context.appBarInset)),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SegmentedButton<int>(
            segments: [for (final (days, label) in _windows) ButtonSegment(value: days, label: Text(label))],
            selected: {_days},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => setState(() => _days = selection.first),
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(80),
              child: Center(child: M3ELoadingIndicator()),
            ),
            error: (error, _) =>
                AppErrorState(error: error, onRetry: () => ref.invalidate(weightHistoryProvider(_days))),
            data: (history) => history.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: AppEmptyState(
                      icon: Symbols.monitor_weight_rounded,
                      title: '还没有体重记录',
                      message: '在健身档案里更新体重，这里就会出现趋势',
                      tint: AppTint.secondary,
                    ),
                  )
                : _Body(history: history, onEditProfile: () => context.push(AppRoutes.fitnessProfile)),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.history, required this.onEditProfile});

  final WeightHistory history;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final change = history.changeKg;
    final changeColor = change == null || change == 0 ? cs.onSurfaceVariant : (change < 0 ? cs.tertiary : cs.error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('近 ${history.periodDays} 天', style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${history.points.last.weightKg.toStringAsFixed(1)} kg',
                      style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        change == null ? '—' : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
                        style: tt.titleSmall?.copyWith(color: changeColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('共 ${history.records} 条记录', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(height: 240, child: _WeightChart(points: history.points)),
        const SizedBox(height: 12),
        Row(
          children: [
            _Legend(color: cs.primary, label: '体重'),
            const SizedBox(width: 16),
            _Legend(color: cs.tertiary, label: '7 日平均'),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: M3EButton(style: M3EButtonStyle.tonal, onPressed: onEditProfile, child: const Text('更新健身档案')),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// 体重折线 + MA7 折线。x 轴按真实日期间隔排布，点稀疏时仍反映时间跨度。
class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.points});

  final List<WeightPoint> points;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (points.isEmpty) return const SizedBox.shrink();

    final start = points.first.date;
    final maxX = points.last.date.difference(start).inDays.clamp(1, 1095).toDouble();
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant);

    final weightSpots = [
      for (final p in points) FlSpot(p.date.difference(start).inDays.toDouble().clamp(0, maxX).toDouble(), p.weightKg),
    ];
    final maSpots = [
      for (final p in points)
        if (p.ma7Kg case final ma?) FlSpot(p.date.difference(start).inDays.toDouble().clamp(0, maxX).toDouble(), ma),
    ];

    final values = [...weightSpots.map((s) => s.y), ...maSpots.map((s) => s.y)];
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxV - minV).abs() < 1 ? maxV * 0.03 : (maxV - minV) * 0.3).clamp(0.5, 10.0).toDouble();
    final minY = minV - pad;
    final maxY = maxV + pad;
    final yInterval = ((maxY - minY) / 3).clamp(0.5, 50).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
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
                space: 6,
                child: Text(value.toStringAsFixed(1), style: labelStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (maxX / 3).clamp(1, 1000).toDouble(),
              getTitlesWidget: (value, meta) {
                final day = start.add(Duration(days: value.round()));
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text('${day.month}/${day.day}', style: labelStyle),
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
                  '${spot.y.toStringAsFixed(1)} kg',
                  TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w600, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: weightSpots,
            isCurved: false,
            color: cs.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: cs.primary,
                strokeWidth: 2,
                strokeColor: cs.surfaceContainerLowest,
              ),
            ),
          ),
          if (maSpots.length > 1)
            LineChartBarData(
              spots: maSpots,
              isCurved: true,
              color: cs.tertiary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}
