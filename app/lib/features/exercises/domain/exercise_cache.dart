import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';

/// 动作库未筛选列表的本地缓存游标。
///
/// [cachedCount] 是从 offset 0 起、按 `id` 顺序连续已缓存的条数，不是表内总行数。
/// 搜索/筛选命中的动作也会写入本地，但不能推进该游标，否则未筛选列表会读到「有空洞」的页。
class ExerciseCacheCursor {
  const ExerciseCacheCursor({this.cachedCount = 0, this.catalogTotal});

  /// 未筛选列表已从首页连续缓存的条数。
  final int cachedCount;

  /// 后端未筛选列表的总条数；尚未拉过首页时为 `null`。
  final int? catalogTotal;

  /// Whether the unfiltered catalog has been fully cached locally.
  bool get isFullySynced =>
      catalogTotal != null && cachedCount >= catalogTotal!;

  /// Whether this request can be served from the contiguous local catalog.
  ///
  /// Filtered queries only hit SQLite after a full unfiltered sync; otherwise
  /// the local subset would silently drop matches the user has not scrolled to.
  /// A fully synced catalog (including an empty one) is always served locally.
  bool canServeLocal({required bool filtered, required int skip}) {
    if (isFullySynced) return true;
    if (filtered) return false;
    return skip < cachedCount;
  }

  /// 游标认为这一页还有行，但本地查出来是空的。缓存被清掉又没重置游标时会出现。
  /// 这种空页不能当结果，否则列表会一直空，直到一次会打到网络的搜索。
  bool emptyPageIsHole({required bool filtered, required int skip}) {
    if (filtered) return false;
    final known = catalogTotal ?? (cachedCount > 0 ? cachedCount : null);
    if (known == null) return false;
    return known > skip;
  }

  /// Returns a cursor after caching an unfiltered page that starts at [skip].
  ///
  /// Filtered pages leave the cursor unchanged. A non-contiguous unfiltered
  /// page (gap after [cachedCount]) is stored but does not extend the range.
  ExerciseCacheCursor afterFetch({
    required bool filtered,
    required int skip,
    required int fetchedCount,
    required int total,
  }) {
    final nextCount = (!filtered && skip == cachedCount)
        ? cachedCount + fetchedCount
        : cachedCount;
    return ExerciseCacheCursor(
      cachedCount: nextCount,
      catalogTotal: filtered ? catalogTotal : total,
    );
  }
}

/// 动作列表的一页结果，附带后端（或本地游标）给出的总量，供分页判断。
class ExerciseListPage {
  const ExerciseListPage({required this.items, this.total});

  /// 本页动作。
  final List<Exercise> items;

  /// 当前筛选条件下的总条数；仅本地、且游标尚未记录总量时为 `null`。
  final int? total;

  /// Whether another page should be requested after this one.
  ///
  /// [skip] is the offset used to load [items]. When [total] is unknown, a full
  /// [pageSize] result is treated as "maybe more".
  bool hasMore({required int skip, required int pageSize}) {
    if (total != null) return skip + items.length < total!;
    return items.length >= pageSize;
  }
}
