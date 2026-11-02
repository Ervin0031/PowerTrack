import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/glass_pull_to_refresh.dart';
import 'package:app_flutter/core/ui/tab_scroll_registry.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/profile/domain/metrics.dart';
import 'package:app_flutter/features/training/application/providers/muscle_group_status_provider.dart';
import 'package:app_flutter/features/training/application/providers/training_home_provider.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/application/providers/training_templates_carousel_provider.dart';
import 'package:app_flutter/features/training/application/providers/weekly_volume_provider.dart';
import 'package:app_flutter/features/training/domain/entities/session_record.dart';
import 'package:app_flutter/features/training/domain/entities/training_home_stats.dart';
import 'package:app_flutter/features/training/domain/volume_delta.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/recovery_anatomy.dart';
import '../widgets/training_templates_carousel.dart';

/// 训练首页：本周进度、周历、连续周数与开始/返回训练入口。
class TrainingPage extends ConsumerStatefulWidget {
  const TrainingPage({super.key});

  @override
  ConsumerState<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends ConsumerState<TrainingPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    TabScrollRegistry.register(0, _scrollController);
  }

  @override
  void dispose() {
    TabScrollRegistry.unregister(0, _scrollController);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final training = ref.watch(trainingSessionProvider);
    final home = ref.watch(trainingHomeProvider);
    final hasActive = training.value != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('训练'),
        actions: [
          M3EButton.icon(
            onPressed: () => context.push(AppRoutes.trainingCalendar),
            icon: const Icon(Symbols.calendar_month_rounded),
            label: const Text('日历'),
          ),
        ],
      ),
      body: GlassPullToRefresh(
        edgeOffset: context.appBarInset,
        notificationPredicate: (notification) {
          if (notification.depth != 0) return false;
          // 只在列表顶部处理下拉；底部 overscroll 交给 ListView 回弹，避免 header 高度抖动。
          if (notification is OverscrollNotification) {
            return notification.metrics.extentBefore <= 0 && notification.overscroll < 0;
          }
          return true;
        },
        onRefresh: () async {
          ref.invalidate(trainingHomeProvider);
          ref.invalidate(muscleGroupStatusProvider);
          ref.invalidate(trainingTemplatesCarouselProvider);
          await ref.read(trainingHomeProvider.future);
          try {
            await ref.read(muscleGroupStatusProvider.future);
          } catch (_) {}
          try {
            await ref.read(trainingTemplatesCarouselProvider.future);
          } catch (_) {}
        },
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: context.appBarInset, bottom: MediaQuery.paddingOf(context).bottom + 96),
          children: [
            home.when(
              loading: () => const SizedBox(height: 160, child: Center(child: M3ELoadingIndicator())),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(userFacingErrorMessage(error)),
                    const SizedBox(height: 12),
                    M3ETextButton(onPressed: () => ref.invalidate(trainingHomeProvider), child: const Text('重试')),
                  ],
                ),
              ),
              data: (stats) => _WeekStrip(stats: stats),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: M3EButton(
                      size: .md,
                      onPressed: training.isLoading ? null : () => _onStartTraining(context),
                      child: hasActive
                          ? const Text('返回训练')
                          : training.isLoading
                          ? const SizedBox(width: 20, height: 20, child: M3ELoadingIndicator())
                          : const Text('开始训练'),
                    ),
                  ),

                  Expanded(
                    child: M3EButton(
                      size: .md,
                      style: .tonal,
                      onPressed: () {
                        if (ref.read(trainingSessionProvider).value != null) {
                          context.push(AppRoutes.trainingSession);
                          return;
                        }
                        context.push(AppRoutes.coach);
                      },
                      child: const Text('AI 训练'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const _VolumeCard(),
            const RecoveryAnatomyCard(),
            const _PlanTeaser(),
            home.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (stats) => stats.lastCompleted == null
                  ? const SizedBox.shrink()
                  : _LastSessionRow(session: stats.lastCompleted!),
            ),
            const SizedBox(height: 24),
            const TrainingTemplatesCarousel(),
          ],
        ),
      ),
    );
  }

  Future<void> _onStartTraining(BuildContext context) async {
    if (ref.read(trainingSessionProvider).value != null) {
      context.push('/training/session');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('开始训练？'),
        content: const Text('将创建一次新的训练会话。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('开始')),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(trainingSessionProvider.notifier).start();
    if (!context.mounted) return;
    if (ref.read(trainingSessionProvider).value != null) {
      context.push('/training/session');
    } else {
      final err = ref.read(trainingSessionProvider).error;
      if (err != null) {
        showExpressiveSnack(context: context, message: userFacingErrorMessage(err), icon: Icons.error_outline);
      }
    }
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.stats});

  final TrainingHomeStats stats;

  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('本周', style: tt.titleMedium),
                  const Spacer(),
                  Text('${stats.sessionsThisWeek} 次', style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                  final trained = stats.trainedThisWeek[index];
                  final isToday = _isTodayIndex(index);
                  return Column(
                    children: [
                      M3EContainer(
                        trained ? Shapes.verySunny : Shapes.circle,
                        width: 42,
                        height: 42,
                        color: trained
                            ? cs.primary
                            : isToday
                            ? cs.secondaryContainer
                            : cs.surfaceContainerHighest,
                        child: Center(
                          child: trained
                              ? Icon(Symbols.check_rounded, size: 22, color: cs.onPrimary, weight: 600)
                              : Text(
                                  '${_dayOfMonth(index)}',
                                  style: tt.labelLarge?.copyWith(
                                    color: isToday ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                                    fontWeight: isToday ? FontWeight.w600 : null,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '周${_weekLabels[index]}',
                        style: tt.labelSmall?.copyWith(
                          color: isToday ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: isToday ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  );
                }),
              ),
              if (stats.weekStreak > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Symbols.local_fire_department_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('连续 ${stats.weekStreak} 周', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isTodayIndex(int weekIndex) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(TrainingHomeStats.startOfWeek(now)).inDays == weekIndex;
  }

  int _dayOfMonth(int weekIndex) {
    return TrainingHomeStats.startOfWeek(DateTime.now()).add(Duration(days: weekIndex)).day;
  }
}

class _LastSessionRow extends StatelessWidget {
  const _LastSessionRow({required this.session});

  final SessionRecord session;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final local = session.startedAt.toLocal();
    final dateLabel = '${local.month}月${local.day}日';
    final duration = session.duration;
    final durationLabel = duration == null ? null : formatSessionDuration(duration);
    final title = durationLabel == null ? '上次训练 · $dateLabel' : '上次训练 · $dateLabel · $durationLabel';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Card(
        child: InkWell(
          onTap: () => context.push(AppRoutes.trainingCalendar),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                M3EContainer(
                  Shapes.circle,
                  width: 40,
                  height: 40,
                  color: cs.primaryContainer,
                  child: Icon(Symbols.history_rounded, color: cs.onPrimaryContainer, size: 20, fill: 1),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: tt.bodyMedium)),
                Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 分化名称；点进档案看完整计划。
class _PlanTeaser extends ConsumerWidget {
  const _PlanTeaser();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(fitnessProfileProvider).value;
    if (profile == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final metrics = profile.metrics ?? computeMetrics(profile);
    final title = metrics.splitName.isEmpty ? '你的训练计划' : metrics.splitName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Card(
        child: InkWell(
          onTap: () => context.push(AppRoutes.fitnessProfile),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                M3EContainer(
                  Shapes.circle,
                  width: 40,
                  height: 40,
                  color: cs.primaryContainer,
                  child: Icon(Symbols.calendar_view_week_rounded, color: cs.onPrimaryContainer, size: 20, fill: 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '查看分化与档案',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeCard extends ConsumerWidget {
  const _VolumeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyVolumeProvider);
    return async.maybeWhen(
      data: (summary) {
        final week = summary.thisWeek;
        if (week == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final previous = summary.weeks.length >= 2 ? summary.weeks[summary.weeks.length - 2].volume : null;
        final delta = weekVolumeDeltaLabel(weekVolumeDeltaPercent(previousWeek: previous, thisWeek: week.volume));
        final topMuscle = week.byMuscle.isEmpty ? null : week.byMuscle.first;
        final detail =
            '有效组 ${week.hardSets}'
            '${delta == null ? '' : ' · $delta'}'
            '${topMuscle == null ? '' : ' · ${topMuscle.name}'}';
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      M3EContainer(
                        Shapes.circle,
                        width: 40,
                        height: 40,
                        color: cs.primaryContainer,
                        child: Icon(Symbols.monitoring_rounded, color: cs.onPrimaryContainer, size: 20, fill: 1),
                      ),
                      const SizedBox(width: 12),
                      Text('本周容量', style: tt.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${formatCount(week.volume.round())} kg',
                    style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  if (summary.suggestDeload && summary.deloadReason != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Symbols.health_and_safety_rounded, size: 18, color: cs.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              summary.deloadReason!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
