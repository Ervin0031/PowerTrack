import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_anatomy.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/stats/application/providers/advanced_stats_providers.dart';
import 'package:app_flutter/features/stats/domain/entities/volume_landmarks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// 本周肌群：人体按区间着色，右侧只列出还不够或偏多的部位。
class StatsVolumeLandmarks extends ConsumerWidget {
  const StatsVolumeLandmarks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(volumeLandmarksProvider);
    final female = isFemaleAnatomy(ref.watch(fitnessProfileProvider).value?.gender);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本周肌群', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('按有效组，对照你的目标区间', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            async.when(
              loading: () => const Align(alignment: Alignment.centerLeft, child: M3ELoadingIndicator()),
              error: (_, _) => Text('肌群加载失败', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              data: (data) {
                if (data.items.isEmpty) {
                  return Text('暂无数据', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant));
                }
                final exceptions = data.items.where((item) => item.zone == 'below_mev' || item.zone == 'above_mrv').toList();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    MuscleStatusAnatomy(female: female, tints: _tints(data.items, cs)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: exceptions.isEmpty
                          ? Text('都在目标区间里', style: tt.bodyMedium)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < exceptions.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  _ExceptionRow(item: exceptions[i]),
                                ],
                              ],
                            ),
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

List<MuscleTint> _tints(List<VolumeLandmarkItem> items, ColorScheme cs) {
  Color? colorOf(VolumeLandmarkItem item) => switch (item.zone) {
    'below_mev' => cs.tertiary,
    'mev' || 'mav' => cs.primary,
    'above_mrv' => cs.error,
    _ => null,
  };

  final tinted = [for (final item in items) if (colorOf(item) case final color?) (item, color)];
  tinted.sort((a, b) => _rank(a.$1.zone).compareTo(_rank(b.$1.zone)));
  return [for (final (item, color) in tinted) MuscleTint(name: item.name, color: color)];
}

int _rank(String zone) => switch (zone) {
  'mev' || 'mav' => 0,
  'below_mev' => 1,
  'above_mrv' => 2,
  _ => 0,
};

class _ExceptionRow extends StatelessWidget {
  const _ExceptionRow({required this.item});

  final VolumeLandmarkItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tooMuch = item.zone == 'above_mrv';
    final color = tooMuch ? cs.error : cs.tertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        Text('${item.hardSets} 组 · ${tooMuch ? '偏多' : '还不够'}', style: tt.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}
