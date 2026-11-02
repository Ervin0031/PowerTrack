import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/exercises/application/providers/exercises_provider.dart';
import 'package:app_flutter/features/exercises/data/repositories/exercise_repository.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 动作库页面。
///
/// 结构（自上而下）：
/// 1. [GlassAppBar]：顶部标题栏。
/// 2. [SearchBar]：顶部搜索栏。
/// 3. [ExerciseFilterBar]：三个 m3e 筛选下拉（肌群 / 器械 / 动作类型）。
/// 4. [M3ESegmentedList]：动作卡片列表，左图右文。
class ExercisesPage extends ConsumerStatefulWidget {
  const ExercisesPage({super.key});

  @override
  ConsumerState<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends ConsumerState<ExercisesPage> {
  // 与下方 GlassAppBar 结构保持同步（toolbarHeight / bottom 高度）。
  static const _appBarToolbarHeight = 100.0;
  static const _appBarBottomHeight = 100.0;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(exercisesFilterProvider.notifier).update((f) => f.copyWith(search: value));
  }

  void _onScroll() {
    // 距底部 200px 内触发加载更多，避免误触顶部。
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(exercisesControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exercisesControllerProvider);
    // 顶部留白 = 状态栏 + 工具栏 + 筛选栏（appBarInset 只覆盖默认高度的工具栏）。
    final topInset = context.safeTop + _appBarToolbarHeight + _appBarBottomHeight;

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: false,
        title: AppSearchBar(
          padding: EdgeInsets.symmetric(horizontal: 4),
          leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Symbols.navigate_before)),
          controller: _searchController,
          hintText: '训练动作',
          onChanged: _onSearchChanged,
        ),
        toolbarHeight: _appBarToolbarHeight,
        bottom: PreferredSize(
          preferredSize: .fromHeight(42),
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: ExerciseFilterBar()),
        ),
      ),
      body: state.when(
        loading: () => const Center(child: M3ELoadingIndicator()),
        error: (error, _) => AppErrorState(error: error, onRetry: () => ref.invalidate(exercisesControllerProvider)),
        data: (s) => M3ESegmentedList.builder(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          listPadding: EdgeInsets.only(bottom: 24),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: s.items.length + (s.hasMore ? 1 : 0),
          emptyBuilder: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: const Center(
              child: AppEmptyState(icon: Symbols.fitness_center_rounded, title: '暂无动作'),
            ),
          ),
          onTap: (index) {
            if (index < s.items.length) {
              context.push('/exercises/${s.items[index].id}');
            }
          },
          itemBuilder: (context, index) {
            if (index < s.items.length) {
              return _ExerciseCard(exercise: s.items[index]);
            }
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: M3ELoadingIndicator()),
            );
          },
        ),
      ),
    );
  }
}

/// 顶部三个筛选下拉：肌群 / 器械 / 动作类型。
///
/// 肌群与器械选项来自后端，使用 `.future` 构造异步加载（在 build 之后回调，
/// 避免 `didUpdateWidget` → `setItems` → `onSelectionChanged` 在构建期改写 Provider）。
/// 动作类型为固定常量选项，列表引用稳定，不会触发重建时的 `setItems`。
/// 以公开类形式提供，供动作选择库页复用同一套筛选交互。
class ExerciseFilterBar extends ConsumerWidget {
  const ExerciseFilterBar({super.key});

  static const _typeItems = [
    M3EDropdownItem<String>(label: '复合', value: 'compound'),
    M3EDropdownItem<String>(label: '孤立', value: 'isolation'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: M3EDropdownMenu<int>.future(
            future: () => ref
                .read(exerciseRepositoryProvider)
                .listMuscleGroups()
                .then((groups) => groups.map((g) => M3EDropdownItem<int>(label: g.name, value: g.id)).toList()),
            singleSelect: true,
            containerRadius: AppRadius.field,
            fieldStyle: M3EDropdownFieldStyle(
              selectedBorderRadius: 8,
              borderRadius: BorderRadius.circular(24),
              hintText: '肌群',
              // border: BorderSide(width: .5, color: Theme.of(context).colorScheme.outlineVariant),
            ),
            onSelectionChanged: (selected) {
              final id = selected.isEmpty ? null : selected.first.value;
              final current = ref.read(exercisesFilterProvider);
              // 仅在取值变化时才改写 Provider，过滤掉加载时的空选中回调。
              if (id != current.muscleGroupId) {
                ref
                    .read(exercisesFilterProvider.notifier)
                    .update((f) => f.copyWith(muscleGroupId: id, clearMuscleGroup: id == null));
              }
            },
          ),
        ),
        Expanded(
          child: M3EDropdownMenu<int>.future(
            future: () => ref
                .read(exerciseRepositoryProvider)
                .listEquipment()
                .then((list) => list.map((e) => M3EDropdownItem<int>(label: e.name, value: e.id)).toList()),
            singleSelect: true,
            containerRadius: AppRadius.field,

            fieldStyle: M3EDropdownFieldStyle(
              hintText: '器械',
              selectedBorderRadius: 8,
              borderRadius: BorderRadius.circular(24),
            ),
            onSelectionChanged: (selected) {
              final id = selected.isEmpty ? null : selected.first.value;
              final current = ref.read(exercisesFilterProvider);
              if (id != current.equipmentId) {
                ref
                    .read(exercisesFilterProvider.notifier)
                    .update((f) => f.copyWith(equipmentId: id, clearEquipment: id == null));
              }
            },
          ),
        ),
        Expanded(
          child: M3EDropdownMenu<String>(
            items: _typeItems,
            singleSelect: true,
            containerRadius: AppRadius.field,
            fieldStyle: M3EDropdownFieldStyle(
              hintText: '类型',
              selectedBorderRadius: 8,
              borderRadius: BorderRadius.circular(24),
            ),
            onSelectionChanged: (selected) {
              final value = selected.isEmpty ? null : selected.first.value;
              final current = ref.read(exercisesFilterProvider);
              if (value != current.exerciseType) {
                ref
                    .read(exercisesFilterProvider.notifier)
                    .update((f) => f.copyWith(exerciseType: value, clearExerciseType: value == null));
              }
            },
          ),
        ),
      ],
    );
  }
}

/// 单个动作卡片：左侧图片，右侧标题 + 副标题。
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        AppNetworkImage(url: exercise.imageUrl, size: 64),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exercise.name, style: Theme.of(context).textTheme.titleMedium),
              if (exercise.nameEn != null) Text(exercise.nameEn!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                exercise.exerciseType == 'compound' ? '复合' : '孤立',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
