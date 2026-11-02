import 'package:app_flutter/features/exercises/application/providers/exercises_provider.dart';
import 'package:app_flutter/features/templates/application/providers/templates_provider.dart';
import 'package:app_flutter/features/templates/domain/entities/workout_template.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 模板列表筛选：范围用分段控件；难度 / 肌群 / 器械用横向芯片 + 底部弹层。
///
/// 避免多个下拉挤在一行时展开菜单溢出屏幕（电商 / 健身 App 常见做法）。
class TemplateFilterBar extends ConsumerWidget {
  const TemplateFilterBar({super.key});

  static const _scopes = [('all', '全部'), ('mine', '我的'), ('public', '公开')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(templatesFilterProvider);
    final muscleGroups = ref.watch(muscleGroupsProvider).value ?? const [];
    final equipment = ref.watch(equipmentListProvider).value ?? const [];
    final scopeIndex = _scopes.indexWhere((e) => e.$1 == filter.scope).clamp(0, _scopes.length - 1);
    final muscleLabel = muscleGroups.where((g) => g.id == filter.muscleGroupId).map((g) => g.name).firstOrNull;
    final equipmentLabel = equipment.where((e) => e.id == filter.equipmentId).map((e) => e.name).firstOrNull;
    final hasSecondary = filter.difficulty != null || filter.muscleGroupId != null || filter.equipmentId != null;

    return Column(
      spacing: 8,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = (constraints.maxWidth - 8) / _scopes.length;
            return M3EToggleButtonGroup(
              selectedIndex: scopeIndex,
              onSelectedIndexChanged: (index) {
                if (index == null) return;
                final next = _scopes[index].$1;
                if (next == filter.scope) return;
                ref.read(templatesFilterProvider.notifier).update((f) => f.copyWith(scope: next));
              },
              type: M3EButtonGroupType.connected,
              style: M3EButtonStyle.tonal,
              shape: M3EButtonShape.round,
              size: M3EButtonSize.sm,
              neighborSquish: false,
              actions: [for (final (_, label) in _scopes) M3EToggleButtonGroupAction(label: Text(label), width: w)],
            );
          },
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: filter.difficulty?.label ?? '难度',
                selected: filter.difficulty != null,
                onTap: () => _pickDifficulty(context, ref, filter.difficulty),
                onClear: filter.difficulty == null
                    ? null
                    : () => ref.read(templatesFilterProvider.notifier).update((f) => f.copyWith(clearDifficulty: true)),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: muscleLabel ?? '肌群',
                selected: filter.muscleGroupId != null,
                onTap: () => _pickIntOption(
                  context,
                  ref,
                  title: '选择肌群',
                  options: [for (final g in muscleGroups) (g.id, g.name)],
                  selectedId: filter.muscleGroupId,
                  onApply: (id) => ref
                      .read(templatesFilterProvider.notifier)
                      .update((f) => f.copyWith(muscleGroupId: id, clearMuscleGroup: id == null)),
                ),
                onClear: filter.muscleGroupId == null
                    ? null
                    : () =>
                          ref.read(templatesFilterProvider.notifier).update((f) => f.copyWith(clearMuscleGroup: true)),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: equipmentLabel ?? '器械',
                selected: filter.equipmentId != null,
                onTap: () => _pickIntOption(
                  context,
                  ref,
                  title: '选择器械',
                  options: [for (final e in equipment) (e.id, e.name)],
                  selectedId: filter.equipmentId,
                  onApply: (id) => ref
                      .read(templatesFilterProvider.notifier)
                      .update((f) => f.copyWith(equipmentId: id, clearEquipment: id == null)),
                ),
                onClear: filter.equipmentId == null
                    ? null
                    : () => ref.read(templatesFilterProvider.notifier).update((f) => f.copyWith(clearEquipment: true)),
              ),
              if (hasSecondary) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: '清除',
                  selected: false,
                  icon: Symbols.filter_alt_off_rounded,
                  onTap: () => ref
                      .read(templatesFilterProvider.notifier)
                      .update((f) => f.copyWith(clearDifficulty: true, clearMuscleGroup: true, clearEquipment: true)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDifficulty(BuildContext context, WidgetRef ref, TemplateDifficulty? current) async {
    final result = await showM3EModalBottomSheet<_PickResult<TemplateDifficulty?>>(
      context: context,
      builder: (_) => _FilterOptionSheet<TemplateDifficulty?>(
        title: '选择难度',
        options: [(null, '不限'), for (final d in TemplateDifficulty.values) (d, d.label)],
        selected: current,
      ),
    );
    if (!context.mounted || result == null) return;
    ref
        .read(templatesFilterProvider.notifier)
        .update((f) => f.copyWith(difficulty: result.value, clearDifficulty: result.value == null));
  }

  Future<void> _pickIntOption(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<(int, String)> options,
    required int? selectedId,
    required void Function(int? id) onApply,
  }) async {
    final result = await showM3EModalBottomSheet<_PickResult<int?>>(
      context: context,
      builder: (_) => _FilterOptionSheet<int?>(
        title: title,
        options: [(null, '不限'), for (final o in options) (o.$1, o.$2)],
        selected: selectedId,
      ),
    );
    if (!context.mounted || result == null) return;
    onApply(result.value);
  }
}

/// 弹层确认结果；与 barrier 关闭的 `null` 区分。
class _PickResult<T> {
  const _PickResult(this.value);
  final T value;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.onClear, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return M3EButton(
      style: selected ? M3EButtonStyle.tonal : M3EButtonStyle.outlined,
      shape: M3EButtonShape.round,
      size: M3EButtonSize.sm,
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 4)],
          Text(label),
          if (onClear != null) ...[
            const SizedBox(width: 2),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Symbols.close_rounded, size: 14, color: cs.onSurfaceVariant),
              ),
            ),
          ] else if (icon == null) ...[
            const SizedBox(width: 2),
            Icon(Symbols.keyboard_arrow_down_rounded, size: 16, color: cs.onSurfaceVariant),
          ],
        ],
      ),
    );
  }
}

class _FilterOptionSheet<T> extends StatelessWidget {
  const _FilterOptionSheet({required this.title, required this.options, required this.selected});

  final String title;
  final List<(T, String)> options;
  final T selected;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = options.indexWhere((e) => e.$1 == selected);

    return M3EBottomSheet(
      padding: EdgeInsets.zero,
      title: Text(title),
      actions: [M3EButton(onPressed: () => Navigator.pop(context), child: const Icon(Symbols.close_rounded, size: 20))],
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
        // 静态版用 Column，选项多会撑破弹层；builder 版是 ListView，超出可滚。
        child: M3ESegmentedList.builder(
          itemCount: options.length,
          selectedIndices: selectedIndex >= 0 ? {selectedIndex} : null,
          selectionMode: M3ESelectionMode.single,
          showSelectionCheckmark: true,
          physics: const ClampingScrollPhysics(),
          onTap: (index) {
            Navigator.pop(context, _PickResult<T>(options[index].$1));
          },
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(options[index].$2),
            );
          },
        ),
      ),
    );
  }
}
