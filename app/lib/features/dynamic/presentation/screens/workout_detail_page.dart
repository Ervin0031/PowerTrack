import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:app_flutter/features/dynamic/application/providers/feed_provider.dart';
import 'package:app_flutter/features/dynamic/application/providers/workout_feed_provider.dart';
import 'package:app_flutter/features/dynamic/data/repositories/social_repository.dart';
import 'package:app_flutter/features/dynamic/domain/entities/workout_feed_item.dart';
import 'package:app_flutter/features/dynamic/domain/workout_feed.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/share_caption_sheet.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_exercise_block.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_anatomy.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_legend.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_stat_strip.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_stats_page.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 单次已完成训练的详情。
class WorkoutDetailPage extends ConsumerWidget {
  const WorkoutDetailPage({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(sessionId));
    final username = ref.watch(authControllerProvider).value?.username ?? '我';
    final female = isFemaleAnatomy(ref.watch(fitnessProfileProvider).value?.gender);

    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('训练'),
        actions: [
          M3EButton.icon(
            onPressed: () => _share(context, ref, sessionId),
            icon: const Icon(Symbols.ios_share_rounded),
            label: const Text('分享'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: M3ELoadingIndicator()),
        error: (error, _) =>
            AppErrorState(error: error, onRetry: () => ref.invalidate(workoutDetailProvider(sessionId))),
        data: (item) => _WorkoutDetailBody(item: item, username: username, female: female),
      ),
    );
  }
}

/// 分享为动态：先收配文，再发接口（同一会话重复分享幂等复用同一条）。
Future<void> _share(BuildContext context, WidgetRef ref, int sessionId) async {
  final caption = await showShareCaptionSheet(context);
  if (caption == null || !context.mounted) return;
  try {
    await ref.read(socialRepositoryProvider).shareSession(sessionId, caption: caption);
    ref.invalidate(feedProvider);
    if (context.mounted) showExpressiveSnack(context: context, message: '已发布到动态');
  } catch (error) {
    if (context.mounted) {
      showExpressiveSnack(
        context: context,
        message: userFacingErrorMessage(error),
        icon: Symbols.error_outline_rounded,
      );
    }
  }
}

class _WorkoutDetailBody extends StatelessWidget {
  const _WorkoutDetailBody({required this.item, required this.username, required this.female});

  final WorkoutFeedItem item;
  final String username;
  final bool female;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = context.safeBottom + 24;

    return ListView(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottom),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    M3EContainer.puffy(
                      width: 44,
                      height: 40,
                      color: cs.primaryContainer,
                      child: Center(
                        child: Text(
                          username.isEmpty ? '?' : username.substring(0, 1),
                          style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(username, style: tt.titleMedium),
                          Text(
                            formatFeedTimestamp(item.startedAt),
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(item.title, style: tt.titleLarge),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                WorkoutStatStrip(duration: item.duration, volumeKg: item.volumeKg, kcal: item.estimatedKcal),
                if (item.hasIntensity) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    formatIntensityLine(hardSets: item.hardSetCount, averageRpe: item.averageRpe),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (item.restSeconds.isNotEmpty) ...[
                  if (!item.hasIntensity) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                  ] else
                    const SizedBox(height: 4),
                  Text(formatRestSummary(item.restSeconds), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppSectionHeader(title: '训练动作', trailing: '${item.exercises.length} 个'),
        if (item.exercises.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('没有动作记录', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ),
            ),
          )
        else
          M3ESegmentedColumn(
            onTap: (index) {
              final ex = item.exercises[index];
              context.push(AppRoutes.exerciseStatsOf(ex.exerciseId), extra: ExerciseStatsArgs(name: ex.name));
            },
            children: [for (final ex in item.exercises) WorkoutExerciseBlock(exercise: ex)],
          ),
        if (item.primaryMuscles.isNotEmpty || item.secondaryMuscles.isNotEmpty) ...[
          const SizedBox(height: 24),
          const AppSectionHeader(title: '肌群'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WorkoutMuscleLegend(
                    primary: item.primaryMuscles,
                    secondary: item.secondaryMuscles,
                    maxPrimary: null,
                    maxSecondary: null,
                  ),
                  const SizedBox(height: 50),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: WorkoutMuscleAnatomy(
                        female: female,
                        primary: item.primaryMuscles,
                        secondary: item.secondaryMuscles,
                        height: 240,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
