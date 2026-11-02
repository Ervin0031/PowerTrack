import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_anatomy.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/training/application/providers/muscle_group_status_provider.dart';
import 'package:app_flutter/features/training/domain/entities/muscle_group_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 首页恢复卡：人体图表示未恢复肌群，右侧只列还不能练的部位。
class RecoveryAnatomyCard extends ConsumerWidget {
  const RecoveryAnatomyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(muscleGroupStatusProvider);
    return async.maybeWhen(
      data: (summary) {
        if (summary.items.isEmpty) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final female = isFemaleAnatomy(ref.watch(fitnessProfileProvider).value?.gender);
        final waiting = summary.items.where(_isWaiting).toList();
        // 未恢复先涂 tertiary，很低的恢复再涂 error，重叠时更紧急的颜色盖住。
        final tints = [
          for (final muscle in waiting)
            if (muscle.recoveryProgress >= 0.45)
              MuscleTint(name: muscle.name, nameEn: muscle.nameEn, color: cs.tertiary),
          for (final muscle in waiting)
            if (muscle.recoveryProgress < 0.45) MuscleTint(name: muscle.name, nameEn: muscle.nameEn, color: cs.error),
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(AppRoutes.muscleRecovery),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('恢复', style: tt.titleMedium),
                        const Spacer(),
                        Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          child: MuscleStatusAnatomy(female: female, tints: tints),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: waiting.isEmpty
                              ? Text('主要肌群已恢复', style: tt.bodyMedium)
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var i = 0; i < waiting.length; i++) ...[
                                      if (i > 0) const SizedBox(height: 10),
                                      _WaitingRow(muscle: waiting[i]),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// 练过且还没恢复。没有训练记录的肌群保持人体底色。
bool _isWaiting(MuscleGroupStatus muscle) {
  if (muscle.isRecovered) return false;
  return muscle.lastTrainedAt.year >= 2000;
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({required this.muscle});

  final MuscleGroupStatus muscle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final urgent = muscle.recoveryProgress < 0.45;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(muscle.name, style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        Text(
          '${muscle.valueLabel} · ${_waitLabel(muscle)}',
          style: tt.bodySmall?.copyWith(color: urgent ? cs.error : cs.tertiary),
        ),
      ],
    );
  }
}

String _waitLabel(MuscleGroupStatus muscle) {
  final wait = muscle.hoursUntilReady;
  if (wait >= 24) return '约 ${(wait / 24).ceil()} 天';
  return '约 $wait 小时';
}
