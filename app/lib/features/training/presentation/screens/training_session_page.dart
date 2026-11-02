import 'dart:async';

import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/features/coach/application/coach_provider.dart';
import 'package:app_flutter/features/coach/domain/coach_proposal.dart';
import 'package:app_flutter/features/settings/domain/entities/ai_settings.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/entities/training_set_kind.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_picker_page.dart';
import 'package:app_flutter/features/training/presentation/widgets/edit_bar.dart';
import 'package:app_flutter/features/training/presentation/widgets/rest_audio_settings_sheet.dart';
import 'package:app_flutter/features/training/presentation/widgets/rest_timer_bar.dart';
import 'package:app_flutter/features/training/presentation/widgets/session_exercise_list.dart';
import 'package:app_flutter/features/training/presentation/widgets/training_settings_sheet.dart';
import 'package:app_flutter/shared/widgets/app_menu_button.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/ui/format.dart';
import '../../../../core/ui/ui.dart';

/// 进行中训练会话页（主界面）。
///
/// 结构（自上而下）：
/// 1. AppBar：左菜单（设置 / 放弃）、中「已练」计时、右小旗（完成训练）。
/// 2. 动作卡片：收起时显示进度和下一组；展开后改次数、重量、完成。
/// 3. 底部悬浮：建议（直接加入）和添加动作。休息倒计时单独占底部一条。
class TrainingSessionPage extends ConsumerStatefulWidget {
  const TrainingSessionPage({super.key});

  @override
  ConsumerState<TrainingSessionPage> createState() =>
      _TrainingSessionPageState();
}

class _TrainingSessionPageState extends ConsumerState<TrainingSessionPage> {
  var _suggesting = false;

  Future<void> _finish() async {
    final ok = await ref.read(trainingSessionProvider.notifier).finish();
    if (!mounted) return;
    if (ok) {
      HapticFeedback.lightImpact();
      context.pop();
    } else {
      showExpressiveSnack(
        context: context,
        message: '网络不稳，训练已存在本地，可稍后重试',
        icon: Icons.error_outline,
      );
    }
  }

