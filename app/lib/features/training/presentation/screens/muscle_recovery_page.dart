import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_anatomy.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/training/application/providers/muscle_group_status_provider.dart';
import 'package:app_flutter/features/training/domain/entities/muscle_group_status.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// 各肌群恢复：大标题概括，横向摘要，每张卡片一个恢复百分比和波浪进度。
class MuscleRecoveryPage extends ConsumerStatefulWidget {
  const MuscleRecoveryPage({super.key});

  @override
  ConsumerState<MuscleRecoveryPage> createState() => _MuscleRecoveryPageState();
}

class _MuscleRecoveryPageState extends ConsumerState<MuscleRecoveryPage> {
  final _cardKeys = <int, GlobalKey>{};

  GlobalKey _keyFor(int id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(muscleGroupStatusProvider);
    final female = isFemaleAnatomy(ref.watch(fitnessProfileProvider).value?.gender);

    return Scaffold(
      appBar: const GlassAppBar(title: Text('恢复')),
      body: async.when(
        loading: () => const Center(child: M3ELoadingIndicator()),
        error: (error, _) => AppErrorState(error: error, onRetry: () => ref.invalidate(muscleGroupStatusProvider)),
        data: (summary) => _RecoveryBody(items: summary.items, female: female, keyFor: _keyFor),
      ),
    );
  }
}

class _RecoveryBody extends StatelessWidget {
  const _RecoveryBody({required this.items, required this.female, required this.keyFor});

  final List<MuscleGroupStatus> items;
  final bool female;
  final GlobalKey Function(int id) keyFor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ordered = _recoveryOrder(items);
    final now = DateTime.now();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + context.safeBottom),
      children: [
        Text(_dateLabel(now), style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text(_headline(items), style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w700, height: 1.15)),
        const SizedBox(height: 8),
        Text(_subtitle(items), style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
        if (ordered.isNotEmpty) ...[
          const SizedBox(height: 20),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ordered.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final muscle = ordered[index];
                return _SummaryChip(
                  muscle: muscle,
                  onTap: () {
                    final target = keyFor(muscle.muscleGroupId).currentContext;
                    if (target == null) return;
                    Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 280), alignment: 0.12);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _RecoveryCard(key: keyFor(ordered[i].muscleGroupId), muscle: ordered[i], female: female),
          ],
        ],
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.muscle, required this.onTap});

  final MuscleGroupStatus muscle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = _statusColor(cs, muscle);
    return Material(
      color: cs.surfaceContainerLowest,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(muscle.name, style: tt.labelLarge),
              const SizedBox(width: 8),
              Text(
                _percentLabel(muscle),
                style: tt.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({super.key, required this.muscle, required this.female});

  final MuscleGroupStatus muscle;
  final bool female;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = _statusColor(cs, muscle);
    final trained = _hasHistory(muscle);
    final progress = trained ? muscle.recoveryProgress.clamp(0.0, 1.0) : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 168,
            child: MuscleGroupCloseup(female: female, name: muscle.name, nameEn: muscle.nameEn),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(muscle.name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Text(_readyLabel(muscle), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('恢复', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(_lastTrainedLabel(muscle), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Text(
                      _percentLabel(muscle),
                      style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: color, height: 1),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(_stateLabel(muscle), style: tt.labelSmall?.copyWith(color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return M3ELinearWavyProgressIndicator(
                      value: progress,
                      color: color,
                      backgroundColor: cs.surfaceContainerHighest,
                      width: constraints.maxWidth,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _hasHistory(MuscleGroupStatus muscle) => muscle.lastTrainedAt.year >= 2000;

List<MuscleGroupStatus> _recoveryOrder(List<MuscleGroupStatus> items) {
  final copy = [...items];
  int rank(MuscleGroupStatus muscle) {
    if (!_hasHistory(muscle)) return 2;
    if (muscle.isRecovered) return 1;
    return 0;
  }

  copy.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return a.recoveryProgress.compareTo(b.recoveryProgress);
  });
  return copy;
}

String _headline(List<MuscleGroupStatus> items) {
  final waiting = items.where((muscle) => _hasHistory(muscle) && !muscle.isRecovered).toList();
  if (waiting.isEmpty) return '都恢复了。';
  if (waiting.length == 1) return '${waiting.first.name}还在恢复。';
  return '还有 ${waiting.length} 处没恢复。';
}

String _subtitle(List<MuscleGroupStatus> items) {
  final waiting = items.where((muscle) => _hasHistory(muscle) && !muscle.isRecovered).toList()
    ..sort((a, b) => a.hoursUntilReady.compareTo(b.hoursUntilReady));
  if (waiting.isEmpty) return '主要肌群可以安排训练';
  final next = waiting.first;
  return '下次可练：${next.name} · ${_readyLabel(next)}';
}

String _percentLabel(MuscleGroupStatus muscle) {
  if (!_hasHistory(muscle)) return '未练';
  return '${(muscle.recoveryProgress * 100).clamp(0, 100).round()}%';
}

String _stateLabel(MuscleGroupStatus muscle) {
  if (!_hasHistory(muscle)) return '无记录';
  if (muscle.isRecovered) return '可练';
  return '恢复中';
}

String _readyLabel(MuscleGroupStatus muscle) {
  if (!_hasHistory(muscle)) return '还没练过';
  if (muscle.isRecovered) return '可以练';
  final wait = muscle.hoursUntilReady;
  if (wait >= 24) return '约 ${(wait / 24).ceil()} 天后';
  if (wait <= 0) return '快好了';
  return '约 $wait 小时后';
}

String _lastTrainedLabel(MuscleGroupStatus muscle) {
  if (!_hasHistory(muscle)) return '还没有训练记录';
  final hours = DateTime.now().difference(muscle.lastTrainedAt).inHours;
  if (hours < 1) return '刚刚练过';
  if (hours < 24) return '$hours 小时前练过';
  return '${hours ~/ 24} 天前练过';
}

Color _statusColor(ColorScheme cs, MuscleGroupStatus muscle) {
  if (!_hasHistory(muscle)) return cs.onSurfaceVariant;
  if (muscle.isRecovered) return cs.primary;
  if (muscle.recoveryProgress < 0.45) return cs.error;
  return cs.tertiary;
}

String _dateLabel(DateTime now) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${now.month}月${now.day}日 星期${weekdays[now.weekday - 1]}';
}
