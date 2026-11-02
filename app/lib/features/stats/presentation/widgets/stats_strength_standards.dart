import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/features/stats/application/providers/advanced_stats_providers.dart';
import 'package:app_flutter/features/stats/domain/entities/strength_standards.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_stats_page.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 相对力量与体型对称度：倍体重比、三大项、Dots/Wilks、推拉容量比。
class StatsStrengthStandards extends ConsumerWidget {
  const StatsStrengthStandards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(strengthStandardsProvider);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppShapeIcon(icon: Symbols.balance_rounded, shape: Shapes.circle, iconSize: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('力量标准', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text('倍体重比 · 三大项 · 推拉均衡', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            async.when(
              loading: () => const Align(alignment: Alignment.centerLeft, child: M3ELoadingIndicator()),
              error: (_, _) => Text('力量标准加载失败', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              data: (data) {
                if (!data.hasProfile) {
                  return Text(
                    '完善健身档案（体重/性别）后可见倍体重比与力量系数',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  );
                }
                if (data.isEmpty) {
                  return Text('暂无 1RM 估算，先记录几组训练', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in data.relativeStrength) _RatioRow(item: item),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    _BigThreeBlock(standards: data),
                    if (data.dots != null || data.wilks != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (data.dots case final dots?)
                            _ScoreChip(icon: Symbols.monitor_weight_rounded, label: 'Dots', value: dots),
                          if (data.wilks case final wilks?)
                            _ScoreChip(icon: Symbols.balance_rounded, label: 'Wilks', value: wilks),
                          if (data.pushPull case final pushPull?)
                            _ScoreChip(
                              icon: Symbols.balance_rounded,
                              label: '推:拉',
                              value: pushPull.ratio,
                              suffix: pushPull.verdictLabel,
                            ),
                        ],
                      ),
                    ],
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

class _RatioRow extends StatelessWidget {
  const _RatioRow({required this.item});

  final RelativeStrengthItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final kg = item.estimated1rmKg % 1 == 0 ? item.estimated1rmKg.toInt().toString() : item.estimated1rmKg.toStringAsFixed(1);

    return InkWell(
      onTap: () => context.push(
        AppRoutes.exerciseStatsOf(item.exerciseId),
        extra: ExerciseStatsArgs(name: item.name),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (item.isBigThree)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Symbols.star_rounded, size: 16, color: cs.tertiary, fill: 1),
              ),
            Expanded(child: Text(item.name, style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600))),
            Text('$kg kg', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(width: 10),
            Text(
              item.ratio == null ? '—' : '${item.ratio!.toStringAsFixed(2)}×',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _BigThreeBlock extends StatelessWidget {
  const _BigThreeBlock({required this.standards});

  final StrengthStandards standards;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final big = standards.bigThree;
    final lifts = <(String, IconData, BigThreeLift?)>[
      ('深蹲', Symbols.accessibility_new_rounded, big.squat),
      ('卧推', Symbols.exercise_rounded, big.bench),
      ('硬拉', Symbols.fitness_center_rounded, big.deadlift),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('三大项', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600))),
            Text(
              big.totalKg == null
                  ? '缺 ${big.missing.join('、')}'
                  : '合计 ${big.totalKg!.toStringAsFixed(0)} kg',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (label, icon, lift) in lifts)
              Expanded(
                child: Column(
                  children: [
                    M3EContainer(
                      Shapes.circle,
                      width: 36,
                      height: 36,
                      color: cs.primaryContainer,
                      child: Icon(icon, size: 18, color: cs.onPrimaryContainer, fill: 1),
                    ),
                    const SizedBox(height: 6),
                    Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                    Text(
                      lift?.estimated1rmKg == null ? '—' : '${lift!.estimated1rmKg!.toStringAsFixed(0)} kg',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      lift?.ratio == null ? '—' : '${lift!.ratio!.toStringAsFixed(2)}×',
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.icon, required this.label, this.value, this.suffix});

  final IconData icon;
  final String label;
  final double? value;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              value == null ? '—' : value!.toStringAsFixed(2),
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (suffix != null)
              Text(suffix!, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
