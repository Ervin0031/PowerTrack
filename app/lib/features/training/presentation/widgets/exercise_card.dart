import 'dart:math' as math;

import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/training/application/exercise_editor.dart';
import 'package:app_flutter/features/training/application/exercise_editor_providers.dart';
import 'package:app_flutter/features/training/application/providers/rest_timer_settings_provider.dart';
import 'package:app_flutter/features/training/domain/bodyweight_load.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/domain/strength.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_picker_page.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_stats_page.dart';
import 'package:app_flutter/features/training/presentation/widgets/exercise_motion.dart';
import 'package:app_flutter/features/training/presentation/widgets/rest_duration_picker_sheet.dart';
import 'package:app_flutter/features/training/presentation/widgets/set_table.dart';
import 'package:app_flutter/shared/widgets/app_menu_button.dart';
import 'package:app_flutter/shared/widgets/app_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

/// 卡片刚展开时滚进可视区域，避免练完一个动作后下一张还在屏幕外。
class _BringIntoView extends StatefulWidget {
  const _BringIntoView({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_BringIntoView> createState() => _BringIntoViewState();
}

class _BringIntoViewState extends State<_BringIntoView> {
  @override
  void didUpdateWidget(_BringIntoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active || oldWidget.active) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.05,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 单个动作卡片：由会话 [ActiveTraining.focusedExerciseId] 控制展开。
///
/// 同一时间只展开一个动作（表示当前在练）；点击 header 切换焦点。
/// `···` 菜单独立于 header 的点击区，避免误触折叠。
/// 展开、收起和组数变化走 M3E 空间弹簧（[M3EExpand] / [M3ESpringSize]）。
class ExerciseCard extends ConsumerWidget {
  const ExerciseCard({super.key, required this.exercise});

  final TrainingExercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final focusedId = ref.watch(focusedExerciseIdProvider);
    final expanded = focusedId == exercise.exerciseId;
    final live = ref.watch(exerciseEditorKindProvider) == ExerciseEditorKind.session;
    final oneRm = estimated1rmFromExercise(exercise);
    final unit = weightUnitLabel(exercise.weightUnit);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        if (exercise.notes != null && exercise.notes!.trim().isNotEmpty)
          Text(exercise.notes!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        SetTable(exercise: exercise),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: M3EButton.icon(
                onPressed: () => ref.read(exerciseListEditorProvider).addSet(exercise.exerciseId),
                icon: const Icon(Symbols.add_rounded),
                label: const Text('追加一组'),
              ),
            ),
            if (live)
              M3EButton.icon(
                style: .tonal,
                onPressed: () => _openStats(context),
                icon: const Icon(Symbols.monitoring_rounded),
                tooltip: '趋势数据',
                label: const Text('数据图表'),
              ),
          ],
        ),
      ],
    );

    return _BringIntoView(
      active: expanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => ref.read(exerciseListEditorProvider).toggleExerciseExpanded(exercise.exerciseId),
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                    child: Row(
                      children: [
                        AppNetworkImage(url: exercise.imageUrl, size: 48, radius: 10),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SingleMotionBuilder(
                                motion: M3EMotion.standardSpatialFast.toMotion(),
                                value: expanded ? 1 : 0,
                                builder: (context, t, _) {
                                  final p = t.clamp(0.0, 1.0);
                                  return Text(
                                    exercise.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.lerp(FontWeight.w400, FontWeight.w600, p),
                                      color: Color.lerp(cs.onSurface, cs.primary, p),
                                    ),
                                  );
                                },
                              ),
                              if ((expanded ? _expandedSubtitle(exercise, oneRm, unit) : exerciseProgressLine(exercise))
                                  case final subtitle when subtitle.isNotEmpty)
                                Text(
                                  subtitle,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        SingleMotionBuilder(
                          motion: M3EMotion.standardSpatialFast.toMotion(),
                          value: expanded ? 1 : 0,
                          builder: (context, t, _) {
                            final p = t.clamp(0.0, 1.0);
                            return Transform.rotate(
                              angle: p * math.pi,
                              child: Icon(
                                Symbols.expand_more_rounded,
                                color: Color.lerp(cs.onSurfaceVariant, cs.primary, p),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: AppMenuButton<String>(
                  icon: Symbols.more_horiz_rounded,
                  iconSize: 32,
                  style: M3EButtonStyle.text,
                  size: .sm,
                  circular: true,
                  buttonPadding: EdgeInsets.zero,
                  menuWidth: 200,
                  semanticLabel: '更多',
                  items: [
                    const AppMenuEntry(value: 'replace', label: '替换动作', icon: Symbols.swap_horiz_rounded),
                    const AppMenuEntry(
                      value: 'delete',
                      label: '删除动作',
                      icon: Symbols.delete_rounded,
                      isDestructive: true,
                    ),
                    const AppMenuEntry(value: 'rest', label: '休息时间', icon: Symbols.timer_rounded),
                    AppMenuEntry(
                      value: 'notes',
                      label: exercise.notes == null || exercise.notes!.trim().isEmpty ? '添加备注' : '编辑备注',
                      icon: Symbols.sticky_note_2_rounded,
                    ),
                    const AppMenuEntry(value: 'unit', label: '修改单位', icon: Symbols.weight_rounded),
                    if (live) const AppMenuEntry(value: 'trend', label: '趋势数据', icon: Symbols.monitoring_rounded),
                  ],
                  onSelected: (entry) => _onMenuSelected(context, ref, entry.value),
                ),
              ),
            ],
          ),
          M3EExpand(
            expanded: expanded,
            child: Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: body),
          ),
        ],
      ),
    );
  }

  void _onMenuSelected(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'replace':
        _replace(context);
      case 'delete':
        ref.read(exerciseListEditorProvider).removeExercise(exercise.exerciseId);
      case 'rest':
        _editRest(context, ref);
      case 'notes':
        _editNotes(context, ref);
      case 'unit':
        _editUnit(context, ref);
      case 'trend':
        _openStats(context);
    }
  }

  void _openStats(BuildContext context) {
    context.push(
      AppRoutes.exerciseStatsOf(exercise.exerciseId),
      extra: ExerciseStatsArgs(name: exercise.name, weightUnit: exercise.weightUnit),
    );
  }

  void _replace(BuildContext context) {
    showExercisePicker(context, replaceExerciseId: exercise.exerciseId);
  }

  Future<void> _editRest(BuildContext context, WidgetRef ref) async {
    final global = ref.read(restTimerSettingsProvider) ?? RestTimerSettings.defaultSeconds;
    final picked = await showM3EModalBottomSheet<int>(
      context: context,
      builder: (_) => RestDurationPickerSheet(initialSeconds: exercise.restTargetSeconds ?? global),
    );
    if (picked == null || !context.mounted) return;
    ref.read(exerciseListEditorProvider).updateExercise(exercise.exerciseId, restTargetSeconds: picked);
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final notes = await showM3EModalBottomSheet<String>(
      context: context,
      builder: (_) => _ExerciseNoteSheet(initial: exercise.notes ?? ''),
    );
    if (notes == null || !context.mounted) return;
    ref
        .read(exerciseListEditorProvider)
        .updateExercise(exercise.exerciseId, notes: notes.trim().isEmpty ? null : notes.trim());
  }

  Future<void> _editUnit(BuildContext context, WidgetRef ref) async {
    final unit = await showM3EModalBottomSheet<String>(
      context: context,
      builder: (_) => _WeightUnitSheet(current: exercise.weightUnit),
    );
    if (unit == null || !context.mounted) return;
    ref.read(exerciseListEditorProvider).updateExercise(exercise.exerciseId, weightUnit: unit);
  }
}

