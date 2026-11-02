import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/glass_pull_to_refresh.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/training/application/providers/exercise_stats_provider.dart';
import 'package:app_flutter/features/training/domain/entities/exercise_stats.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/domain/strength.dart';
import 'package:app_flutter/features/training/presentation/widgets/exercise_strength_board.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 路由 extra：动作名与重量单位。
class ExerciseStatsArgs {
  const ExerciseStatsArgs({required this.name, this.weightUnit = 'kg'});

  final String name;
  final String weightUnit;
}

/// 动作数据图表：数据 / 个人记录 / 历史。
class ExerciseStatsPage extends ConsumerStatefulWidget {
  const ExerciseStatsPage({
    super.key,
    required this.exerciseId,
    required this.name,
    this.weightUnit = 'kg',
  });

  final int exerciseId;
  final String name;
  final String weightUnit;

  @override
  ConsumerState<ExerciseStatsPage> createState() => _ExerciseStatsPageState();
}

class _ExerciseStatsPageState extends ConsumerState<ExerciseStatsPage> {
  /// 与下方 GlassAppBar 的 bottom（切换按钮组）高度保持同步。
  static const _appBarBottomHeight = 60.0;

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(exerciseStatsProvider(widget.exerciseId));

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(widget.name),
        bottom: PreferredSize(
          preferredSize: .fromHeight(_appBarBottomHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = (constraints.maxWidth - 8) / 3;
                return M3EToggleButtonGroup(
                  selectedIndex: _tab,
                  onSelectedIndexChanged: (index) {
                    if (index != null) setState(() => _tab = index);
                  },
                  type: M3EButtonGroupType.connected,
                  style: M3EButtonStyle.tonal,
                  shape: M3EButtonShape.round,
                  size: M3EButtonSize.sm,
                  neighborSquish: false,
                  actions: [
                    M3EToggleButtonGroupAction(
                      label: const Text('数据'),
                      width: w,
                    ),
                    M3EToggleButtonGroupAction(
                      label: const Text('个人记录'),
                      width: w,
                    ),
                    M3EToggleButtonGroupAction(
                      label: const Text('历史'),
                      width: w,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: statsAsync.when(
        loading: () => const Center(child: M3ELoadingIndicator()),
        error: (error, _) => AppErrorState(
          error: error,
          onRetry: () =>
              ref.invalidate(exerciseStatsProvider(widget.exerciseId)),
        ),
        data: (stats) => Column(
          children: [
            Expanded(
              child: GlassPullToRefresh(
                edgeOffset: context.appBarInset + _appBarBottomHeight,
                onRefresh: () async {
                  ref.invalidate(exerciseStatsProvider(widget.exerciseId));
                  ref.invalidate(exerciseOneRmProvider(widget.exerciseId));
                  ref.invalidate(
                    exerciseOneRmHistoryProvider(widget.exerciseId),
                  );
                  await ref.read(
                    exerciseStatsProvider(widget.exerciseId).future,
                  );
                  try {
                    await ref.read(
                      exerciseOneRmProvider(widget.exerciseId).future,
                    );
                  } catch (_) {}
                },
                child: _tabBody(stats),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBody(ExerciseStats stats) {
    return switch (_tab) {
      1 => _RecordsTab(records: stats.records, weightUnit: widget.weightUnit),
      2 => _HistoryTab(history: stats.history, weightUnit: widget.weightUnit),
      _ => ExerciseStrengthBoard(stats: stats, weightUnit: widget.weightUnit),
    };
  }
}

class _RecordsTab extends StatelessWidget {
  const _RecordsTab({required this.records, required this.weightUnit});

  final PersonalRecords records;
  final String weightUnit;

  @override
  Widget build(BuildContext context) {
    final unit = weightUnitLabel(weightUnit);
    final rows = <(String, String, String?)>[
      (
        '最大重量',
        records.maxWeightKg == null
            ? '—'
            : '${formatWeight(records.maxWeightKg!, unit: weightUnit)}$unit',
        _mdLabel(records.maxWeightAt),
      ),
      (
        '最大次数',
        records.maxReps == null ? '—' : '${records.maxReps} 次',
        _mdLabel(records.maxRepsAt),
      ),
      (
        '单组容量',
        records.maxSetVolume == null
            ? '—'
            : records.maxSetVolume!.toStringAsFixed(0),
        _mdLabel(records.maxSetVolumeAt),
      ),
      (
        '估算 1RM',
        records.estimated1rmKg == null
            ? '—'
            : '${formatWeight(records.estimated1rmKg!, unit: weightUnit)}$unit',
        null,
      ),
      ('训练次数', '${records.sessionCount} 次', null),
      ('首次训练', _mdLabel(records.firstAt) ?? '—', null),
      ('最近训练', _mdLabel(records.lastAt) ?? '—', null),
    ];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        16,
        32,
      ),
      child: Column(
        children: [
          if (records.sessionCount == 0)
            _EmptyHint(
              icon: Symbols.emoji_events_rounded,
              text: '完成一次训练后，这里会记下你的个人纪录',
            )
          else
            M3ESegmentedColumn(
              outerRadius: AppRadius.card,
              children: [
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row.$1),
                    subtitle: row.$3 == null ? null : Text(row.$3!),
                    trailing: Text(
                      row.$2,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.history, required this.weightUnit});

  final List<ExerciseHistorySession> history;
  final String weightUnit;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 4,
          16,
          32,
        ),
        children: const [
          _EmptyHint(icon: Symbols.history_rounded, text: '还没有这个动作的训练记录'),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 4,
        16,
        32,
      ),
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = history[index];
        return M3ESegmentedColumn(
          outerRadius: AppRadius.card,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mdLabel(session.startedAt) ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final set in session.sets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Text(
                          '第 ${set.setNumber} 组',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        Text(
                          _setLine(set, weightUnit),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
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
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String _setLine(ExerciseHistorySet set, String unit) {
  final parts = <String>[];
  if (set.weightKg != null) {
    parts.add(
      '${formatWeight(set.weightKg!, unit: unit)}${weightUnitLabel(unit)}',
    );
  }
  if (set.reps != null) parts.add('${set.reps} 次');
  var body = parts.join(' × ');
  if (set.rpe != null) {
    final tag = 'RPE ${formatRpe(set.rpe!)}';
    body = body.isEmpty ? tag : '$body · $tag';
  }
  return body.isEmpty ? '—' : body;
}

String? _mdLabel(Object? value) {
  DateTime? dt;
  if (value is DateTime) {
    dt = value.toLocal();
  } else if (value is String) {
    dt = DateTime.tryParse(value)?.toLocal();
  }
  if (dt == null) return null;
  return '${dt.month}月${dt.day}日';
}
