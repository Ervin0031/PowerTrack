import 'dart:math' as math;

import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_anatomy.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_legend.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/templates/application/providers/templates_provider.dart';
import 'package:app_flutter/features/templates/domain/entities/workout_template.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/entities/training_set_kind.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/domain/strength.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_stats_page.dart';
import 'package:app_flutter/features/training/presentation/widgets/exercise_motion.dart';
import 'package:app_flutter/features/training/presentation/widgets/session_exercise_list.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

class TemplateDetailPage extends ConsumerWidget {
  const TemplateDetailPage({super.key, required this.templateId});

  final int templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(templateDetailProvider(templateId));
    final female = isFemaleAnatomy(ref.watch(fitnessProfileProvider).value?.gender);

    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('模板'),
        actions: [
          detail.maybeWhen(
            data: (item) => item.isOwner
                ? AppMenuButton<String>(
                    icon: Symbols.more_horiz_rounded,
                    iconSize: 42,
                    style: M3EButtonStyle.text,
                    size: .sm,
                    circular: true,

                    buttonPadding: EdgeInsets.zero,
                    items: const [
                      AppMenuEntry(value: 'edit', label: '修改'),
                      AppMenuEntry(value: 'delete', label: '删除', isDestructive: true),
                    ],
                    onSelected: (entry) => _onMenu(context, ref, item, entry.value),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: M3ELoadingIndicator()),
        error: (error, _) =>
            AppErrorState(error: error, onRetry: () => ref.invalidate(templateDetailProvider(templateId))),
        data: (item) => _Body(item: item, female: female),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, WorkoutTemplate item, String value) async {
    if (value == 'edit') {
      context.push(AppRoutes.templateEditOf(item.id));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模板？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(templatesProvider.notifier).deleteTemplate(item.id);
      if (context.mounted) context.pop();
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
}

class _Body extends ConsumerWidget {
  const _Body({required this.item, required this.female});

  final WorkoutTemplate item;
  final bool female;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = context.safeBottom + 96;
    final training = ref.watch(trainingSessionProvider);
    final hasActive = training.value != null;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(0, 0, 0, bottom),
          children: [
            if (item.coverUrl != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final cacheWidth = (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).round();
                  return CachedNetworkImage(
                    imageUrl: item.coverUrl!,
                    cacheKey: stableImageCacheKey(item.coverUrl!),
                    width: constraints.maxWidth,
                    fit: BoxFit.contain,
                    memCacheWidth: cacheWidth,
                    placeholder: (_, _) => SizedBox(width: constraints.maxWidth, height: 180),
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                  const SizedBox(height: 6),
                  Text(
                    [
                      item.difficulty.label,
                      item.isPublic ? '公开' : '私密',
                      item.ownerUsername,
                    ].where((part) => part.trim().isNotEmpty).join(' · '),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (item.description != null && item.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(item.description!, style: tt.bodyLarge),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    '${item.exerciseCount} 动作 · ${item.setCount} 组 · 完成 ${item.completionCount}',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('训练动作', style: tt.titleMedium),
            ),
            const SizedBox(height: 4),
            if (item.exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text('还没有动作', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              )
            else
              _TemplateExercisePaper(exercises: [for (final exercise in item.exercises) exercise.toTrainingExercise()]),
            if (item.equipment.isNotEmpty) ...[
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('用到的器械', style: tt.titleMedium),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  item.equipment.map((eq) => eq.name).join(' · '),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
            if (item.primaryMuscles.isNotEmpty || item.secondaryMuscles.isNotEmpty) ...[
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('会练到的肌群', style: tt.titleMedium),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: WorkoutMuscleLegend(
                  primary: item.primaryFeedMuscles,
                  secondary: item.secondaryFeedMuscles,
                  maxPrimary: null,
                  maxSecondary: null,
                ),
              ),
              const SizedBox(height: 50),
              Center(
                child: WorkoutMuscleAnatomy(
                  female: female,
                  primary: item.primaryFeedMuscles,
                  secondary: item.secondaryFeedMuscles,
                  height: 240,
                ),
              ),
            ],
            const SizedBox(height: 24),
            InkWell(
              onTap: () => context.push(AppRoutes.templateCompletionsOf(item.id)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('完成列表', style: tt.titleMedium),
                          Text(
                            '${item.completionCount} 次完成',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: context.safeBottom + 16,
          child: M3EButton(
            size: M3EButtonSize.md,
            onPressed: training.isLoading ? null : () => _start(context, ref, hasActive),
            child: Text(hasActive ? '已有进行中的训练' : '用此模板开始'),
          ),
        ),
      ],
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref, bool hasActive) async {
    if (hasActive) {
      showExpressiveSnack(context: context, message: '请先结束或放弃当前训练', icon: Symbols.flag_rounded);
      return;
    }
    try {
      await ref.read(trainingSessionProvider.notifier).start(templateId: item.id);
      await ref.read(trainingSessionProvider.notifier).loadTemplateExercises([
        for (final e in item.exercises) e.toTrainingExercise(),
      ]);
      if (!context.mounted) return;
      context.push(AppRoutes.trainingSession);
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
}

/// 训练会话同款动作卡片，只读：点开看组，不改草稿。
class _TemplateExercisePaper extends StatefulWidget {
  const _TemplateExercisePaper({required this.exercises});

  final List<TrainingExercise> exercises;

  @override
  State<_TemplateExercisePaper> createState() => _TemplateExercisePaperState();
}

class _TemplateExercisePaperState extends State<_TemplateExercisePaper> {
  int? _openId;

  @override
  Widget build(BuildContext context) {
    final blocks = groupExercises(widget.exercises);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        spacing: 12,
        children: [for (final block in blocks) _ExerciseBlock(block: block, openId: _openId, onToggle: _toggle)],
      ),
    );
  }

  void _toggle(int exerciseId) {
    setState(() => _openId = _openId == exerciseId ? null : exerciseId);
  }
}

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({required this.block, required this.openId, required this.onToggle});

  final ExerciseBlock block;
  final int? openId;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = M3ESegmentedList.builder(
      color: block.isSuperset ? cs.primaryContainer.withValues(alpha: 0.45) : cs.surfaceContainer,
      listPadding: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: block.exercises.length,
      outerRadius: 28,
      innerRadius: 42,
      itemBuilder: (_, index) {
        final exercise = block.exercises[index];
        return _TemplateExerciseRow(
          exercise: exercise,
          expanded: openId == exercise.exerciseId,
          onToggle: () => onToggle(exercise.exerciseId),
        );
      },
    );
    if (!block.isSuperset) return list;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(Symbols.conversion_path_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('超级组', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary)),
                  const Spacer(),
                  Text(
                    '${block.exercises.length} 个动作轮换',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            list,
          ],
        ),
      ),
    );
  }
}

class _TemplateExerciseRow extends StatelessWidget {
  const _TemplateExerciseRow({required this.exercise, required this.expanded, required this.onToggle});

  final TrainingExercise exercise;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unit = weightUnitLabel(exercise.weightUnit);
    final oneRm = estimated1rmFromExercise(exercise);
    final subtitle = expanded ? _expandedLine(exercise, oneRm, unit) : _planLine(exercise);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(AppRadius.field),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                  child: Row(
                    children: [
                      AppNetworkImage(url: exercise.imageUrl, size: 48, radius: 10),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SingleMotionBuilder(
                              motion: M3EMotion.standardSpatialFast.toMotion(),
                              value: expanded ? 1 : 0,
                              builder: (context, t, _) {
                                final p = t.clamp(0.0, 1.0);
                                return Text(
                                  exercise.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.lerp(FontWeight.w400, FontWeight.w600, p),
                                    color: Color.lerp(cs.onSurface, cs.primary, p),
                                  ),
                                );
                              },
                            ),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                      SingleMotionBuilder(
                        motion: M3EMotion.standardSpatialFast.toMotion(),
                        value: expanded ? 1 : 0,
                        builder: (context, t, _) {
                          final p = t.clamp(0.0, 1.0);
                          return Transform.rotate(
                            angle: p * math.pi,
                            child: Icon(
                              Symbols.expand_more_rounded,
                              color: Color.lerp(cs.onSurfaceVariant, cs.primary, p),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: '趋势数据',
                onPressed: () => context.push(
                  AppRoutes.exerciseStatsOf(exercise.exerciseId),
                  extra: ExerciseStatsArgs(name: exercise.name, weightUnit: exercise.weightUnit),
                ),
                icon: Icon(Symbols.monitoring_rounded, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
        M3EExpand(
          expanded: expanded,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                if (exercise.notes != null && exercise.notes!.trim().isNotEmpty)
                  Text(
                    exercise.notes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                _ReadOnlySets(exercise: exercise),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlySets extends StatelessWidget {
  const _ReadOnlySets({required this.exercise});

  final TrainingExercise exercise;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final unit = weightUnitLabel(exercise.weightUnit);
    if (exercise.sets.isEmpty) {
      return Text('还没有组', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant));
    }
    final labels = trainingSetDisplayLabels(exercise.sets);
    return Column(
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            spacing: 8,
            children: [
              const _Head(flex: 1, text: '组数'),
              const _Head(flex: 2, text: '次数'),
              _Head(flex: 2, text: '重量($unit)'),
            ],
          ),
        ),
        for (var i = 0; i < exercise.sets.length; i++)
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                spacing: 8,
                children: [
                  _Cell(flex: 1, text: labels[i]),
                  _Cell(flex: 2, text: exercise.sets[i].reps?.toString() ?? '—'),
                  _Cell(
                    flex: 2,
                    text: exercise.sets[i].weightKg == null
                        ? '—'
                        : formatWeight(exercise.sets[i].weightKg!, unit: exercise.weightUnit),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.flex, required this.text});

  final int flex;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.flex, required this.text});

  final int flex;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

String _planLine(TrainingExercise exercise) {
  if (exercise.sets.isEmpty) return '还没有组';
  final first = exercise.sets.first;
  final unit = weightUnitLabel(exercise.weightUnit);
  final load = [
    if (first.reps != null) '${first.reps} 次',
    if (first.weightKg != null) '${formatWeight(first.weightKg!, unit: exercise.weightUnit)}$unit',
  ].join(' × ');
  return load.isEmpty ? '${exercise.sets.length} 组' : '${exercise.sets.length} 组 · $load';
}

String _expandedLine(TrainingExercise exercise, double? oneRm, String unit) {
  return [
    if (oneRm != null) '估 1RM ${formatWeight(oneRm, unit: exercise.weightUnit)}$unit',
    if (exercise.restTargetSeconds != null) '休息 ${formatRestSeconds(exercise.restTargetSeconds)}',
  ].join(' · ');
}
