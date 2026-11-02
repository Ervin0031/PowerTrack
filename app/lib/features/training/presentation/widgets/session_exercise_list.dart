import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/presentation/widgets/exercise_card.dart';
import 'package:app_flutter/features/training/presentation/widgets/exercise_motion.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 把连续且 `supersetId` 相同的动作收成一组，供超级组容器渲染。
List<ExerciseBlock> groupExercises(List<TrainingExercise> exercises) {
  if (exercises.isEmpty) return const [];
  final blocks = <ExerciseBlock>[];
  var current = <TrainingExercise>[exercises.first];
  var currentId = exercises.first.supersetId;
  for (var i = 1; i < exercises.length; i++) {
    final next = exercises[i];
    if (currentId != null && next.supersetId == currentId) {
      current.add(next);
      continue;
    }
    blocks.add(ExerciseBlock(supersetId: current.length > 1 ? currentId : null, exercises: current));
    current = [next];
    currentId = next.supersetId;
  }
  blocks.add(ExerciseBlock(supersetId: current.length > 1 ? currentId : null, exercises: current));
  return blocks;
}

class ExerciseBlock {
  const ExerciseBlock({required this.supersetId, required this.exercises});

  final int? supersetId;
  final List<TrainingExercise> exercises;

  bool get isSuperset => supersetId != null && exercises.length > 1;
}

/// 训练会话 / 模板编辑共用的动作列表，超级组包一层强调容器。
///
/// 新增动作从 0 高度弹簧展开，删除先收起再移出列表。
class SessionExerciseList extends StatefulWidget {
  const SessionExerciseList({
    super.key,
    required this.exercises,
    this.topPadding = 0,
    this.shrinkWrap = false,
    this.footer,
  });

  final List<TrainingExercise> exercises;
  final double topPadding;
  final bool shrinkWrap;

  /// 只在训练会话里用。模板编辑不传，列表保持原样。
  final Widget? footer;

  @override
  State<SessionExerciseList> createState() => _SessionExerciseListState();
}

class _ExerciseSlot {
  _ExerciseSlot(this.exercise, {this.appear = false});

  TrainingExercise exercise;
  bool appear;
  bool exiting = false;

  int get id => exercise.exerciseId;
}

class _SessionExerciseListState extends State<SessionExerciseList> {
  late List<_ExerciseSlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = [for (final exercise in widget.exercises) _ExerciseSlot(exercise)];
  }

  @override
  void didUpdateWidget(SessionExerciseList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(widget.exercises);
  }

  void _sync(List<TrainingExercise> next) {
    final previous = _slots;
    final byId = {for (final slot in previous) slot.id: slot};
    final result = <_ExerciseSlot>[];
    final seen = <int>{};

    for (final exercise in next) {
      final slot = byId[exercise.exerciseId];
      if (slot == null) {
        result.add(_ExerciseSlot(exercise, appear: true));
      } else {
        slot.exercise = exercise;
        slot.exiting = false;
        result.add(slot);
      }
      seen.add(exercise.exerciseId);
    }

    for (var i = 0; i < previous.length; i++) {
      final slot = previous[i];
      if (seen.contains(slot.id)) continue;
      slot.exiting = true;
      result.insert(i.clamp(0, result.length), slot);
    }
    _slots = result;
  }

  void _drop(int id) {
    if (!mounted) return;
    setState(() => _slots.removeWhere((slot) => slot.id == id && slot.exiting));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blocks = groupExercises([for (final slot in _slots) slot.exercise]);
    final exiting = {
      for (final slot in _slots)
        if (slot.exiting) slot.id,
    };
    final appearing = {
      for (final slot in _slots)
        if (slot.appear) slot.id,
    };
    final footer = widget.footer;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12, 16, 12, widget.shrinkWrap ? 12 : 120),
      itemCount: blocks.length + (footer == null ? 0 : 1),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      separatorBuilder: (_, _) => const SizedBox(height: 12),

      itemBuilder: (context, index) {
        if (index >= blocks.length) return footer!;
        final block = blocks[index];
        final list = M3ESegmentedList.builder(
          color: block.isSuperset ? cs.primaryContainer.withValues(alpha: 0.45) : cs.surfaceContainer,
          listPadding: EdgeInsets.zero,
          padding: EdgeInsets.zero,

          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: block.exercises.length,
          outerRadius: 28,
          innerRadius: 42,
          itemBuilder: (_, i) {
            final exercise = block.exercises[i];
            return M3EMotionReveal(
              key: ValueKey(exercise.exerciseId),
              show: !exiting.contains(exercise.exerciseId),
              appear: appearing.contains(exercise.exerciseId),
              onDismissed: () => _drop(exercise.exerciseId),
              child: ExerciseCard(exercise: exercise),
            );
          },
        );
        if (!block.isSuperset) return list;
        return DecoratedBox(
          decoration: BoxDecoration(
            // 外框 = 内层卡片圆角 + 每边 4px 内边距。
            borderRadius: BorderRadius.circular(AppRadius.card + 4),
            border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
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
      },
    );
  }
}
