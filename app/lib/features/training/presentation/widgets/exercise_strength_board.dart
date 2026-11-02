import 'package:app_flutter/features/training/domain/entities/exercise_stats.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/domain/strength.dart';
import 'package:app_flutter/features/training/domain/strength_window.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 动作力量：两列变化（重量 / PR）、重量容量次数三张图、按日重量。
class ExerciseStrengthBoard extends StatefulWidget {
  const ExerciseStrengthBoard({
    super.key,
    required this.stats,
    required this.weightUnit,
  });

  final ExerciseStats stats;
  final String weightUnit;

  @override
  State<ExerciseStrengthBoard> createState() => _ExerciseStrengthBoardState();
}

class _ExerciseStrengthBoardState extends State<ExerciseStrengthBoard> {
  _Range _range = _Range.month;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final weight = strengthWindow(
      points: widget.stats.maxWeight.points,
      now: now,
      days: _range.days,
    );
    final volume = strengthWindow(
      points: widget.stats.totalVolume.points,
      now: now,
      days: _range.days,
    );
    final reps = strengthWindow(
      points: widget.stats.maxReps.points,
      now: now,
      days: _range.days,
    );
    final record = weightRecord(widget.stats.maxWeight.points);
    final records = widget.stats.records;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        32,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ChangeColumn(
                title: '重量变化',
                rows: [
                  _ChangeRow(
                    label: '最近一次',
                    value: weight.last == null
                        ? '—'
                        : '${formatWeight(weight.last!.value, unit: widget.weightUnit)} ${weightUnitLabel(widget.weightUnit)}',
                    delta: _changeText(
                      weight.sessionDelta,
                      weight.sessionPercent,
                      widget.weightUnit,
                    ),
                    up: weight.sessionDelta == null
                        ? null
                        : weight.sessionDelta! >= 0,
                  ),
                  _ChangeRow(
                    label: '区间',
                    value: weight.rangeDelta == null
                        ? '—'
                        : '${_signedWeight(weight.rangeDelta!, widget.weightUnit)} ${weightUnitLabel(widget.weightUnit)}',
                    delta: _signedPercent(weight.rangePercent),
                    up: weight.rangeDelta == null
                        ? null
                        : weight.rangeDelta! >= 0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ChangeColumn(
                title: 'PR',
                rows: [
                  _ChangeRow(
                    label: '重量纪录',
                    value: (record.best ?? records.maxWeightKg) == null
                        ? '—'
                        : '${formatWeight((record.best ?? records.maxWeightKg)!, unit: widget.weightUnit)} ${weightUnitLabel(widget.weightUnit)}',
                    delta: record.delta == null
                        ? null
                        : '较前纪录 ${_signedWeight(record.delta!, widget.weightUnit)}',
                    up: record.delta == null ? null : record.delta! >= 0,
                  ),
                  _ChangeRow(
                    label: '次数纪录',
                    value: records.maxReps == null
                        ? '—'
                        : '${records.maxReps} 次',
                    delta: null,
                    up: null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _Range.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final range = _Range.values[index];
              final selected = range == _range;
              return TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: selected
                      ? cs.surfaceContainerHighest
                      : Colors.transparent,
                  foregroundColor: selected
                      ? cs.onSurface
                      : cs.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() => _range = range),
                child: Text(
                  range.label,
                  style: tt.labelLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        _SeriesChart(
          title: '最大重量',
          samples: weight.samples,
          color: _seriesColor(cs, weight.rangeDelta),
          weightUnit: widget.weightUnit,
          formatY: (value) => formatWeight(value, unit: widget.weightUnit),
        ),
        const SizedBox(height: 20),
        _SeriesChart(
          title: '容量',
          samples: volume.samples,
          color: _seriesColor(cs, volume.rangeDelta),
          weightUnit: widget.weightUnit,
          formatY: (value) => value >= 100
              ? value.round().toString()
              : value.toStringAsFixed(0),
        ),
        const SizedBox(height: 20),
        _SeriesChart(
          title: '次数',
          samples: reps.samples,
          color: _seriesColor(cs, reps.rangeDelta),
          weightUnit: widget.weightUnit,
          formatY: (value) => value.round().toString(),
          integerTooltip: true,
        ),
        const SizedBox(height: 28),
        Text('每日力量', style: tt.titleMedium),
        const SizedBox(height: 12),
        _MonthBar(
          month: _month,
          onPrevious: () =>
              setState(() => _month = DateTime(_month.year, _month.month - 1)),
          onNext: () =>
              setState(() => _month = DateTime(_month.year, _month.month + 1)),
        ),
        const SizedBox(height: 12),
        _DayGrid(
          month: _month,
          history: widget.stats.history,
          weightUnit: widget.weightUnit,
        ),
      ],
    );
  }
}

enum _Range {
  week(7, '1 周'),
  twoWeeks(14, '2 周'),
  month(30, '1 个月'),
  quarter(90, '3 个月'),
  halfYear(180, '6 个月');

  const _Range(this.days, this.label);
  final int days;
  final String label;
}

class _ChangeRow {
  const _ChangeRow({
    required this.label,
    required this.value,
    required this.delta,
    required this.up,
  });

  final String label;
  final String value;
  final String? delta;
  final bool? up;
}

class _ChangeColumn extends StatelessWidget {
  const _ChangeColumn({required this.title, required this.rows});

  final String title;
  final List<_ChangeRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tt.titleMedium),
        for (final row in rows) ...[
          const SizedBox(height: 12),
          Text(
            row.label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            row.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (row.delta != null)
            Text(
              row.delta!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelLarge?.copyWith(
                color: row.up == null
                    ? cs.onSurfaceVariant
                    : (row.up! ? cs.primary : cs.error),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ],
    );
  }
}

class _SeriesChart extends StatelessWidget {
  const _SeriesChart({
    required this.title,
    required this.samples,
    required this.color,
    required this.weightUnit,
    required this.formatY,
    this.integerTooltip = false,
  });

  final String title;
  final List<StatsPoint> samples;
  final Color color;
  final String weightUnit;
  final String Function(double value) formatY;
  final bool integerTooltip;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tt.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: samples.isEmpty
              ? const _EmptyHint(
                  icon: Symbols.monitoring_rounded,
                  text: '这个区间没有数据',
                )
              : _PaddedLineChart(
                  samples: samples,
                  color: color,
                  weightUnit: weightUnit,
                  formatY: formatY,
                  integerTooltip: integerTooltip,
                ),
        ),
      ],
    );
  }
}

