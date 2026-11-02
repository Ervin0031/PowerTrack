import 'dart:async';

import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/domain/bodyweight_load.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/shared/widgets/app_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroine/heroine.dart';
import 'package:material_ui/material_ui.dart';

/// 首页底部导航栏顶部的「训练中」胶囊。
///
/// 仅在进行中会话存在时由 [HomePage] 注入 [AppBottomNavigationBar.topWidget]。
/// 左：当前动作封面 + 名称 + 当前组/重量/次数；右：训练计时。
/// 整体用 [Heroine] 包裹，点击以缩放过渡「自动展开」进入训练会话页。
class TrainingTopWidget extends ConsumerStatefulWidget {
  const TrainingTopWidget({super.key, this.tag = 'training_session_top', this.padding});

  final Object tag;
  final EdgeInsets? padding;

  @override
  ConsumerState<TrainingTopWidget> createState() => _TrainingTopWidgetState();
}

class _TrainingTopWidgetState extends ConsumerState<TrainingTopWidget> {
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final active = ref.read(trainingSessionProvider).value;
    if (active == null) return;
    _startedAt = active.startedAt;
    _tick(active.startedAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick(active.startedAt));
  }

  void _restartIfNeeded(DateTime startedAt) {
    if (_startedAt == startedAt) return;
    _timer?.cancel();
    _startTimer();
  }

  void _tick(DateTime startedAt) {
    if (!mounted) return;
    setState(() => _elapsed = DateTime.now().difference(startedAt));
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(trainingSessionProvider).value;
    if (active == null) return const SizedBox.shrink();

    // 计时依赖 startedAt，会话切换时重启。
    final timerStart = active.startedAt;
    _restartIfNeeded(timerStart);

    final exercise = _currentExercise(active);
    final subtitle = _subtitle(exercise);
    final formattedText = formatMmSs(_elapsed.inSeconds);
    return Heroine(
      motion: Motion.linear(Durations.medium1),
      tag: widget.tag,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/training/session'),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                AppNetworkImage(url: exercise?.imageUrl, size: 42, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exercise?.name ?? '训练进行中',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: Text(
                        formatMmSs(_elapsed.inSeconds),
                        // ValueKey 保证内容变化时触发平滑渐变
                        key: ValueKey<String>(formattedText),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: Theme.of(context).colorScheme.primary,
                        ),
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
  }

  /// 当前动作：优先会话 [focusedExerciseId]；否则有未完成组的第一个；否则最后一个。
  TrainingExercise? _currentExercise(ActiveTraining active) {
    final exercises = active.exercises;
    if (exercises.isEmpty) return null;
    final focusedId = active.focusedExerciseId;
    if (focusedId != null) {
      for (final e in exercises) {
        if (e.exerciseId == focusedId) return e;
      }
    }
    for (final e in exercises) {
      if (e.sets.isNotEmpty && e.sets.any((s) => s.completedAt == null)) return e;
    }
    return exercises.last;
  }

  /// 格式化重量：
  /// 9.97903214022078 -> "10 kg"（若四舍五入到 1 位或 2 位）
  /// 50.0000000001    -> "50 kg"
  /// 52.5000000000    -> "52.5 kg"
  /// 52.25            -> "52.25 kg"
  String _formatWeight(double kg, {int maxDecimals = 2}) {
    // 1. 先按指定精度四舍五入并转为字符串
    final fixedStr = kg.toStringAsFixed(maxDecimals);
    // 2. 重新解析为 double，自动去除末尾的无效 0（如 "50.00" -> 50.0 -> "50"）
    final num = double.parse(fixedStr);

    final formatted = (num % 1 == 0) ? num.toInt().toString() : num.toString();
    return '$formatted kg'; // 如果不要空格写成 '$formatted kg' 即可
  }

  String _subtitle(TrainingExercise? exercise) {
    if (exercise == null) return '添加动作开始训练';
    if (exercise.sets.isEmpty) return '未添加组';

    final currentSet = exercise.sets.firstWhere((s) => s.completedAt == null, orElse: () => exercise.sets.last);

    final weight = currentSet.weightKg != null && currentSet.weightKg! > 0
        ? _formatWeight(currentSet.weightKg!)
        : (exercise.isBodyweight ? kBodyweightLoadLabel : '-');

    final reps = currentSet.reps != null ? '${currentSet.reps} 次' : '-';
    final done = exercise.sets.where((s) => s.completedAt != null).length;

    return '第 ${currentSet.setNumber} 组 · $weight × $reps  ($done/${exercise.sets.length})';
  }
}
