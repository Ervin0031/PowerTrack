import 'dart:convert';

import 'package:app_flutter/core/database/app_database.dart';
import 'package:app_flutter/core/database/base_dao.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'exercise_local_dao.g.dart';

/// exercises 模块的本地表建表语句，库加载时注册到 [AppDatabase]。
const _exerciseTables = <String>[
  '''
  CREATE TABLE IF NOT EXISTS muscle_groups (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    name_en TEXT NOT NULL,
    category TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS equipment (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    name_en TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS exercises (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    name_en TEXT,
    exercise_type TEXT NOT NULL,
    equipment_id INTEGER,
    image_url TEXT,
    primary_muscle_group_id INTEGER
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS exercise_details (
    id INTEGER PRIMARY KEY,
    data TEXT NOT NULL
  )
  ''',
];

/// exercises 模块的本地数据访问对象。
///
/// 负责肌群 / 器械 / 动作 / 动作详情的本地读写与缓存。列表页按页写入，
/// 详情在打开时写入；读操作供 UI 直接使用。
@Riverpod(keepAlive: true)
ExerciseLocalDao exerciseLocalDao(Ref ref) => ExerciseLocalDao(ref);

class ExerciseLocalDao extends BaseDao {
  ExerciseLocalDao(super.ref) {
    AppDatabase.registerSchema(_exerciseTables);
  }

  // --- 肌群 ---
  Future<List<MuscleGroup>> getMuscleGroups() async {
    final database = await db;
    final rows = await database.query('muscle_groups', orderBy: 'id');
    return rows.map(_muscleGroupFromRow).toList();
  }

  Future<void> cacheMuscleGroups(List<MuscleGroup> groups) =>
      insertOrReplaceBatch(
        'muscle_groups',
        groups.map(_muscleGroupToRow).toList(),
      );

  // --- 器械 ---
  Future<List<Equipment>> getEquipment() async {
    final database = await db;
    final rows = await database.query('equipment', orderBy: 'id');
    return rows.map(_equipmentFromRow).toList();
  }

  Future<void> cacheEquipment(List<Equipment> items) =>
      insertOrReplaceBatch('equipment', items.map(_equipmentToRow).toList());

  // --- 动作列表 ---
  Future<List<Exercise>> getExercises({
    String? search,
    int? muscleGroupId,
    int? equipmentId,
    String? exerciseType,
    int? limit,
    int? offset,
  }) async {
    final database = await db;
    final filter = _exerciseFilter(
      search: search,
      muscleGroupId: muscleGroupId,
      equipmentId: equipmentId,
      exerciseType: exerciseType,
    );
    final rows = await database.query(
      'exercises',
      where: filter.where,
      whereArgs: filter.args,
      limit: limit,
      offset: offset,
      orderBy: 'id',
    );
    return rows.map(_exerciseFromRow).toList();
  }

  /// 与 [getExercises] 相同筛选条件下的行数。
  Future<int> countExercises({
    String? search,
    int? muscleGroupId,
    int? equipmentId,
    String? exerciseType,
  }) {
    final filter = _exerciseFilter(
      search: search,
      muscleGroupId: muscleGroupId,
      equipmentId: equipmentId,
      exerciseType: exerciseType,
    );
    return count('exercises', where: filter.where, whereArgs: filter.args);
  }

  Future<void> cacheExercises(List<Exercise> items) =>
      insertOrReplaceBatch('exercises', items.map(_exerciseToRow).toList());

  /// 按列表接口原始 JSON 写入动作行，保留 `primary_muscle_group_id` 供本地筛选。
  Future<void> cacheExerciseJson(List<Map<String, dynamic>> items) =>
      insertOrReplaceBatch('exercises', items.map(_exerciseJsonToRow).toList());

