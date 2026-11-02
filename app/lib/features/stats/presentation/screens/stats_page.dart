import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/glass_pull_to_refresh.dart';
import 'package:app_flutter/core/ui/tab_scroll_registry.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/stats/application/providers/advanced_stats_providers.dart';
import 'package:app_flutter/features/stats/application/providers/stats_overview_provider.dart';
import 'package:app_flutter/features/stats/presentation/widgets/stats_kpi_grid.dart';
import 'package:app_flutter/features/stats/presentation/widgets/stats_period_toggle.dart';
import 'package:app_flutter/features/stats/presentation/widgets/stats_recent_prs.dart';
import 'package:app_flutter/features/stats/presentation/widgets/stats_strength_standards.dart';
import 'package:app_flutter/features/stats/presentation/widgets/stats_top_exercises.dart';
import 'package:app_flutter/features/stats/presentation/widgets/stats_volume_landmarks.dart';
import 'package:app_flutter/features/stats/presentation/widgets/stats_weekly_volume_chart.dart';
import 'package:app_flutter/features/training/application/providers/weekly_volume_provider.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 数据 Tab：中长期复盘（KPI / 日历 / 容量趋势 / 肌群 / PR / 常练动作）。
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  /// 与 AppBar.bottom 的 StatsPeriodToggle 高度保持同步。
  static const _toggleHeight = 56.0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    TabScrollRegistry.register(2, _scrollController);
  }

  @override
  void dispose() {
    TabScrollRegistry.unregister(2, _scrollController);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(statsOverviewProvider);
    ref.invalidate(weeklyVolumeProvider);
    ref.invalidate(volumeLandmarksProvider);
    ref.invalidate(strengthStandardsProvider);
    await ref.read(statsOverviewProvider.future);
    try {
      await Future.wait([
        ref.read(weeklyVolumeProvider.future),
        ref.read(volumeLandmarksProvider.future),
        ref.read(strengthStandardsProvider.future),
      ]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(statsOverviewProvider);
    final topInset = context.appBarInset + _toggleHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('数据'),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(_toggleHeight), child: StatsPeriodToggle()),
      ),
      body: GlassPullToRefresh(
        edgeOffset: topInset,
        onRefresh: _refresh,
        child: overview.when(
          loading: () => ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: topInset + 64),
            children: const [Center(child: M3ELoadingIndicator())],
          ),
          error: (error, _) => ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, topInset + 16, 24, 24),
            children: [
              AppErrorState(error: error, onRetry: () => ref.invalidate(statsOverviewProvider)),
            ],
          ),
          data: (stats) => ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
            ).add(EdgeInsetsGeometry.only(top: topInset + 12, bottom: context.safeBottom + 20)),
            children: [
              if (stats.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: AppEmptyState(
                    icon: Symbols.query_stats_rounded,
                    title: '完成几次训练后，这里会展示趋势',
                    message: '坚持打卡、容量变化与个人纪录都会汇总在此',
                    tint: AppTint.secondary,
                  ),
                )
              else ...[
                StatsKpiGrid(stats: stats),
                const SizedBox(height: 16),
                const StatsWeeklyVolumeChart(),
                const SizedBox(height: 16),
                const StatsVolumeLandmarks(),
                const SizedBox(height: 16),
                const StatsStrengthStandards(),
                if (stats.recentPrs.isNotEmpty) ...[const SizedBox(height: 20), StatsRecentPrs(prs: stats.recentPrs)],
                if (stats.topExercises.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  StatsTopExercises(items: stats.topExercises),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
