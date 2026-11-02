import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/safe_area_ext.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:app_flutter/features/profile/domain/metrics.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// 健身档案详情：基础信息 + BMR / TDEE / 目标热量。
class FitnessProfilePage extends ConsumerWidget {
  const FitnessProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fitnessProfileProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('健身档案')),
      body: async.when(
        loading: () => const Center(child: M3ECircularWavyProgressIndicator()),
        error: (error, _) => AppErrorState(error: error, onRetry: () => ref.invalidate(fitnessProfileProvider)),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('还没有健身档案'),
                    const SizedBox(height: 16),
                    M3EButton(
                      onPressed: () {
                        ref.invalidate(onboardingProvider);
                        context.push(AppRoutes.onboarding);
                      },
                      child: const Text('去完善'),
                    ),
                  ],
                ),
              ),
            );
          }
          final metrics = profile.metrics ?? computeMetrics(profile);
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          final injuries = profile.injuryTags.isEmpty
              ? '无'
              : profile.injuryTags.map((t) => FitnessInjury.labels[t] ?? t).join('、');
          return ListView(
            padding: EdgeInsets.fromLTRB(16, context.appBarInset, 16, 32),
            children: [
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今日热量目标',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatKcal(metrics.calorieTarget),
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        metrics.splitName.isEmpty ? '基础计划' : metrics.splitName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              M3ESegmentedColumn(
                children: [
                  ListTile(
                    title: const Text('基础代谢 BMR'),
                    trailing: Text(formatKcal(metrics.bmr), style: tt.titleSmall),
                  ),
                  ListTile(
                    title: const Text('每日消耗 TDEE'),
                    trailing: Text(formatKcal(metrics.tdee), style: tt.titleSmall),
                  ),
                  ListTile(
                    title: const Text('最大心率'),
                    trailing: Text('${metrics.maxHr.round()} bpm', style: tt.titleSmall),
                  ),
                  ListTile(
                    title: const Text('年龄'),
                    trailing: Text('${metrics.age} 岁', style: tt.titleSmall),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              M3ESegmentedColumn(
                children: [
                  ListTile(
                    title: const Text('性别'),
                    trailing: Text(FitnessGender.labels[profile.gender] ?? profile.gender, style: tt.titleSmall),
                  ),
                  ListTile(
                    title: const Text('身高'),
                    trailing: Text('${profile.heightCm.round()} cm', style: tt.titleSmall),
                  ),
                  ListTile(
                    title: const Text('体重'),
                    trailing: Text('${_fmtWeight(profile.weightKg)} kg', style: tt.titleSmall),
                  ),
                  ListTile(
                    title: const Text('目标'),
                    trailing: Text(FitnessGoal.labels[profile.goal] ?? profile.goal, style: tt.titleSmall),
                  ),
                  ListTile(
                    title: const Text('经验'),
                    trailing: Text(
                      FitnessExperience.labels[profile.experience] ?? profile.experience,
                      style: tt.titleSmall,
                    ),
                  ),
                  ListTile(
                    title: const Text('伤病'),
                    trailing: Text(injuries, style: tt.titleSmall),
                  ),
                  ListTile(
                    title: const Text('训练安排'),
                    trailing: Text(
                      '每周 ${profile.weeklyDays ?? 3} 天 · 每次 ${profile.sessionMinutes ?? 45} 分钟',
                      style: tt.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              M3EButton(
                size: .md,
                style: M3EButtonStyle.tonal,
                onPressed: () {
                  ref.invalidate(onboardingProvider);
                  context.push(AppRoutes.onboarding);
                },
                child: const Text('重新填写'),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _fmtWeight(double kg) => kg == kg.roundToDouble() ? '${kg.round()}' : kg.toStringAsFixed(1);
