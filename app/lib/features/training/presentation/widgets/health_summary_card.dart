import 'package:app_flutter/core/native/apple_health_service.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 训练首页：今日苹果健康摘要（环形进度卡片）。
class HealthSummaryCard extends StatefulWidget {
  const HealthSummaryCard({super.key});

  @override
  State<HealthSummaryCard> createState() => _HealthSummaryCardState();
}

class _HealthSummaryCardState extends State<HealthSummaryCard> {
  static const _stepGoal = 10000.0;
  static const _kcalGoal = 500.0;

  HealthDailySummary _summary = const HealthDailySummary();
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final summary = await AppleHealthService.instance.fetchDailySummary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _connect() async {
    await AppleHealthService.instance.requestAuthorization();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final onCard = cs.onSecondaryContainer;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: cs.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                M3EContainer.circle(
                  width: 28,
                  height: 28,
                  color: cs.primary,
                  child: Icon(
                    Symbols.ecg_heart_rounded,
                    size: 16,
                    color: cs.onPrimary,
                    fill: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '今日健康',
                    style: tt.titleMedium?.copyWith(
                      color: onCard,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_summary.hasAny && !_loading)
                  M3ETextButton(onPressed: _connect, child: const Text('连接')),
                M3EButton(
                  style: M3EButtonStyle.text,
                  size: M3EButtonSize.xs,
                  tooltip: '日历',
                  onPressed: () => context.push(AppRoutes.trainingCalendar),
                  child: Icon(Symbols.calendar_today_rounded, color: onCard),
                ),
                M3EButton(
                  style: M3EButtonStyle.text,
                  size: M3EButtonSize.xs,
                  tooltip: '刷新',
                  onPressed: _loading ? null : _refresh,
                  child: Icon(Symbols.refresh_rounded, color: onCard),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: M3ELoadingIndicator(),
                ),
              )
            else if (!_summary.hasAny)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                child: Text(
                  '授权苹果健康后，可查看步数、活动能量、体重与静息心率。',
                  style: tt.bodyMedium?.copyWith(
                    color: onCard.withValues(alpha: 0.72),
                  ),
                ),
              )
            else
              Row(
                children: [
                  _MetricRing(
                    icon: Symbols.steps_rounded,
                    value: _summary.steps == null
                        ? '—'
                        : formatCount(_summary.steps!.toInt()),
                    label: '步数',
                    progress: _ringProgress(_summary.steps, _stepGoal),
                  ),
                  _MetricRing(
                    icon: Symbols.local_fire_department_rounded,
                    value: _summary.activeEnergyKcal == null
                        ? '—'
                        : formatCount(_summary.activeEnergyKcal!.toInt()),
                    label: '热量',
                    progress: _ringProgress(
                      _summary.activeEnergyKcal,
                      _kcalGoal,
                    ),
                  ),
                  _MetricRing(
                    icon: Symbols.monitor_weight_rounded,
                    value: _summary.bodyMassKg == null
                        ? '—'
                        : _summary.bodyMassKg!.toStringAsFixed(1),
                    label: '体重',
                    progress: _summary.bodyMassKg == null ? 0 : 1,
                  ),
                  _MetricRing(
                    icon: Symbols.ecg_heart_rounded,
                    value: _summary.restingHeartRate == null
                        ? '—'
                        : _summary.restingHeartRate!.toInt().toString(),
                    label: '静息',
                    progress: _summary.restingHeartRate == null ? 0 : 1,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static double _ringProgress(double? value, double goal) {
    if (value == null || goal <= 0) return 0;
    final progress = (value / goal).clamp(0.0, 1.0);
    if (value > 0 && progress < 0.02) return 0.02;
    return progress;
  }
}

class _MetricRing extends StatelessWidget {
  const _MetricRing({
    required this.icon,
    required this.value,
    required this.label,
    required this.progress,
  });

  final IconData icon;
  final String value;
  final String label;
  final double progress;

  static const _ringSize = 58.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final onCard = cs.onSecondaryContainer;

    return Expanded(
      child: Column(
        children: [
          SizedBox(
            width: _ringSize,
            height: _ringSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return M3ECircularProgressIndicator(
                      value: value,
                      size: _ringSize,
                      strokeWidth: 6,
                      color: cs.primary,
                      backgroundColor: cs.primary.withValues(alpha: 0.18),
                      gapSize: 3,
                    );
                  },
                ),
                Icon(icon, size: 22, color: onCard),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              color: onCard,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: onCard.withValues(alpha: 0.64),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
