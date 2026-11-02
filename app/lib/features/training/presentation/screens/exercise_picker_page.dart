import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/features/exercises/application/providers/exercises_provider.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/exercises/presentation/screens/exercises_page.dart';
import 'package:app_flutter/features/training/application/exercise_editor_providers.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showExercisePicker(
  BuildContext context, {
  int? replaceExerciseId,
}) {
  // 底部弹层挂在根导航上，看不到页面里的 ProviderScope 覆盖。
  // 模板编辑靠这层覆盖把添加动作写进草稿，不带上就会写进训练会话或直接无效。
  final container = ProviderScope.containerOf(context);
  return showModalBottomSheet<void>(
    isScrollControlled: true,
    useSafeArea: true,
    context: context,
    clipBehavior: Clip.hardEdge,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: ExercisePickerPage(replaceExerciseId: replaceExerciseId),
    ),
  );
}

/// 动作选择库页面（多选）。
///
/// 结构复用动作库列表与 [ExerciseFilterBar]，区别在于：
/// - 列表项右侧为选择圈，点击切换选中态。
/// - 选中动作后底部显示操作条：单选只有「添加动作」；多选（≥2）时再带出
///   「添加超级组」，出现/消失带尺寸过渡。
class ExercisePickerPage extends ConsumerStatefulWidget {
  const ExercisePickerPage({super.key, this.replaceExerciseId});

  /// 非空时为「替换动作」：单选一个未在会话中的动作后替换 [replaceExerciseId]。
  final int? replaceExerciseId;

  @override
  ConsumerState<ExercisePickerPage> createState() => _ExercisePickerPageState();
}