class _ExerciseNoteSheet extends StatefulWidget {
  const _ExerciseNoteSheet({required this.initial});

  final String initial;

  @override
  State<_ExerciseNoteSheet> createState() => _ExerciseNoteSheetState();
}

class _ExerciseNoteSheetState extends State<_ExerciseNoteSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // isScrollControlled sheet 默认不跟键盘上移，需用 viewInsets 垫高。
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: M3EBottomSheet(
        padding: EdgeInsets.all(0),
        title: const Text('动作备注'),
        actions: [
          M3EButton(
            style: M3EButtonStyle.filled,
            size: M3EButtonSize.sm,
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('保存'),
          ),
        ],
        child: TextField(
          controller: _controller,
          maxLines: 4,
          minLines: 3,
          autofocus: true,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '写一点关于这个动作的备注',
            filled: true,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeightUnitSheet extends StatelessWidget {
  const _WeightUnitSheet({required this.current});

  final String current;

  static const _units = ['kg', 'lb'];

  @override
  Widget build(BuildContext context) {
    final selected = _units.indexOf(current);

    return M3EBottomSheet(
      padding: EdgeInsets.zero,
      title: const Text('重量单位'),
      child: M3ESegmentedList(
        itemCount: _units.length,
        selectedIndices: selected >= 0 ? {selected} : const <int>{},
        selectionMode: M3ESelectionMode.single,
        showSelectionCheckmark: true,
        onTap: (index) => Navigator.pop(context, _units[index]),
        itemBuilder: (context, index) {
          final unit = _units[index];

          return ListTile(title: Text(unit == 'kg' ? '公斤 (kg)' : '磅 (lb)'));
          // return Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          //   child: Text(unit == 'kg' ? '公斤 (kg)' : '磅 (lb)'),
          // );
        },
      ),
    );
  }
}

/// 收起时看得到练到哪、下一组多重。展开后组表已经写出这些，这里改显示 1RM 和休息目标。
String exerciseProgressLine(TrainingExercise exercise) {
  final total = exercise.sets.length;
  if (total == 0) return '还没有组';
  final done = exercise.sets.where((set) => set.completedAt != null).length;
  if (done == total) return '$done/$total 完成';
  TrainingSet? next;
  for (final set in exercise.sets) {
    if (set.completedAt == null) {
      next = set;
      break;
    }
  }
  return '$done/$total · 下一组 ${_setLoad(exercise, next!)}';
}

String _expandedSubtitle(TrainingExercise exercise, double? oneRm, String unit) {
  final parts = <String>[
    if (oneRm != null) '估 1RM ${formatWeight(oneRm, unit: exercise.weightUnit)}$unit',
    if (exercise.restTargetSeconds != null) '休息 ${formatRestSeconds(exercise.restTargetSeconds)}',
  ];
  return parts.join(' · ');
}

String _setLoad(TrainingExercise exercise, TrainingSet set) {
  final unit = weightUnitLabel(exercise.weightUnit);
  final weight = set.weightKg;
  final reps = set.reps;
  if (weight != null && weight > 0 && reps != null) {
    return '${formatWeight(weight, unit: exercise.weightUnit)}$unit × $reps';
  }
  if (weight != null && weight > 0) {
    return '${formatWeight(weight, unit: exercise.weightUnit)}$unit';
  }
  if (exercise.isBodyweight && reps != null) {
    return '$kBodyweightLoadLabel × $reps';
  }
  if (reps != null) return '$reps 次';
  final suggested = set.suggestedWeightKg;
  if (suggested != null && suggested > 0) {
    return '建议 ${formatWeight(suggested, unit: exercise.weightUnit)}$unit';
  }
  return '待填';
}
