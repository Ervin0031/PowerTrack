import 'package:app_flutter/features/training/application/exercise_editor_providers.dart';
import 'package:app_flutter/features/training/application/providers/active_set_edit_provider.dart';
import 'package:app_flutter/features/training/application/providers/set_edit_scope.dart';
import 'package:app_flutter/shared/widgets/app_menu_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 键盘升起时贴在键盘上方的编辑栏。
///
/// 左侧弹出菜单：自动更新、这组、全部未做。点菜单不抢走输入框焦点，键盘保持升起。
/// 自动更新会让同值且未完成的组跟着当前输入变。已完成的组不动。
/// 右侧「完成」收起键盘；不是自动更新时同时提交。
class EditBar extends ConsumerWidget {
  const EditBar({super.key});

  static String _label(SetEditMode mode) => switch (mode) {
    SetEditMode.auto => '✨ 自动更新',
    SetEditMode.thisSet => '这组',
    SetEditMode.allOpen => '全部未做',
  };

  static void _apply(WidgetRef ref, ActiveSetEdit edit, SetEditMode mode) {
    final notifier = ref.read(exerciseListEditorProvider);
    final reps = edit.field == EditField.reps ? int.tryParse(edit.text) : null;
    final weight = edit.field == EditField.weight ? double.tryParse(edit.text) : null;
    if (mode == SetEditMode.allOpen) {
      notifier.updateAllSets(edit.exerciseId, reps: reps, weightKg: weight);
      return;
    }
    final followMatching = mode == SetEditMode.auto;
    if (edit.field == EditField.reps) {
      notifier.updateSet(
        edit.exerciseId,
        edit.setNumber,
        reps: reps,
        followRemaining: false,
        followMatching: followMatching,
      );
    } else {
      notifier.updateSet(
        edit.exerciseId,
        edit.setNumber,
        weightKg: weight,
        followRemaining: false,
        followMatching: followMatching,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(setEditModeProvider);
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            TextFieldTapRegion(
              child: Focus(
                canRequestFocus: false,
                descendantsAreFocusable: false,
                child: AppMenuButton<SetEditMode>(
                  verticalPlacement: AppMenuVerticalPlacement.above,
                  horizontalPlacement: AppMenuHorizontalPlacement.start,
                  selectable: true,
                  menuWidth: 168,
                  elevation: 8,
                  onSelected: (entry) {
                    final value = entry.value;
                    if (value == ref.read(setEditModeProvider)) return;
                    ref.read(setEditModeProvider.notifier).select(value);
                    final edit = ref.read(activeSetEditNotifierProvider);
                    if (edit != null) _apply(ref, edit, value);
                  },
                  items: [
                    for (final value in SetEditMode.values)
                      AppMenuEntry(value: value, label: _label(value), selected: value == mode),
                  ],
                  child: Material(
                    color: cs.surfaceContainerHigh,
                    elevation: 3,
                    shadowColor: cs.shadow,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_label(mode), style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(width: 4),
                          Icon(Symbols.expand_less_rounded, size: 20, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            M3EButton(
              style: .elevated,

              decoration: M3EButtonDecoration(
                elevation: WidgetStatePropertyAll(4),
                backgroundColor: WidgetStatePropertyAll(cs.primaryContainer),
              ),
              onPressed: () {
                final edit = ref.read(activeSetEditNotifierProvider);
                final current = ref.read(setEditModeProvider);
                if (current != SetEditMode.auto && edit != null) {
                  _apply(ref, edit, current);
                }
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }
}
