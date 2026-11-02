import 'dart:math' as math;

import 'package:app_flutter/core/ui/app_radius.dart';
import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/features/coach/domain/coach_proposal.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/presentation/widgets/exercise_motion.dart';
import 'package:app_flutter/features/training/presentation/widgets/set_table.dart';
import 'package:app_flutter/shared/widgets/app_network_image.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

/// 教练提案里的动作列表。
///
/// 视觉与训练会话页的 `ExerciseCard` 对齐（缩略图 + 名称 + 副标题 + 折叠 +
/// 组表格），但整体只读：没有输入框、勾选、滑动删除和动作菜单。
class ProposalExerciseList extends StatelessWidget {
  const ProposalExerciseList({super.key, required this.exercises});

  final List<CoachExercise> exercises;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (exercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('教练这次没有安排动作', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      );
    }
    return M3ESegmentedList.builder(
      color: cs.surfaceContainer,
      listPadding: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exercises.length,
      itemBuilder: (context, index) => _ProposalExerciseCard(exercise: exercises[index]),
    );
  }
}

/// 单个提案动作卡片：默认展开，点击头部折叠/展开。
class _ProposalExerciseCard extends StatefulWidget {
  const _ProposalExerciseCard({required this.exercise});

  final CoachExercise exercise;

  @override
  State<_ProposalExerciseCard> createState() => _ProposalExerciseCardState();
}

class _ProposalExerciseCardState extends State<_ProposalExerciseCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final exercise = widget.exercise;
    final rest = exercise.restTargetSeconds;
    final notes = exercise.notes?.trim();
    final meta = ['${exercise.sets.length} 组', if (rest != null) '休息 ${formatRestSeconds(rest)}'].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AppNetworkImage(url: exercise.imageUrl, size: 48, radius: AppRadius.field),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(meta, style: textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                      if (notes != null && notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            notes,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SingleMotionBuilder(
                  motion: M3EMotion.standardSpatialFast.toMotion(),
                  value: _expanded ? 1 : 0,
                  builder: (context, t, _) {
                    final p = t.clamp(0.0, 1.0);
                    return Transform.rotate(
                      angle: p * math.pi,
                      child: Icon(Symbols.expand_more_rounded, color: Color.lerp(cs.onSurfaceVariant, cs.primary, p)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        M3EExpand(
          expanded: _expanded,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _SetPreview(exercise: exercise),
          ),
        ),
      ],
    );
  }
}

/// 只读组表格：列【组数 / 次数 / 重量(kg)】，列宽与 [SetTable] 保持一致。
class _SetPreview extends StatelessWidget {
  const _SetPreview({required this.exercise});

  final CoachExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (exercise.sets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('暂无组', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            spacing: 8,
            children: [
              HeaderCell(flex: 1, text: '组数'),
              HeaderCell(flex: 2, text: '次数'),
              HeaderCell(flex: 2, text: '重量(kg)'),
            ],
          ),
        ),
        for (final set in exercise.sets) _PreviewSetRow(set: set),
      ],
    );
  }
}

class _PreviewSetRow extends StatelessWidget {
  const _PreviewSetRow({required this.set});

  final CoachSet set;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = _kindStyle(cs, set.setKind);
    final weight = set.weightKg;

    return Row(
      spacing: 8,
      children: [
        Expanded(
          flex: 1,
          child: _PreviewCell(color: style.bg, text: style.label, textColor: style.fg, bold: true),
        ),
        Expanded(
          flex: 2,
          child: _PreviewCell(color: cs.surface, text: set.reps?.toString() ?? '—'),
        ),
        Expanded(
          flex: 2,
          child: _PreviewCell(color: cs.surface, text: weight == null ? '—' : '${formatWeight(weight)}kg'),
        ),
      ],
    );
  }
}

/// 组类型配色与会话页的组表格一致：正式用 surface，其余用容器色。
({Color bg, Color fg, String label}) _kindStyle(ColorScheme cs, String kind) => switch (kind) {
  'warmup' => (bg: cs.tertiaryContainer, fg: cs.onTertiaryContainer, label: '热身'),
  'cooldown' => (bg: cs.secondaryContainer, fg: cs.onSecondaryContainer, label: '放松'),
  'drop' => (bg: cs.errorContainer, fg: cs.onErrorContainer, label: '递减'),
  _ => (bg: cs.surface, fg: cs.onSurface, label: '正式'),
};

class _PreviewCell extends StatelessWidget {
  const _PreviewCell({required this.color, required this.text, this.textColor, this.bold = false});

  final Color color;
  final String text;
  final Color? textColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.field)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: bold ? FontWeight.w600 : null, height: 1),
        ),
      ),
    );
  }
}
