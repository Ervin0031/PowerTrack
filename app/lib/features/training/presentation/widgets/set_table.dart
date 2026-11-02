import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/training/application/exercise_editor.dart';
import 'package:app_flutter/features/training/application/exercise_editor_providers.dart';
import 'package:app_flutter/features/training/application/providers/active_set_edit_provider.dart';
import 'package:app_flutter/features/training/application/providers/rest_timer_settings_provider.dart';
import 'package:app_flutter/features/training/application/providers/set_edit_scope.dart';
import 'package:app_flutter/features/training/domain/bodyweight_load.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/entities/training_set_kind.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/domain/strength.dart';
import 'package:app_flutter/features/training/presentation/widgets/rpe_collect_sheet.dart';
import 'package:app_flutter/shared/widgets/app_menu_button.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:motor/motor.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 次数上限（防误触乱输；常规力量训练组足够）。
const _kMaxReps = 999;

/// 重量上限 kg（硬拉人类纪录约 500kg）。
const _kMaxWeightKg = 500.0;

/// 组表格：列【组数 / 用时 / 次数 / 重量 / 完成】。
///
/// 表头与数据行共用同一套 flex / spacing，保证列对齐。
class SetTable extends ConsumerWidget {
  const SetTable({super.key, required this.exercise});

  final TrainingExercise exercise;

  /// 表头与数据行共用的列间距。
  static const _colSpacing = 8.0;

  /// 与 [M3EDismissibleCardStyle.padding] 水平内边距一致，避免表头相对内容偏移。
  static const _rowInset = EdgeInsets.symmetric(horizontal: 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final labels = trainingSetDisplayLabels(exercise.sets);
    final live =
        ref.watch(exerciseEditorKindProvider) == ExerciseEditorKind.session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Padding(
          padding: _rowInset,
          child: Row(
            spacing: _colSpacing,
            children: [
              const HeaderCell(flex: 1, text: '组数'),
              if (live) const HeaderCell(flex: 2, text: '用时'),
              const HeaderCell(flex: 2, text: '次数'),
              HeaderCell(
                flex: 2,
                text: '重量(${weightUnitLabel(exercise.weightUnit)})',
              ),
              if (live) const HeaderCell(flex: 1, text: '完成'),
            ],
          ),
        ),
        if (exercise.sets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('暂无组，点击 Add Set 添加'),
          )
        else
          M3EDismissibleCardColumn(
            itemCount: exercise.sets.length,
            style: M3EDismissibleCardStyle(
              // 透明底交给 [SetRow] 自绘，避免与动作卡片 surfaceContainer 糊成一片。
              color: Colors.transparent,
              elevation: 0,
              padding: EdgeInsets.zero,
              dismissThreshold: 0.3,
              neighbourPull: 12.0,

              secondaryBackground: Container(
                color: cs.error,
                alignment: Alignment.center,
                child: Icon(
                  Symbols.delete_rounded,
                  color: cs.onError,
                  size: 28,
                ),
              ),
            ),
            itemBuilder: (ctx, i) {
              final set = exercise.sets[i];
              return SetRow(
                key: ValueKey('${exercise.exerciseId}-${set.setNumber}'),
                exerciseId: exercise.exerciseId,
                set: set,
                displayLabel: labels[i],
                weightUnit: exercise.weightUnit,
                isBodyweight: exercise.isBodyweight,
              );
            },
            onDismiss: (i, direction) async {
              // 仅允许从右往左滑删除（LTR 下为 endToStart）。
              if (direction != DismissDirection.endToStart) return false;
              if (exercise.sets.length <= 1) {
                showExpressiveSnack(
                  context: context,
                  message: '至少保留一组，或删除整个动作',
                  icon: Icons.error_outline,
                );
                return false;
              }
              ref
                  .read(exerciseListEditorProvider)
                  .removeSet(exercise.exerciseId, exercise.sets[i].setNumber);
              return true;
            },
          ),
      ],
    );
  }
}

