import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/exercises/application/providers/exercises_provider.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_stats_page.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 动作详情页。
///
/// 通过路由参数 `id` 读取 [exerciseDetailProvider]，展示动作图片、名称、
/// 主/辅助肌群、器械与说明。
class ExerciseDetailPage extends ConsumerWidget {
  const ExerciseDetailPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(exerciseDetailProvider(id));

    return Scaffold(
      appBar: GlassAppBar(title: const Text('动作详情')),
      body: detail.when(
        loading: () => const Center(child: M3ELoadingIndicator()),
        error: (error, _) => AppErrorState(error: error, onRetry: () => ref.invalidate(exerciseDetailProvider(id))),
        data: (exercise) => _DetailBody(exercise: exercise),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.exercise});

  final ExerciseDetail exercise;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (exercise.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.field),
            child: ColoredBox(
              color: colorScheme.surfaceContainerHighest,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cacheWidth = (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).round();
                  return CachedNetworkImage(
                    imageUrl: exercise.imageUrl!,
                    cacheKey: stableImageCacheKey(exercise.imageUrl!),
                    width: constraints.maxWidth,
                    fit: BoxFit.contain,
                    // 大图（可能是几 MB 的 GIF）按盒子宽度解码；高度跟图片比例走，避免 cover 裁切。
                    memCacheWidth: cacheWidth,
                    useOldImageOnUrlChange: true,
                    placeholder: (_, _) => SizedBox(width: constraints.maxWidth, height: 220),
                    errorWidget: (_, _, _) => SizedBox(width: constraints.maxWidth, height: 220),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(exercise.name, style: textTheme.headlineSmall),
        if (exercise.nameEn != null) ...[
          const SizedBox(height: 4),
          Text(exercise.nameEn!, style: textTheme.titleMedium),
        ],
        const SizedBox(height: 8),
        Text(
          exercise.exerciseType == 'compound' ? '复合动作' : '孤立动作',
          style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
        ),
        const SizedBox(height: 16),
        M3EButton.icon(
          style: M3EButtonStyle.tonal,
          onPressed: () =>
              context.push(AppRoutes.exerciseStatsOf(exercise.id), extra: ExerciseStatsArgs(name: exercise.name)),
          icon: const Icon(Symbols.monitoring_rounded),
          label: const Text('数据图表'),
        ),
        const SizedBox(height: 16),
        _InfoRow(label: '主肌群', value: exercise.primaryMuscleName ?? '-'),
        _InfoRow(label: '器械', value: exercise.equipmentName ?? '无'),
        if (exercise.secondaryMuscles.isNotEmpty)
          _InfoRow(label: '辅助肌群', value: exercise.secondaryMuscles.map((m) => m.name).join('、')),
        if (exercise.instructions != null && exercise.instructions!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('动作说明', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(exercise.instructions!, style: textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: textTheme.bodySmall)),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
