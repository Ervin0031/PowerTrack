import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/exercise.dart';
import '../../domain/exercise_cache.dart';
import '../datasources/exercise_local_dao.dart';

part 'exercise_repository.g.dart';

/// [ExerciseRepository] 组装 Provider。
///
/// 与 Repository 同文件维护，由 `@riverpod` 生成 `exerciseRepositoryProvider`。
@Riverpod(keepAlive: true)
ExerciseRepository exerciseRepository(Ref ref) {
  return ExerciseRepository(
    ref.watch(dioProvider),
    ref.watch(exerciseLocalDaoProvider),
    ref.watch(sharedPreferencesProvider),
  );
}

/// 动作库数据仓库：按用户已加载的页写入本地，不再等全量拉取结束。
///
/// 未筛选列表用 [ExerciseCacheCursor] 记录从首页起连续缓存的范围；
/// 已缓存的页直接读 SQLite，缺页才请求后端并立刻 upsert。
class ExerciseRepository {
  ExerciseRepository(this._dio, this._dao, this._prefs);

  static const _kCachedCount = 'cache.exercises.unfiltered_count';
  static const _kCatalogTotal = 'cache.exercises.catalog_total';

  /// 图片地址从 presigned 换成稳定端点后的一次性缓存失效标记。
  static const _kStableUrlScheme = 'cache.exercises.stable_urls';

  final Dio _dio;
  final ExerciseLocalDao _dao;
  final SharedPreferences _prefs;

  /// 本地肌群表为空时，从后端一次性拉取并缓存；之后直接读本地。
  Future<List<MuscleGroup>> listMuscleGroups() async {
    final local = await _dao.getMuscleGroups();
    if (local.isNotEmpty) return local;
    final remote = await _fetchAll('/api/v1/exercises/muscle-groups');
    final groups = remote.map(MuscleGroup.fromJson).toList();
    await _dao.cacheMuscleGroups(groups);
    return groups;
  }

  /// 本地器械表为空时，从后端一次性拉取并缓存；之后直接读本地。
  Future<List<Equipment>> listEquipment() async {
    final local = await _dao.getEquipment();
    if (local.isNotEmpty) return local;
    final remote = await _fetchAll('/api/v1/exercises/equipment');
    final items = remote.map(Equipment.fromJson).toList();
    await _dao.cacheEquipment(items);
    return items;
  }

  /// 动作列表：已连续缓存的页读本地；否则拉当前页并立刻写入。
  ///
  /// 搜索 / 筛选在目录尚未全量同步时走后端，避免本地子集漏结果。
  /// 网络失败且本地已有对应页时回退本地。
  Future<ExerciseListPage> listExercises({
    String? search,
    int? muscleGroupId,
    int? equipmentId,
    String? exerciseType,
    int skip = 0,
    int limit = 20,
  }) async {
    await _dropLegacyUrlsOnce();
    final filtered = _hasFilters(
      search: search,
      muscleGroupId: muscleGroupId,
      equipmentId: equipmentId,
      exerciseType: exerciseType,
    );
    final cursor = _cursor();

    if (cursor.canServeLocal(filtered: filtered, skip: skip)) {
      final items = await _dao.getExercises(
        search: search,
        muscleGroupId: muscleGroupId,
        equipmentId: equipmentId,
        exerciseType: exerciseType,
        limit: limit,
        offset: skip,
      );
      if (items.isNotEmpty ||
          !cursor.emptyPageIsHole(filtered: filtered, skip: skip)) {
        return ExerciseListPage(
          items: items,
          total: filtered
              ? await _dao.countExercises(
                  search: search,
                  muscleGroupId: muscleGroupId,
                  equipmentId: equipmentId,
                  exerciseType: exerciseType,
                )
              : cursor.catalogTotal,
        );
      }
    }

    return await _fetchAndCachePage(
      search: search,
      muscleGroupId: muscleGroupId,
      equipmentId: equipmentId,
      exerciseType: exerciseType,
      skip: skip,
      limit: limit,
      filtered: filtered,
      cursor: cursor,
    );
  }

  /// 本地封面地址。未缓存时返回 null，不请求网络。
  Future<String?> cachedImageUrl(int id) => _dao.getExerciseImageUrl(id);