class _PaddedLineChart extends StatelessWidget {
  const _PaddedLineChart({
    required this.samples,
    required this.color,
    required this.weightUnit,
    required this.formatY,
    required this.integerTooltip,
  });

  final List<StatsPoint> samples;
  final Color color;
  final String weightUnit;
  final String Function(double value) formatY;
  final bool integerTooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant);
    final origin = DateTime(
      samples.first.at.year,
      samples.first.at.month,
      samples.first.at.day,
    );
    final spots = [
      for (final point in samples)
        FlSpot(point.at.difference(origin).inDays.toDouble(), point.value),
    ];
    final firstX = spots.first.x;
    final lastX = spots.last.x;
    final spanX = lastX <= firstX ? 1.0 : lastX - firstX;
    final minX = firstX - spanX * 0.08;
    final maxX = lastX + spanX * 0.14;
    var minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    var maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    final spanY = maxY - minY;
    final padY = spanY < 1 ? (maxY * 0.08).clamp(1.0, 8.0) : spanY * 0.22;
    minY = (minY - padY).clamp(0, minY).toDouble();
    maxY += padY;
    final yInterval = _axisStep(maxY - minY);

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.55),
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yInterval,
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (value, meta) {
                if (value < minY + yInterval * 0.35 ||
                    value > maxY - yInterval * 0.35) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(formatY(value), style: labelStyle),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (spanX / 2).clamp(1, 60),
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (value, meta) {
                if (value < minX + spanX * 0.08 ||
                    value > maxX - spanX * 0.12) {
                  return const SizedBox.shrink();
                }
                final day = origin.add(Duration(days: value.round()));
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
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  _tooltip(origin, spot, integerTooltip, weightUnit),
                  TextStyle(
                    color: cs.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 2.2,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            dotData: FlDotData(
              show: spots.length <= 16,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: 3.5, color: color, strokeWidth: 0),
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '上个月',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${month.year}年${month.month}月',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        IconButton(
          tooltip: '下个月',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.month,
    required this.history,
    required this.weightUnit,
  });

  final DateTime month;
  final List<ExerciseHistorySession> history;
  final String weightUnit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final weights = _dailyMax(history);
    final first = DateTime(month.year, month.month, 1);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = leading + count;

    return Column(
      children: [
        Row(
          children: [
            for (final name in const ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Center(
                  child: Text(
                    name,
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final day = index - leading + 1;
            if (day < 1 || day > count) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, day);
            final kg = weights[date];
            return DecoratedBox(
              decoration: BoxDecoration(
                color: kg == null
                    ? cs.surfaceContainerLow
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day', style: tt.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      kg == null ? '—' : formatWeight(kg, unit: weightUnit),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        color: kg == null ? cs.onSurfaceVariant : cs.onSurface,
                        fontWeight: kg == null ? null : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: cs.outline),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

Map<DateTime, double> _dailyMax(List<ExerciseHistorySession> history) {
  final weights = <DateTime, double>{};
  for (final session in history) {
    final local = session.startedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    for (final set in session.sets) {
      final kg = set.weightKg;
      if (kg == null || kg <= 0) continue;
      final current = weights[day];
      if (current == null || kg > current) weights[day] = kg;
    }
  }
  return weights;
}

double _axisStep(double span) {
  if (span <= 5) return 1;
  if (span <= 12) return 2;
  if (span <= 30) return 5;
  if (span <= 80) return 10;
  if (span <= 200) return 20;
  if (span <= 500) return 50;
  return (span / 4).ceilToDouble();
}

Color _seriesColor(ColorScheme cs, double? delta) {
  if (delta == null || delta >= 0) return cs.primary;
  return cs.error;
}

String? _changeText(double? kg, double? percent, String unit) {
  if (kg == null) return null;
  return '${_signedWeight(kg, unit)} ${weightUnitLabel(unit)} · ${_signedPercent(percent)}';
}

String _signedPercent(double? value) {
  if (value == null) return '—';
  final rounded = (value * 10).roundToDouble() / 10;
  final body = rounded == rounded.roundToDouble()
      ? rounded.abs().round().toString()
      : rounded.abs().toStringAsFixed(1);
  if (rounded > 0) return '+$body%';
  if (rounded < 0) return '-$body%';
  return '0%';
}

String _signedWeight(double kg, String unit) {
  final body = formatWeight(kg.abs(), unit: unit);
  if (kg > 0) return '+$body';
  if (kg < 0) return '-$body';
  return body;
}

String _tooltip(
  DateTime origin,
  LineBarSpot spot,
  bool integer,
  String weightUnit,
) {
  final day = origin.add(Duration(days: spot.x.round()));
  final unit = weightUnitLabel(weightUnit);
  final value = integer
      ? spot.y.round().toString()
      : '${formatWeight(spot.y, unit: weightUnit)}$unit';
  return '${day.month}月${day.day}日\n$value';
}