class HeaderCell extends StatelessWidget {
  const HeaderCell({super.key, required this.flex, required this.text});

  final int flex;
  final String text;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

/// 单行组的编辑控件。
///
/// 控制器在 [State.initState] 初始化一次，配合稳定 `key` 在父级重建时保留输入焦点与文本，
/// 避免每次按键触发 [TrainingSession] 更新后输入框被重置。
class SetRow extends ConsumerStatefulWidget {
  const SetRow({
    super.key,
    required this.exerciseId,
    required this.set,
    required this.displayLabel,
    this.weightUnit = 'kg',
    this.isBodyweight = false,
  });

  final int exerciseId;
  final TrainingSet set;
  final String displayLabel;
  final String weightUnit;
  final bool isBodyweight;

  @override
  ConsumerState<SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<SetRow> {
  late final TextEditingController _reps;
  late final TextEditingController _weight;
  final _repsFocus = FocusNode();
  final _weightFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(text: widget.set.reps?.toString() ?? '');
    _weight = TextEditingController(text: _weightText(widget.set.weightKg));
    _repsFocus.addListener(_handleFocus);
    _weightFocus.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.set.reps != widget.set.reps && !_repsFocus.hasFocus) {
      final next = widget.set.reps?.toString() ?? '';
      if (_reps.text != next) _reps.text = next;
    }
    if (!_weightFocus.hasFocus) {
      final next = _weightText(widget.set.weightKg);
      if (_weight.text != next) _weight.text = next;
    }
  }

  @override
  void dispose() {
    _repsFocus.removeListener(_handleFocus);
    _weightFocus.removeListener(_handleFocus);
    _reps.dispose();
    _weight.dispose();
    _repsFocus.dispose();
    _weightFocus.dispose();
    super.dispose();
  }