  /// 清除动作库相关表（肌群 / 器械 / 列表 / 详情），不影响进行中训练会话。
  Future<void> clearCatalog() async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('exercise_details');
      await txn.delete('exercises');
      await txn.delete('muscle_groups');
      await txn.delete('equipment');
    });
  }

  /// 本地已缓存的动作封面。只读 SQLite，不访问网络。
  ///
  /// 列表行优先；没有封面时再看详情缓存。都没有则返回 null。
  Future<String?> getExerciseImageUrl(int id) async {
    final database = await db;
    final rows = await database.query(
      'exercises',
      columns: const ['image_url'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final url = rows.first['image_url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }
    final detail = await getExerciseDetail(id);
    final detailUrl = detail?.imageUrl;
    if (detailUrl != null && detailUrl.isNotEmpty) return detailUrl;
    return null;
  }

  /// 拉取详情后回填动作的关联肌群，使本地「按肌群筛选」可用。
  Future<void> updateExercisePrimaryMuscle(
    int exerciseId,
    int muscleGroupId,
  ) async {
    final database = await db;
    await database.update(
      'exercises',
      {'primary_muscle_group_id': muscleGroupId},
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
  }

  // --- 动作详情 ---
  Future<ExerciseDetail?> getExerciseDetail(int id) async {
    final database = await db;
    final rows = await database.query(
      'exercise_details',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final data = rows.first['data'] as String;
    return ExerciseDetail.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<void> cacheExerciseDetail(ExerciseDetail detail) async {
    await insertOrReplace('exercise_details', {
      'id': detail.id,
      'data': jsonEncode(detail.toJson()),
    });
    await updateExercisePrimaryMuscle(detail.id, detail.primaryMuscleGroupId);
  }
}

({String? where, List<Object?>? args}) _exerciseFilter({
  String? search,
  int? muscleGroupId,
  int? equipmentId,
  String? exerciseType,
}) {
  final where = <String>[];
  final args = <Object?>[];
  if (search != null && search.isNotEmpty) {
    where.add('(name LIKE ? OR name_en LIKE ?)');
    args.add('%$search%');
    args.add('%$search%');
  }
  if (muscleGroupId != null) {
    where.add('primary_muscle_group_id = ?');
    args.add(muscleGroupId);
  }
  if (equipmentId != null) {
    where.add('equipment_id = ?');
    args.add(equipmentId);
  }
  if (exerciseType != null && exerciseType.isNotEmpty) {
    where.add('exercise_type = ?');
    args.add(exerciseType);
  }
  return (
    where: where.isEmpty ? null : where.join(' AND '),
    args: args.isEmpty ? null : args,
  );
}

// --- 行 <-> 实体映射 ---

Map<String, Object?> _muscleGroupToRow(MuscleGroup g) => {
  'id': g.id,
  'name': g.name,
  'name_en': g.nameEn,
  'category': g.category,
};

MuscleGroup _muscleGroupFromRow(Map<String, Object?> row) => MuscleGroup(
  id: row['id'] as int,
  name: row['name'] as String,
  nameEn: row['name_en'] as String,
  category: row['category'] as String,
);

Map<String, Object?> _equipmentToRow(Equipment e) => {
  'id': e.id,
  'name': e.name,
  'name_en': e.nameEn,
};

Equipment _equipmentFromRow(Map<String, Object?> row) => Equipment(
  id: row['id'] as int,
  name: row['name'] as String,
  nameEn: row['name_en'] as String,
);

Map<String, Object?> _exerciseToRow(Exercise e) => {
  'id': e.id,
  'name': e.name,
  'name_en': e.nameEn,
  'exercise_type': e.exerciseType,
  'equipment_id': e.equipmentId,
  'image_url': e.imageUrl,
};

Map<String, Object?> _exerciseJsonToRow(Map<String, dynamic> json) => {
  'id': (json['id'] as num).toInt(),
  'name': json['name'] as String,
  'name_en': json['name_en'] as String?,
  'exercise_type': json['exercise_type'] as String,
  'equipment_id': (json['equipment_id'] as num?)?.toInt(),
  'image_url': json['image_url'] as String?,
  'primary_muscle_group_id': (json['primary_muscle_group_id'] as num?)?.toInt(),
};

Exercise _exerciseFromRow(Map<String, Object?> row) => Exercise(
  id: row['id'] as int,
  name: row['name'] as String,
  nameEn: row['name_en'] as String?,
  exerciseType: row['exercise_type'] as String,
  equipmentId: row['equipment_id'] as int?,
  imageUrl: row['image_url'] as String?,
);