class _ExercisePickerPageState extends ConsumerState<ExercisePickerPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final Map<int, Exercise> _selected = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 和动作库共用一份筛选。上次的搜索还在时，这个输入框是空的，列表却是空的。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(exercisesFilterProvider) == const ExercisesFilter()) return;
      ref.read(exercisesFilterProvider.notifier).state = const ExercisesFilter();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(exercisesControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    ref
        .read(exercisesFilterProvider.notifier)
        .update((f) => f.copyWith(search: value.trim()));
  }

  /// 回车。文字没变时筛选不会重新拉，空列表或一直转圈就再要一次。
  void _onSearchSubmitted(String value) {
    final search = value.trim();
    final filter = ref.read(exercisesFilterProvider);
    final current = ref.read(exercisesControllerProvider);
    if (filter.search != search) {
      _onSearchChanged(search);
      return;
    }
    if (current.isLoading || (current.value?.items.isEmpty ?? true)) {
      ref.invalidate(exercisesControllerProvider);
    }
  }

  bool get _replacing => widget.replaceExerciseId != null;

  void _toggle(Exercise exercise, Set<int> addedIds) {
    // 已添加进当前会话的动作不可重复选择。
    if (addedIds.contains(exercise.id)) return;
    setState(() {
      if (_replacing) {
        _selected
          ..clear()
          ..[exercise.id] = exercise;
        return;
      }
      if (_selected.containsKey(exercise.id)) {
        _selected.remove(exercise.id);
      } else {
        _selected[exercise.id] = exercise;
      }
    });
  }

  Future<void> _add({required bool asSuperset}) async {
    if (_selected.isEmpty) return;
    if (_replacing) {
      final next = _selected.values.first;
      final ok = await ref
          .read(exerciseListEditorProvider)
          .replaceExercise(widget.replaceExerciseId!, next);
      if (!mounted) return;
      if (!ok) {
        showExpressiveSnack(
          context: context,
          message: '该动作已在本次训练中',
          icon: Symbols.error_outline_rounded,
        );
        return;
      }
      context.pop();
      return;
    }
    // 超级组至少两个动作才成立。
    if (asSuperset && _selected.length < 2) return;
    final list = _selected.values.toList();
    if (asSuperset) {
      // 同一批动作赋相同 supersetId，标记为一组超级组（轻量分组，仅打标记）。
      final supersetId = _selected.keys.reduce((a, b) => a + b);
      ref
          .read(exerciseListEditorProvider)
          .addExercises(list, supersetId: supersetId);
    } else {
      ref.read(exerciseListEditorProvider).addExercises(list);
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exercisesControllerProvider);
    ref.listen(exercisesControllerProvider, (previous, next) {
      final previousFilter = previous?.value?.filter;
      final nextFilter = next.value?.filter;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        if (previousFilter != nextFilter) {
          _scrollController.jumpTo(0);
          return;
        }
        final position = _scrollController.position;
        if (position.hasContentDimensions &&
            position.pixels > position.maxScrollExtent) {
          position.jumpTo(position.maxScrollExtent);
        }
      });
    });
    final hasSelection = _selected.isNotEmpty;
    // 至少两个动作才允许组超级组。
    final canSuperset = _selected.length >= 2;
    // 当前会话已添加的动作，列表中禁用不可重复选择。
    final addedIds = ref.watch(editorExerciseIdsProvider);

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 120,

        title: AppSearchBar(
          padding: EdgeInsets.symmetric(horizontal: 4),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Symbols.keyboard_arrow_down),
          ),
          controller: _searchController,
          hintText: '搜索',
          onChanged: _onSearchChanged,
          onSubmitted: _onSearchSubmitted,
        ),

        bottom: PreferredSize(
          preferredSize: .fromHeight(42),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: const ExerciseFilterBar(),
          ),
        ),
      ),
      body: _pickerBody(state, addedIds),
      bottomNavigationBar: hasSelection
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  spacing: 12,
                  children: [
                    // 单选时不占位；多选时按钮从左侧展开，动作按钮随之让出宽度。
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      alignment: Alignment.centerLeft,
                      clipBehavior: Clip.hardEdge,
                      child: !_replacing && canSuperset
                          ? M3EButton(
                              size: .md,
                              style: M3EButtonStyle.tonal,
                              onPressed: () => _add(asSuperset: true),
                              child: Text('添加超级组 (${_selected.length})'),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: M3EButton(
                        size: .md,
                        onPressed: () => _add(asSuperset: false),
                        child: Text(
                          _replacing ? '替换动作' : '添加动作 (${_selected.length})',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _pickerBody(AsyncValue<ExercisesPageState> state, Set<int> addedIds) {
    // 换筛选时保留当前列表。默认的 loading 分支会把整表换成转圈，看起来像数据没了。
    final page = state.value;
    if (page == null) {
      if (state.hasError) {
        return AppErrorState(
          error: state.error!,
          onRetry: () => ref.invalidate(exercisesControllerProvider),
        );
      }
      return const Center(child: M3ELoadingIndicator());
    }
    final s = page;
    return M3ESegmentedList.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      listPadding: EdgeInsets.only(bottom: 24),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      itemCount: s.items.length + (s.hasMore ? 1 : 0),
      emptyBuilder: const Center(
        child: AppEmptyState(
          icon: Symbols.fitness_center_rounded,
          title: '暂无动作',
        ),
      ),
      onTap: (index) {
        if (index < s.items.length) _toggle(s.items[index], addedIds);
      },
      itemBuilder: (context, index) {
        if (index < s.items.length) {
          return _PickerItem(
            exercise: s.items[index],
            selected: _selected.containsKey(s.items[index].id),
            added: addedIds.contains(s.items[index].id),
            onTap: () => _toggle(s.items[index], addedIds),
          );
        }
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: M3ELoadingIndicator()),
        );
      },
    );
  }
}

/// 选择库列表项：封面图 + 中英文名 + 右侧选择圈。
class _PickerItem extends StatelessWidget {
  const _PickerItem({
    required this.exercise,
    required this.selected,
    required this.added,
    required this.onTap,
  });

  final Exercise exercise;
  final bool selected;
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 已添加的动作：显示已勾选但置灰，且不可再次选择。
    final disabled = added;
    final effectiveSelected = selected || added;

    return Row(
      children: [
        AppNetworkImage(url: exercise.imageUrl, size: 56, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: disabled ? colorScheme.outline : null,
                ),
              ),
              if (exercise.nameEn != null)
                Text(
                  exercise.nameEn!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: disabled ? colorScheme.outline : null,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          ),
          onPressed: disabled ? null : onTap,
          icon: Icon(
            effectiveSelected
                ? Symbols.check_circle_rounded
                : Symbols.circle_rounded,
            color: effectiveSelected
                ? colorScheme.primary
                : colorScheme.outline,
            fill: effectiveSelected ? 1 : 0,
          ),
        ),
      ],
    );
  }
}
