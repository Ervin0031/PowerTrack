import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/exercises/domain/exercise_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExerciseCacheCursor', () {
    const empty = ExerciseCacheCursor();

    test('未同步时未筛选首页不能读本地', () {
      expect(empty.canServeLocal(filtered: false, skip: 0), isFalse);
      expect(empty.isFullySynced, isFalse);
    });

    test('连续缓存范围内的未筛选页读本地', () {
      const cursor = ExerciseCacheCursor(cachedCount: 40, catalogTotal: 120);
      expect(cursor.canServeLocal(filtered: false, skip: 0), isTrue);
      expect(cursor.canServeLocal(filtered: false, skip: 20), isTrue);
      expect(cursor.canServeLocal(filtered: false, skip: 40), isFalse);
    });

    test('未全量同步时筛选不读本地', () {
      const cursor = ExerciseCacheCursor(cachedCount: 40, catalogTotal: 120);
      expect(cursor.canServeLocal(filtered: true, skip: 0), isFalse);
    });

    test('全量同步后筛选可读本地', () {
      const cursor = ExerciseCacheCursor(cachedCount: 120, catalogTotal: 120);
      expect(cursor.isFullySynced, isTrue);
      expect(cursor.canServeLocal(filtered: true, skip: 0), isTrue);
    });

    test('空目录全量同步后首页读本地', () {
      const cursor = ExerciseCacheCursor(cachedCount: 0, catalogTotal: 0);
      expect(cursor.isFullySynced, isTrue);
      expect(cursor.canServeLocal(filtered: false, skip: 0), isTrue);
      expect(cursor.emptyPageIsHole(filtered: false, skip: 0), isFalse);
    });

    test('游标说还有数据但这一页是空的，不能当结果', () {
      const cursor = ExerciseCacheCursor(cachedCount: 40, catalogTotal: 120);
      expect(cursor.emptyPageIsHole(filtered: false, skip: 0), isTrue);
      expect(cursor.emptyPageIsHole(filtered: false, skip: 120), isFalse);
      expect(cursor.emptyPageIsHole(filtered: true, skip: 0), isFalse);
    });

    test('未筛选连续页推进游标并记录总量', () {
      const cursor = ExerciseCacheCursor();
      final next = cursor.afterFetch(
        filtered: false,
        skip: 0,
        fetchedCount: 20,
        total: 80,
      );
      expect(next.cachedCount, 20);
      expect(next.catalogTotal, 80);

      final third = next.afterFetch(
        filtered: false,
        skip: 20,
        fetchedCount: 20,
        total: 80,
      );
      expect(third.cachedCount, 40);
    });

    test('筛选页不推进未筛选游标', () {
      const cursor = ExerciseCacheCursor(cachedCount: 20, catalogTotal: 80);
      final next = cursor.afterFetch(
        filtered: true,
        skip: 0,
        fetchedCount: 5,
        total: 5,
      );
      expect(next.cachedCount, 20);
      expect(next.catalogTotal, 80);
    });

    test('空洞的未筛选页不推进游标', () {
      const cursor = ExerciseCacheCursor(cachedCount: 20, catalogTotal: 80);
      final next = cursor.afterFetch(
        filtered: false,
        skip: 40,
        fetchedCount: 20,
        total: 80,
      );
      expect(next.cachedCount, 20);
    });
  });

  group('ExerciseListPage.hasMore', () {
    test('已知总量时按 skip + 本页判断', () {
      final first = ExerciseListPage(
        items: List.generate(
          20,
          (i) => Exercise(id: i, name: '$i', exerciseType: 'compound'),
        ),
        total: 25,
      );
      final last = ExerciseListPage(
        items: List.generate(
          5,
          (i) => Exercise(id: 20 + i, name: '$i', exerciseType: 'compound'),
        ),
        total: 25,
      );
      expect(first.hasMore(skip: 0, pageSize: 20), isTrue);
      expect(last.hasMore(skip: 20, pageSize: 20), isFalse);
    });

    test('未知总量时满页视为可能还有更多', () {
      final full = ExerciseListPage(
        items: List.generate(
          20,
          (i) => Exercise(id: i, name: '$i', exerciseType: 'compound'),
        ),
      );
      final short = ExerciseListPage(
        items: [const Exercise(id: 1, name: 'a', exerciseType: 'compound')],
      );
      expect(full.hasMore(skip: 0, pageSize: 20), isTrue);
      expect(short.hasMore(skip: 0, pageSize: 20), isFalse);
    });
  });
}
