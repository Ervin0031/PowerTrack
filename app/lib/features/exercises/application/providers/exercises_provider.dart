import 'package:app_flutter/features/exercises/data/repositories/exercise_repository.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'exercises_provider.g.dart';

/// 按动作 ID 获取详情：`GET /api/v1/exercises/{id}`。
@riverpod
Future<ExerciseDetail> exerciseDetail(Ref ref, int id) {
  return ref.watch(exerciseRepositoryProvider).getExercise(id);
}

/// 本地动作封面。未缓存时为 null，不打网络。
final exerciseImageUrlProvider = FutureProvider.family<String?, int>((ref, id) {
  return ref.watch(exerciseRepositoryProvider).cachedImageUrl(id);
});

/// 动作列表的筛选条件。
///
/// 任一字段为 `null`（或 search 为空）表示不筛选；[copyWith] 用于增量更新。
class ExercisesFilter {
  const ExercisesFilter({
    this.search = '',
    this.muscleGroupId,
    this.equipmentId,
    this.exerciseType,
  });

  final String search;
  final int? muscleGroupId;
  final int? equipmentId;

  /// 动作类型：compound（复合）/ isolation（孤立）。空字符串表示全部。
  final String? exerciseType;

  ExercisesFilter copyWith({
    String? search,
    int? muscleGroupId,
    bool clearMuscleGroup = false,
    int? equipmentId,
    bool clearEquipment = false,
    String? exerciseType,
    bool clearExerciseType = false,
  }) {
    return ExercisesFilter(
      search: search ?? this.search,
      muscleGroupId: clearMuscleGroup
          ? null
          : (muscleGroupId ?? this.muscleGroupId),
      equipmentId: clearEquipment ? null : (equipmentId ?? this.equipmentId),
      exerciseType: clearExerciseType
          ? null
          : (exerciseType ?? this.exerciseType),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExercisesFilter &&
      other.search == search &&
      other.muscleGroupId == muscleGroupId &&
      other.equipmentId == equipmentId &&
      other.exerciseType == exerciseType;

  @override
  int get hashCode =>
      Object.hash(search, muscleGroupId, equipmentId, exerciseType);
}

/// 当前筛选条件，UI 通过修改它触发列表重新拉取。
final exercisesFilterProvider = StateProvider<ExercisesFilter>(
  (ref) => const ExercisesFilter(),
);

/// 动作列表的分页状态。
///
/// [items] 为已加载的全部动作；[skip] 为下一页偏移；[hasMore] 表示是否
/// 仍有后续页；[isLoadingMore] 防止滚动到底部时重复触发加载。
class ExercisesPageState {
  const ExercisesPageState({
    this.items = const [],
    this.skip = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    required this.filter,
  });

  final List<Exercise> items;
  final int skip;
  final bool hasMore;
  final bool isLoadingMore;
  final ExercisesFilter filter;

  ExercisesPageState copyWith({
    List<Exercise>? items,
    int? skip,
    bool? hasMore,
    bool? isLoadingMore,
    ExercisesFilter? filter,
  }) {
    return ExercisesPageState(
      items: items ?? this.items,
      skip: skip ?? this.skip,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      filter: filter ?? this.filter,
    );
  }
}

/// 动作列表控制器（分页 + 筛选联动）。
///
/// `build` 监听 [exercisesFilterProvider]，筛选条件变化即重置并重新拉取第一页；
/// [loadMore] 在现有列表末尾追加下一页，供滚动到底部时调用。
@riverpod
class ExercisesController extends _$ExercisesController {
  static const _pageSize = 20;

  @override
  Future<ExercisesPageState> build() async {
    final filter = ref.watch(exercisesFilterProvider);
    final page = await ref
        .read(exerciseRepositoryProvider)
        .listExercises(
          search: filter.search,
          muscleGroupId: filter.muscleGroupId,
          equipmentId: filter.equipmentId,
          exerciseType: filter.exerciseType,
          limit: _pageSize,
        );
    return ExercisesPageState(
      items: page.items,
      skip: page.items.length,
      hasMore: page.hasMore(skip: 0, pageSize: _pageSize),
      filter: filter,
    );
  }

  /// 加载下一页并追加到现有列表。
  ///
  /// 无更多数据、正在加载或首屏未就绪时直接返回；异常只取消加载态，
  /// 不阻塞已加载的列表。
  Future<void> loadMore() async {
    final current = state.value;
    // 正在换筛选时，旧的下一页不能再写回来，否则会把新结果盖成空列表。
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        state.isLoading) {
      return;
    }
    final filter = current.filter;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final more = await ref
          .read(exerciseRepositoryProvider)
          .listExercises(
            search: filter.search,
            muscleGroupId: filter.muscleGroupId,
            equipmentId: filter.equipmentId,
            exerciseType: filter.exerciseType,
            skip: current.skip,
            limit: _pageSize,
          );
      final updated = state.value;
      if (updated == null || updated.filter != filter || state.isLoading) {
        return;
      }
      state = AsyncData(
        updated.copyWith(
          items: [...updated.items, ...more.items],
          skip: updated.skip + more.items.length,
          hasMore: more.hasMore(skip: current.skip, pageSize: _pageSize),
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      final updated = state.value;
      if (updated != null) {
        state = AsyncData(updated.copyWith(isLoadingMore: false));
      }
      // 分页错误不阻断已有列表；如需提示可在此上浮。
    }
  }
}

/// 肌群字典（筛选 / 表单复用）。
final muscleGroupsProvider = FutureProvider<List<MuscleGroup>>((ref) {
  return ref.watch(exerciseRepositoryProvider).listMuscleGroups();
});

/// 器械字典（筛选 / 表单复用）。
final equipmentListProvider = FutureProvider<List<Equipment>>((ref) {
  return ref.watch(exerciseRepositoryProvider).listEquipment();
});