  /// 聚焦变化时登记/清除「当前编辑的组字段」，供键盘升起时的编辑栏使用。
  void _handleFocus() {
    final hasReps = _repsFocus.hasFocus;
    final hasWeight = _weightFocus.hasFocus;
    final notifier = ref.read(activeSetEditNotifierProvider.notifier);
    if (hasReps || hasWeight) {
      final controller = hasReps ? _reps : _weight;
      // 框架会在 onTap 之后改选区，下一帧再全选才能盖住已有值。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!(hasReps ? _repsFocus.hasFocus : _weightFocus.hasFocus)) return;
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      });
      notifier.update(
        ActiveSetEdit(
          exerciseId: widget.exerciseId,
          setNumber: widget.set.setNumber,
          field: hasReps ? EditField.reps : EditField.weight,
          text: hasReps ? _reps.text : _weight.text,
        ),
      );
    } else {
      // 失焦前把当前输入提交到 Provider：键盘收起触发列表回收时，
      // 行 State 会被重建并从 Provider 重新初始化，未提交的输入会丢成空白。
      _update();
      notifier.clear();
    }
  }

  String _weightText(double? kg) {
    if (kg != null && kg > 0) return formatWeight(kg, unit: widget.weightUnit);
    if (widget.isBodyweight) return kBodyweightLoadLabel;
    return '';
  }

  double? _parseWeight(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == kBodyweightLoadLabel) return null;
    final value = double.tryParse(trimmed);
    if (value == null) return null;
    final kg = fromDisplayWeight(value, widget.weightUnit);
    return kg > _kMaxWeightKg ? _kMaxWeightKg : kg;
  }

  /// [only] 有值时只写正在输入的那一列，避免打次数时把本行重量抄到其他组。
  /// 失焦提交不传 [only]，次数和重量一起落。已完成的组由编辑器跳过。
  void _update({EditField? only}) {
    var reps = int.tryParse(_reps.text);
    if (reps != null && reps > _kMaxReps) reps = _kMaxReps;
    final weight = _parseWeight(_weight.text);
    final editor = ref.read(exerciseListEditorProvider);
    final mode = ref.read(setEditModeProvider);
    if (mode == SetEditMode.allOpen) {
      editor.updateAllSets(
        widget.exerciseId,
        reps: only == EditField.weight ? null : reps,
        weightKg: only == EditField.reps ? null : weight,
      );
      return;
    }
    final followMatching = mode == SetEditMode.auto;
    if (only == EditField.reps) {
      editor.updateSet(
        widget.exerciseId,
        widget.set.setNumber,
        reps: reps,
        followRemaining: false,
        followMatching: followMatching,
      );
    } else if (only == EditField.weight) {
      editor.updateSet(
        widget.exerciseId,
        widget.set.setNumber,
        weightKg: weight,
        followRemaining: false,
        followMatching: followMatching,
      );
    } else {
      editor.updateSet(
        widget.exerciseId,
        widget.set.setNumber,
        reps: reps,
        weightKg: weight,
        followRemaining: false,
        followMatching: followMatching,
      );
    }
  }

  /// 输入变更：同步当前编辑状态；自动更新开启时立即写入。
  void _onChanged(EditField field, String text) {
    ref
        .read(activeSetEditNotifierProvider.notifier)
        .update(
          ActiveSetEdit(
            exerciseId: widget.exerciseId,
            setNumber: widget.set.setNumber,
            field: field,
            text: text,
          ),
        );
    if (ref.read(setEditModeProvider) == SetEditMode.auto) _update(only: field);
  }

  Color _rowColor(ColorScheme cs, bool done) {
    final rpe = widget.set.rpe;
    if (!done) return cs.surfaceContainerHighest;
    if (rpe != null && rpe >= kRpeFailure) {
      return cs.error.withValues(alpha: 0.22);
    }
    if (rpe != null) return cs.primary.withValues(alpha: 0.22);
    return cs.primary.withValues(alpha: 0.15);
  }

  void _adoptSuggestion() {
    final suggested = widget.set.suggestedWeightKg;
    if (suggested == null) return;
    _weight.text = formatWeight(suggested, unit: widget.weightUnit);
    ref
        .read(exerciseListEditorProvider)
        .applySuggestedWeight(widget.exerciseId, widget.set.setNumber);
  }

  Future<void> _onCompletePressed() async {
    final weightText = _weight.text.trim();
    final hasInput =
        _reps.text.trim().isNotEmpty ||
        (weightText.isNotEmpty && weightText != kBodyweightLoadLabel);
    if (!hasInput) {
      showExpressiveSnack(
        context: context,
        message: '请先输入次数或重量，再点击完成',
        icon: Icons.error_outline,
      );
      return;
    }
    final wasDone = widget.set.completedAt != null;
    _update();
    if (!wasDone) HapticFeedback.lightImpact();
    ref
        .read(exerciseListEditorProvider)
        .toggleSetDone(widget.exerciseId, widget.set.setNumber);
  }

  Future<void> _editRpe() async {
    final rpe = await showRpeCollectSheet(
      context,
      initial: widget.set.rpe ?? 8.0,
    );
    if (!mounted || rpe == null) return;
    final followUp = ref
        .read(exerciseListEditorProvider)
        .completeSetWithRpe(widget.exerciseId, widget.set.setNumber, rpe);
    if (followUp != null && mounted) _presentRpeFollowUp(followUp);
  }

  void _presentRpeFollowUp(RpeFollowUp followUp) {
    final advice = followUp.advice;
    if (advice.extraRestSeconds > 0) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    }
    if (advice.fatigueWarning) {
      HapticFeedback.heavyImpact();
      final message = advice.message;
      if (message == null) return;
      showExpressiveSnack(
        context: context,
        message: message,
        icon: Symbols.warning_rounded,
        duration: const Duration(seconds: 6),
      );
      return;
    }
    if (advice.message != null && advice.extraRestSeconds > 0) {
      showExpressiveSnack(
        context: context,
        message: advice.message!,
        icon: Symbols.timer_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final live =
        ref.watch(exerciseEditorKindProvider) == ExerciseEditorKind.session;
    final cs = Theme.of(context).colorScheme;
    final done = widget.set.completedAt != null;
    final fieldColor = cs.surface;
    final suggestion = widget.set.suggestedWeightKg;
    final showSuggestion = !done && _weight.text.isEmpty && suggestion != null;
    final showBodyweightHint =
        !done && _weight.text.isEmpty && widget.isBodyweight && !showSuggestion;
    final idle = cs.surfaceContainerHighest;
    final doneColor = _rowColor(cs, true);
    return SingleMotionBuilder(
      motion: M3EMotion.expressiveEffectsFast.toMotion(),
      value: done ? 1 : 0,
      builder: (context, t, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(idle, doneColor, t.clamp(0.0, 1.0)),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          spacing: SetTable._colSpacing,
          children: [
            Expanded(
              flex: 1,
              child: _SetKindMenu(
                displayLabel: widget.displayLabel,
                kind: widget.set.setKind,
                fieldColor: fieldColor,
                rpe: widget.set.rpe,
                completed: done,
                onRecordRpe:
                    done && widget.set.setKind != TrainingSetKind.warmup
                    ? _editRpe
                    : null,
                onSelected: (kind) => ref
                    .read(exerciseListEditorProvider)
                    .updateSet(
                      widget.exerciseId,
                      widget.set.setNumber,
                      setKind: kind,
                    ),
              ),
            ),
            if (live)
              RestField(
                value: widget.set.restSeconds,
                fieldColor: fieldColor,
                onChanged: (seconds) => ref
                    .read(exerciseListEditorProvider)
                    .updateSet(
                      widget.exerciseId,
                      widget.set.setNumber,
                      restSeconds: seconds,
                    ),
              ),
            NumberField(
              flex: 2,
              controller: _reps,
              focusNode: _repsFocus,
              fieldColor: fieldColor,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _MaxNumberFormatter(max: double.parse(_kMaxReps.toString())),
              ],
              onFieldSubmitted: () => _weightFocus.requestFocus(),
              onChanged: (text) => _onChanged(EditField.reps, text),
            ),
            NumberField(
              flex: 2,
              controller: _weight,
              focusNode: _weightFocus,
              fieldColor: fieldColor,
              textInputAction: TextInputAction.done,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                _WeightInputFormatter(),
                _MaxNumberFormatter(
                  max: toDisplayWeight(_kMaxWeightKg, widget.weightUnit),
                  decimals: true,
                ),
              ],
              hintText: showSuggestion
                  ? '建议: ${formatWeight(suggestion, unit: widget.weightUnit)}${weightUnitLabel(widget.weightUnit)}'
                  : showBodyweightHint
                  ? kBodyweightLoadLabel
                  : null,
              onTap: showSuggestion ? _adoptSuggestion : null,
              onFieldSubmitted: () {},
              onChanged: (text) {
                _onChanged(EditField.weight, text);
                setState(() {});
              },
            ),
            if (live)
              Expanded(
                flex: 1,
                child: M3EContainer(
                  done ? Shapes.softBurst : Shapes.square,
                  // m3e_core 的 M3EClipper.shouldReclip 恒返回 false，形状变化时
                  // ClipPath 不会重新裁剪；用随 done 变化的 key 强制重建该子树。
                  key: ValueKey(done),
                  height: 40,
                  color: done
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  clipBehavior: .hardEdge,
                  margin: EdgeInsets.symmetric(horizontal: 0),
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onCompletePressed,
                      child: Icon(
                        done ? Symbols.check_rounded : Symbols.check,
                        color: done ? cs.primaryFixed : cs.outline,
                        size: 24,
                        fill: done ? 1 : 0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 休息时长单元格：点击弹出双列滚轮（左分钟 0~59、右秒 0~55），
/// 右上角「确定」写入；下拉取消不改动。
class RestField extends ConsumerWidget {
  const RestField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.fieldColor,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final Color fieldColor;

  void _showPicker(BuildContext context, WidgetRef ref) {
    // 秒轮步进为 5，初始值需对齐到 5 的倍数；无值时用全局休息目标（关闭时取默认）。
    final target =
        value ??
        ref.read(restTimerSettingsProvider) ??
        RestTimerSettings.defaultSeconds;
    final initial = (target ~/ 5) * 5;
    showM3EModalBottomSheet<int>(
      context: context,
      builder: (_) => _ElapsedPickerSheet(initialSeconds: initial),
    ).then((picked) {
      if (picked != null) onChanged(picked);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Expanded(
      flex: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: () => _showPicker(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          alignment: Alignment.center,
          child: Text(
            formatRestSeconds(value),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

/// 耗时双列滚轮。确认返回秒数，下拉关闭返回 null。
class _ElapsedPickerSheet extends StatefulWidget {
  const _ElapsedPickerSheet({required this.initialSeconds});

  final int initialSeconds;

  @override
  State<_ElapsedPickerSheet> createState() => _ElapsedPickerSheetState();
}

class _ElapsedPickerSheetState extends State<_ElapsedPickerSheet> {
  static const _maxMinutes = 59;
  static const _secondStep = 5;
  static const _secondValues = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  late int _minutes;
  late int _seconds;
  late final FixedExtentScrollController _minuteCtrl;
  late final FixedExtentScrollController _secondCtrl;

  @override
  void initState() {
    super.initState();
    final aligned = (widget.initialSeconds ~/ _secondStep) * _secondStep;
    _minutes = (aligned ~/ 60).clamp(0, _maxMinutes);
    _seconds = aligned % 60;
    if (!_secondValues.contains(_seconds)) _seconds = 0;
    _minuteCtrl = FixedExtentScrollController(initialItem: _minutes);
    _secondCtrl = FixedExtentScrollController(
      initialItem: _secondValues.indexOf(_seconds),
    );
  }

  @override
  void dispose() {
    _minuteCtrl.dispose();
    _secondCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return M3EBottomSheet(
      title: const Text('耗时'),
      padding: EdgeInsets.zero,
      actions: [
        M3EButton(
          style: M3EButtonStyle.filled,
          size: M3EButtonSize.sm,
          onPressed: () => Navigator.pop(context, _minutes * 60 + _seconds),
          child: const Text('确定'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _minuteCtrl,
                        itemExtent: 40,
                        magnification: 1.05,
                        useMagnifier: true,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: (i) =>
                            setState(() => _minutes = i),
                        children: [
                          for (var m = 0; m <= _maxMinutes; m++)
                            Center(
                              child: Text(
                                '$m分钟',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _secondCtrl,
                        itemExtent: 40,
                        magnification: 1.05,
                        useMagnifier: true,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: (i) =>
                            setState(() => _seconds = _secondValues[i]),
                        children: [
                          for (final s in _secondValues)
                            Center(
                              child: Text(
                                '$s秒',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.flex,
    required this.controller,
    required this.onChanged,
    required this.fieldColor,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
    this.keyboardType = TextInputType.number,
    this.inputFormatters,
    this.onFieldSubmitted,
    this.hintText,
    this.onTap,
  });

  final int flex;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Color fieldColor;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final VoidCallback? onFieldSubmitted;
  final String? hintText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      flex: flex,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onTap: onTap,
        onFieldSubmitted: (_) => onFieldSubmitted?.call(),
        textInputAction: textInputAction,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textAlign: TextAlign.center,
        onTapOutside: (_) {},
        decoration: InputDecoration(
          fillColor: fieldColor,
          filled: true,
          isDense: true,
          hintText: hintText,
          hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.38),
          ),
          border: const OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.field)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 4,
          ),
        ),
      ),
    );
  }
}

/// 重量格：允许数字，或徒手动作的「自重」占位。
class _WeightInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty || text == kBodyweightLoadLabel) return newValue;
    if (RegExp(r'^[0-9.]+$').hasMatch(text)) return newValue;
    return oldValue;
  }
}

/// 拒绝超过 [max] 的数值；[decimals] 时允许输入中的尾随小数点。
class _MaxNumberFormatter extends TextInputFormatter {
  _MaxNumberFormatter({required this.max, this.decimals = false});

  final double max;
  final bool decimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty || text == kBodyweightLoadLabel) return newValue;
    if (decimals) {
      if (text == '.') return newValue;
      if (text.endsWith('.')) {
        final head = double.tryParse(text.substring(0, text.length - 1));
        if (head == null || head > max) return oldValue;
        return newValue;
      }
      // 最多一个小数点。
      if ('.'.allMatches(text).length > 1) return oldValue;
      final value = double.tryParse(text);
      if (value == null || value > max) return oldValue;
      return newValue;
    }
    final value = int.tryParse(text);
    if (value == null || value > max) return oldValue;
    return newValue;
  }
}

/// 组数菜单里多出来的一项：记下 RPE，不占组行高度。
class _SetMenuValue {
  const _SetMenuValue.kind(this.kind) : recordRpe = false;
  const _SetMenuValue.rpe() : kind = null, recordRpe = true;

  final TrainingSetKind? kind;
  final bool recordRpe;
}

/// 组数格：点击弹出组类型菜单；完成且有 RPE 时按热力图上色。
class _SetKindMenu extends StatelessWidget {
  const _SetKindMenu({
    required this.displayLabel,
    required this.kind,
    required this.fieldColor,
    required this.onSelected,
    this.onRecordRpe,
    this.rpe,
    this.completed = false,
  });

  final String displayLabel;
  final TrainingSetKind kind;
  final Color fieldColor;
  final ValueChanged<TrainingSetKind> onSelected;
  final VoidCallback? onRecordRpe;
  final double? rpe;
  final bool completed;

  Color _fillColor(ColorScheme cs) {
    if (completed && rpe != null && kind == TrainingSetKind.working) {
      if (rpe! >= kRpeFailure) return cs.error;
      if (rpe! >= kRpeRedZone) return Color.lerp(cs.error, cs.primary, 0.2)!;
      return cs.primary;
    }
    return switch (kind) {
      TrainingSetKind.working => fieldColor,
      TrainingSetKind.warmup => cs.tertiaryContainer,
      TrainingSetKind.cooldown => cs.secondaryContainer,
      TrainingSetKind.drop => cs.errorContainer,
    };
  }

  Color _fgColor(ColorScheme cs) {
    if (completed && rpe != null && kind == TrainingSetKind.working) {
      return rpe! >= kRpeFailure ? cs.onError : cs.onPrimary;
    }
    return switch (kind) {
      TrainingSetKind.working => cs.onSurface,
      TrainingSetKind.warmup => cs.onTertiaryContainer,
      TrainingSetKind.cooldown => cs.onSecondaryContainer,
      TrainingSetKind.drop => cs.onErrorContainer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppMenuButton<_SetMenuValue>(
      selectable: true,
      items: [
        for (final option in TrainingSetKind.values)
          AppMenuEntry(
            value: _SetMenuValue.kind(option),
            label: option.label,
            selected: option == kind,
          ),
        if (onRecordRpe != null)
          AppMenuEntry(
            value: const _SetMenuValue.rpe(),
            label: rpe == null ? '记 RPE' : 'RPE ${formatRpe(rpe!)}',
          ),
      ],
      onSelected: (entry) {
        final value = entry.value;
        if (value.recordRpe) {
          onRecordRpe?.call();
          return;
        }
        final next = value.kind;
        if (next != null) onSelected(next);
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _fillColor(cs),
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            displayLabel,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _fgColor(cs),
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
