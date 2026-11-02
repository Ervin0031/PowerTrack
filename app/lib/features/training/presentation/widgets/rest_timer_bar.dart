import 'dart:async';

import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/features/training/application/providers/rest_audio_cue_provider.dart';
import 'package:app_flutter/features/training/application/providers/rest_timer_settings_provider.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/application/rest_alert_service.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 底部组间休息计时条。
///
/// 任一动作有组完成（勾选「完成」）后出现，挂在 Scaffold 的 bottomNavigationBar：
/// 第一行左侧为状态文案、右侧为剩余倒计时（如 `1:30`），第二行为进度条。
/// RPE 红区会把目标时长加 60 秒。超过目标后继续显示超时并变红；下一组完成时归零重计。
///
/// 休息结束提醒：后台走系统本地通知；前台到 0 时用系统音效 + 震动。
class RestTimerBar extends ConsumerStatefulWidget {
  const RestTimerBar({super.key});

  @override
  ConsumerState<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends ConsumerState<RestTimerBar> {
  Timer? _ticker;
  DateTime? _anchor;
  DateTime? _lastCompletedAt;
  DateTime? _scheduledForCompletedAt;
  int? _lastScheduledTarget;
  bool _alertFiredForAnchor = false;
  bool _wasPositiveRemaining = false;

  @override
  void initState() {
    super.initState();
    // 挂载时可能已有完成的组，先同步一次副作用（timer / 通知调度）。
    _syncSideEffects();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 最近一次完成的组所属动作与完成时间。
  ({TrainingExercise? exercise, DateTime? at}) _latestCompleted(
    ActiveTraining? session,
  ) {
    TrainingExercise? exercise;
    DateTime? latest;
    if (session == null) return (exercise: null, at: null);
    for (final item in session.exercises) {
      for (final set in item.sets) {
        final at = set.completedAt;
        if (at != null && (latest == null || at.isAfter(latest))) {
          latest = at;
          exercise = item;
        }
      }
    }
    return (exercise: exercise, at: latest);
  }

  /// 当前生效的目标秒数（动作自定义 > 全局设置，再加 RPE 红区奖励）。
  int _currentEffectiveTarget() {
    final session = ref.read(trainingSessionProvider).value;
    final globalTarget = ref.read(restTimerSettingsProvider);
    if (globalTarget == null) return 0;
    final latest = _latestCompleted(session);
    return (latest.exercise?.restTargetSeconds ?? globalTarget) +
        (session?.restBonusSeconds ?? 0);
  }

  /// 副作用统一入口：由 ref.listen 回调驱动，不在 build 里执行。
  /// 负责：新完成事件 → 重启 ticker；提醒调度；计时关闭 → 停表取消通知。
  void _syncSideEffects() {
    final session = ref.read(trainingSessionProvider).value;
    final latest = _latestCompleted(session);
    final completedAt = latest.at;
    final globalTarget = ref.read(restTimerSettingsProvider);
    final cueEnabled = ref.read(restAudioCueEnabledProvider);

    if (completedAt == null || globalTarget == null) {
      _ticker?.cancel();
      _ticker = null;
      _lastCompletedAt = null;
      _anchor = null;
      if (_lastScheduledTarget != null) {
        _lastScheduledTarget = null;
        _scheduledForCompletedAt = null;
        unawaited(RestAlertService.instance.cancel());
      }
      return;
    }

    final target = latest.exercise?.restTargetSeconds ?? globalTarget;
    final effectiveTarget = target + (session?.restBonusSeconds ?? 0);

    // 检测到新的完成事件：以该时间点为起点开始倒计时。
    if (completedAt != _lastCompletedAt) {
      _lastCompletedAt = completedAt;
      _anchor = completedAt;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    }

    _syncAlert(
      completedAt: completedAt,
      effectiveTarget: effectiveTarget,
      exerciseName: latest.exercise?.name,
      cueEnabled: cueEnabled,
    );
  }

  void _onTick() {
    if (!mounted || _anchor == null) return;
    // 前台：刚从剩余 >0 跨到 ≤0 时响铃，并取消已调度的本地通知避免重复。
    final remaining =
        _currentEffectiveTarget() -
        DateTime.now().difference(_anchor!).inSeconds;
    if (ref.read(restAudioCueEnabledProvider) &&
        !_alertFiredForAnchor &&
        _wasPositiveRemaining &&
        remaining <= 0) {
      _alertFiredForAnchor = true;
      unawaited(RestAlertService.instance.notifyForegroundRestEnded());
    }
    if (remaining > 0) _wasPositiveRemaining = true;
    setState(() {});
  }

  void _syncAlert({
    required DateTime completedAt,
    required int effectiveTarget,
    required String? exerciseName,
    required bool cueEnabled,
  }) {
    if (!cueEnabled) {
      unawaited(RestAlertService.instance.cancel());
      _scheduledForCompletedAt = null;
      _lastScheduledTarget = null;
      return;
    }
    if (_scheduledForCompletedAt == completedAt && _lastScheduledTarget == effectiveTarget) {
      return;
    }
    _scheduledForCompletedAt = completedAt;
    _lastScheduledTarget = effectiveTarget;
    _alertFiredForAnchor = false;
    _wasPositiveRemaining = true;
    unawaited(
      RestAlertService.instance.scheduleRestEnd(
        endsAt: completedAt.add(Duration(seconds: effectiveTarget)),
        exerciseName: exerciseName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 副作用（timer 重启 / 通知调度）全部由 listen 回调驱动，build 只渲染。
    ref
      ..listen(trainingSessionProvider, (_, _) => _syncSideEffects())
      ..listen(restTimerSettingsProvider, (_, _) => _syncSideEffects())
      ..listen(restAudioCueEnabledProvider, (_, _) => _syncSideEffects());

    final session = ref.watch(trainingSessionProvider).value;
    final completedAt = _latestCompleted(session).at;
    final globalTarget = ref.watch(restTimerSettingsProvider);
    if (completedAt == null || globalTarget == null) {
      return const SizedBox.shrink();
    }

    final anchor = _anchor ?? completedAt;
    final bonus = session?.restBonusSeconds ?? 0;
    final effectiveTarget = _currentEffectiveTarget();

    final cs = Theme.of(context).colorScheme;
    final elapsed = DateTime.now().difference(anchor).inSeconds;
    final remaining = effectiveTarget - elapsed;
    final overtime = remaining < 0;
    final color = overtime ? cs.error : cs.primary;
    final progress = effectiveTarget <= 0
        ? 1.0
        : (elapsed / effectiveTarget).clamp(0.0, 1.0);
    final clock = overtime
        ? '+${formatMmSs(-remaining)}'
        : formatMmSs(remaining);

    return Material(
      color: cs.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          // 会话页用 Heroine 从底部胶囊展开。飞行中整页会被压进胶囊高度，
          // 这列只剩几像素，按自然高度排就会底部溢出。
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight < 1 || constraints.maxWidth < 1) {
                return const SizedBox.shrink();
              }
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            overtime
                                ? Symbols.timer_off_rounded
                                : Symbols.timer_rounded,
                            size: 18,
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              overtime
                                  ? '超时'
                                  : (bonus > 0 ? '休息 · 已加 $bonus 秒' : '休息'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.labelMedium?.copyWith(color: color),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            clock,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: color,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      M3ELinearWavyProgressIndicator(
                        value: progress,
                        color: color,
                        backgroundColor: cs.surfaceContainerHighest,
                        width: constraints.maxWidth,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