  /// 动作详情：先读本地缓存；缺失时从后端拉取并立刻缓存。
  Future<ExerciseDetail> getExercise(int id) async {
    await _dropLegacyUrlsOnce();
    final cached = await _dao.getExerciseDetail(id);
    if (cached != null) return cached;
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/exercises/$id',
    );
    final data = response.data;
    if (data == null) throw const FormatException('动作详情响应缺少数据');
    final detail = ExerciseDetail.fromJson(data);
    await _dao.cacheExerciseDetail(detail);
    return detail;
  }

  /// 已缓存的动作条数（含搜索命中、尚未纳入连续游标的行）。
  Future<int> cachedExerciseCount() => _dao.count('exercises');

  /// 已缓存的动作详情条数。
  Future<int> cachedExerciseDetailCount() => _dao.count('exercise_details');

  /// 清除动作库 SQLite 缓存与分页游标。
  Future<void> clearCache() async {
    await _dao.clearCatalog();
    await _prefs.remove(_kCachedCount);
    await _prefs.remove(_kCatalogTotal);
  }

  /// 本地缓存里存的是旧 presigned 图片 URL，过期后必然 403；
  /// 首次运行清一次，之后写入的都是不过期的稳定地址。
  Future<void> _dropLegacyUrlsOnce() async {
    if (_prefs.getBool(_kStableUrlScheme) ?? false) return;
    await clearCache();
    await _prefs.setBool(_kStableUrlScheme, true);
  }

  ExerciseCacheCursor _cursor() => ExerciseCacheCursor(
    cachedCount: _prefs.getInt(_kCachedCount) ?? 0,
    catalogTotal: _prefs.getInt(_kCatalogTotal),
  );

  Future<void> _saveCursor(ExerciseCacheCursor cursor) async {
    await _prefs.setInt(_kCachedCount, cursor.cachedCount);
    final total = cursor.catalogTotal;
    if (total == null) {
      await _prefs.remove(_kCatalogTotal);
    } else {
      await _prefs.setInt(_kCatalogTotal, total);
    }
  }

  Future<ExerciseListPage> _fetchAndCachePage({
    required String? search,
    required int? muscleGroupId,
    required int? equipmentId,
    required String? exerciseType,
    required int skip,
    required int limit,
    required bool filtered,
    required ExerciseCacheCursor cursor,
  }) async {
    final page = await _fetchPage(
      skip: skip,
      limit: limit,
      search: search,
      muscleGroupId: muscleGroupId,
      equipmentId: equipmentId,
      exerciseType: exerciseType,
    );
    await _dao.cacheExerciseJson(page.items);
    await _saveCursor(
      cursor.afterFetch(
        filtered: filtered,
        skip: skip,
        fetchedCount: page.items.length,
        total: page.total,
      ),
    );
    return ExerciseListPage(
      items: page.items.map(Exercise.fromJson).toList(),
      total: page.total,
    );
  }

  bool _hasFilters({
    String? search,
    int? muscleGroupId,
    int? equipmentId,
    String? exerciseType,
  }) {
    return (search != null && search.isNotEmpty) ||
        muscleGroupId != null ||
        equipmentId != null ||
        (exerciseType != null && exerciseType.isNotEmpty);
  }

  /// 拉取支持 `items` 结构的列表接口的「全量」（不翻页，后端一次返回）。
  Future<List<Map<String, dynamic>>> _fetchAll(String path) async {
    final response = await _dio.get<Map<String, dynamic>>(path);
    final items = response.data?['items'];
    if (items is! List) return const [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  /// 拉取动作列表的单页（`items` + `total`）。
  Future<({List<Map<String, dynamic>> items, int total})> _fetchPage({
    required int skip,
    required int limit,
    String? search,
    int? muscleGroupId,
    int? equipmentId,
    String? exerciseType,
  }) async {
    final query = <String, dynamic>{'skip': skip, 'limit': limit};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (muscleGroupId != null) query['muscle_group_id'] = muscleGroupId;
    if (equipmentId != null) query['equipment_id'] = equipmentId;
    if (exerciseType != null && exerciseType.isNotEmpty)
      query['exercise_type'] = exerciseType;

    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/exercises',
      queryParameters: query,
    );
    final items = response.data?['items'];
    final parsed = items is List
        ? items.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    final total = (response.data?['total'] as num?)?.toInt() ?? parsed.length;
    return (items: parsed, total: total);
  }
}