  /// 完成训练：有未完成组时先提示，确定后只保存已完成的组。
  Future<void> _confirmFinish() async {
    final active = ref.read(trainingSessionProvider).value;
    if (active == null) return;
    final leftover = [
      for (final e in active.exercises)
        ...e.sets.where((s) => s.completedAt == null),
    ].length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(leftover > 0 ? '还有组没完成' : '完成训练？'),
        content: Text(
          leftover > 0
              ? '还有 $leftover 组未完成。确定结束的话，这些组会被丢掉，只保存已完成的记录。'
              : '本次训练将被保存，之后无法再修改。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(leftover > 0 ? '仍然结束' : '完成训练'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _finish();
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃训练？'),
        content: const Text('已勾的组会丢掉，不会进历史。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(trainingSessionProvider.notifier).discard();
    if (mounted) context.pop();
  }

  /// 训练设置：M3E 底部弹层打开设置框架页。
  void _showTrainingSettings() {
    showM3EModalBottomSheet<void>(
      context: context,
      builder: (_) => const TrainingSettingsSheet(),
    );
  }

  /// 休息闹钟和音频：M3E 底部弹层打开设置框架页。
  void _showRestAudioSettings() {
    showM3EModalBottomSheet<void>(
      context: context,
      builder: (_) => const RestAudioSettingsSheet(),
    );
  }

  /// 顶部菜单：设置 / 闹钟音频 / 放弃。完成只留右上角的旗子。
  void _onMenuSelected(AppMenuEntry<int> entry) {
    switch (entry.value) {
      case 2:
        _showTrainingSettings();
      case 3:
        _showRestAudioSettings();
      case 4:
        _discard();
    }
  }

  Future<void> _openSuggestion() async {
    if (_suggesting) return;
    final session = ref.read(trainingSessionProvider).value;
    if (session == null) return;
    final empty = session.exercises.isEmpty;
    setState(() => _suggesting = true);
    try {
      final agent = await ref.read(coachAgentProvider.future);
      if (!mounted) return;
      if (empty) {
        final turn = await agent.fillEmptySession();
        if (!mounted) return;
        final proposal = turn.proposal;
        if (turn.error != null || proposal == null) {
          _suggestSnack(turn.error ?? '这次没排出动作，稍后再试', failed: true);
          return;
        }
        final count = await ref
            .read(trainingSessionProvider.notifier)
            .addPlannedExercises(_plannedExercises(proposal.exercises));
        if (!mounted) return;
        final note = turn.messages.isEmpty ? '' : turn.messages.first;
        _suggestSnack(
          count == 0
              ? '这些动作已经在这场训练里'
              : (note.isEmpty ? '已加入 $count 个动作' : '已加入 $count 个动作。$note'),
          failed: count == 0,
        );
      } else {
        final turn = await agent.suggestNext(
          exercises: _sessionContext(session.exercises),
        );
        if (!mounted) return;
        final suggestion = turn.suggestion;
        if (turn.error != null || suggestion == null) {
          _suggestSnack(turn.error ?? '这次没选出动作，稍后再试', failed: true);
          return;
        }
        final added = await ref
            .read(trainingSessionProvider.notifier)
            .addPlannedExercise(_plannedExercise(suggestion.exercise));
        if (!mounted) return;
        final reason = suggestion.reason.trim();
        _suggestSnack(
          added
              ? (reason.isEmpty
                    ? '已加入 ${suggestion.exercise.name}'
                    : '已加入 ${suggestion.exercise.name}。$reason')
              : '这个动作已经在这场训练里',
          failed: !added,
        );
      }
    } on AiNotConfiguredException {
      if (!mounted) return;
      _suggestSnack('先在设置里填上 AI', failed: true);
    } catch (error) {
      if (!mounted) return;
      _suggestSnack(userFacingErrorMessage(error), failed: true);
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  void _suggestSnack(String message, {bool failed = false}) {
    showExpressiveSnack(
      context: context,
      message: message,
      icon: failed ? Symbols.error_outline_rounded : Symbols.auto_awesome,
    );
  }

  List<Map<String, dynamic>> _sessionContext(List<TrainingExercise> exercises) {
    return [
      for (final exercise in exercises)
        {
          'exercise_id': exercise.exerciseId,
          'name': exercise.name,
          'sets_done': exercise.sets
              .where((set) => set.completedAt != null)
              .length,
          'sets_planned': exercise.sets.length,
          if (_lastDone(exercise) case final done?) ...{
            'last_weight_kg': ?done.weightKg,
            'last_reps': ?done.reps,
          },
          'sets': [
            for (final set in exercise.sets)
              if (set.completedAt != null)
                '${set.weightKg ?? '-'}kg×${set.reps ?? '-'}${set.rpe == null ? '' : ' RPE ${set.rpe}'}',
          ],
        },
    ];
  }

  TrainingSet? _lastDone(TrainingExercise exercise) {
    for (final set in exercise.sets.reversed) {
      if (set.completedAt != null &&
          (set.weightKg != null || set.reps != null)) {
        return set;
      }
    }
    return null;
  }

  List<TrainingExercise> _plannedExercises(List<CoachExercise> exercises) {
    return [for (final exercise in exercises) _plannedExercise(exercise)];
  }

  TrainingExercise _plannedExercise(CoachExercise exercise) {
    return TrainingExercise(
      exerciseId: exercise.exerciseId,
      name: exercise.name,
      imageUrl: exercise.imageUrl,
      exerciseType: exercise.exerciseType,
      notes: exercise.notes,
      restTargetSeconds: exercise.restTargetSeconds,
      sets: [
        for (final set in exercise.sets)
          TrainingSet(
            setNumber: set.setNumber,
            reps: set.reps,
            weightKg: set.weightKg,
            setKind:
                TrainingSetKind.values
                    .where((kind) => kind.name == set.setKind)
                    .firstOrNull ??
                TrainingSetKind.working,
            clientUuid: 'pending',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(trainingSessionProvider);
    // 键盘升起时底部编辑栏替换 FAB 区域。
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: GlassAppBar(
        title: const Center(
          child: Column(
            crossAxisAlignment: .center,
            mainAxisAlignment: .center,
            children: [
              SizedBox(
                width: 50,
                child: Divider(
                  height: 10,
                  thickness: 5,
                  radius: BorderRadius.all(Radius.circular(24)),
                ),
              ),
              _SessionElapsedTimer(),
            ],
          ),
        ),
        centerTitle: true,
        leading: AppMenuButton<int>(
          icon: Icons.more_horiz,
          iconSize: 32,
          style: M3EButtonStyle.text,
          size: .sm,
          circular: true,
          buttonPadding: EdgeInsets.zero,
          menuWidth: 200,
          onSelected: _onMenuSelected,
          items: [
            AppMenuEntry(value: 2, label: "训练设置"),
            AppMenuEntry(value: 3, label: "休息闹钟和音频"),
            AppMenuEntry(value: 4, label: "放弃训练", isDestructive: true),
          ],
        ),
        actions: [
          IconButton(
            iconSize: 32,
            onPressed: session.isLoading ? null : _confirmFinish,
            icon: const Icon(Symbols.flag_rounded),
            tooltip: '完成训练',
          ),
        ],
      ),
      body: Container(
        clipBehavior: Clip.hardEdge, // 关键：让 borderRadius 真正裁剪 child
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(42),
            topRight: Radius.circular(42),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 动作列表铺满整屏，浮动编辑栏叠加在其上。
            Positioned.fill(
              child: session.when(
                loading: () => const Center(child: M3ELoadingIndicator()),
                error: (error, _) =>
                    Center(child: Text(userFacingErrorMessage(error))),
                data: (active) {
                  if (active == null) {
                    return const Center(child: Text('未开始训练'));
                  }
                  if (active.exercises.isEmpty) {
                    return const Center(child: Text('点下方建议，按恢复和最近训练排这一堂'));
                  }
                  return SessionExerciseList(
                    exercises: active.exercises,
                    topPadding: context.appBarInset,
                  );
                },
              ),
            ),
            // 底部浮动编辑栏：贴屏幕左右两端。body 随 viewInsets 收缩，故 bottom:0
            // 即贴着键盘顶边，随键盘一起升降；AnimatedSwitcher 负责淡入/上滑出现、
            // 淡出/下滑消失。
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: keyboardVisible
                    ? const EditBar(key: ValueKey('edit-bar'))
                    : const SizedBox.shrink(key: ValueKey('edit-bar-empty')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: keyboardVisible
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 12,
                children: [
                  _SuggestButton(busy: _suggesting, onPressed: _openSuggestion),
                  FloatingActionButton(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.tertiary,
                    onPressed: () => showExercisePicker(context),
                    child: const Icon(Symbols.add_rounded),
                  ),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // 键盘升起时隐藏底部休息条，避免它挡住编辑栏。
      bottomNavigationBar: keyboardVisible ? null : const RestTimerBar(),
    );
  }
}

/// 建议按钮。思考时换成加载指示，背景是一层更浅的流动渐变。
class _SuggestButton extends StatefulWidget {
  const _SuggestButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  State<_SuggestButton> createState() => _SuggestButtonState();
}

class _SuggestButtonState extends State<_SuggestButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.busy) _motion.repeat();
  }

  @override
  void didUpdateWidget(covariant _SuggestButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!widget.busy && _motion.isAnimating) {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onPrimaryContainer;
    return M3EButton.icon(
      style: M3EButtonStyle.tonal,
      size: .md,
      onPressed: widget.busy ? null : widget.onPressed,
      icon: widget.busy
          ? const SizedBox(width: 18, height: 18, child: M3ELoadingIndicator())
          : Icon(Symbols.auto_awesome, fill: 1, color: ink),
      label: Text(widget.busy ? '思考中' : '建议'),
      decoration: M3EButtonDecoration(
        elevation: const WidgetStatePropertyAll(8),
        foregroundColor: WidgetStatePropertyAll(ink),
        backgroundColor: widget.busy
            ? null
            : WidgetStatePropertyAll(scheme.primaryContainer),
        backgroundBuilder: widget.busy
            ? (context, states, child) => _wash(scheme, child)
            : null,
      ),
    );
  }

  Widget _wash(ColorScheme scheme, Widget? child) {
    final pale = scheme.surfaceContainerLow;
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final shift = _motion.value * 2.4 - 1.2;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(shift - 1, -0.2),
              end: Alignment(shift, 0.4),
              colors: [
                Color.alphaBlend(scheme.primary.withValues(alpha: 0.10), pale),
                Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.26),
                  scheme.surface,
                ),
                Color.alphaBlend(scheme.tertiary.withValues(alpha: 0.18), pale),
                Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), pale),
              ],
            ),
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// AppBar 中央的训练计时文本。
///
/// 自持 1s Timer 独立重建，避免每秒 setState 重建整个会话页。
class _SessionElapsedTimer extends ConsumerStatefulWidget {
  const _SessionElapsedTimer();

  @override
  ConsumerState<_SessionElapsedTimer> createState() =>
      _SessionElapsedTimerState();
}

class _SessionElapsedTimerState extends ConsumerState<_SessionElapsedTimer>
    with WidgetsBindingObserver {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final startedAt = ref.read(trainingSessionProvider).value?.startedAt;
    if (startedAt != null) {
      _start(startedAt);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App 从后台切回前台时立即同步时间，避免后台挂起导致的显示延迟
    if (state == AppLifecycleState.resumed && _startedAt != null) {
      _tick();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  void _start(DateTime startedAt) {
    _stop();
    _startedAt = startedAt;
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
  }

  void _tick() {
    if (!mounted || _startedAt == null) return;
    setState(() => _elapsed = DateTime.now().difference(_startedAt!));
  }

  @override
  Widget build(BuildContext context) {
    // 监听会话状态：处理首次加载、会话重置或会话结束
    ref.listen(trainingSessionProvider, (previous, next) {
      final newStartedAt = next.value?.startedAt;
      final prevStartedAt = previous?.value?.startedAt;

      if (newStartedAt == null) {
        _stop();
        if (mounted) setState(() => _elapsed = Duration.zero);
      } else if (newStartedAt != prevStartedAt || _timer == null) {
        _start(newStartedAt);
      }
    });

    final formattedText = formatMmSs(_elapsed.inSeconds);
    final style = Theme.of(context).textTheme.titleMedium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '已练',
          style: style?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Text(
            formattedText,
            key: ValueKey<String>(formattedText),
            style: style?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
