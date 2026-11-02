import 'package:app_flutter/core/database/app_database.dart';
import 'package:app_flutter/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// 本地 DAO 基类。
///
/// 统一持有打开的 [Database]，并封装「按主键 upsert」「条件查询」「计数」等
/// 复用样板，各功能模块的 DAO 继承它即可专注表结构与业务查询。
abstract class BaseDao {
  const BaseDao(this.ref);

  final Ref ref;

  /// 当前进程共享的数据库实例（异步打开，仅在首次访问时建库）。
  ///
  /// 打开后立即 [AppDatabase.ensureSchemas]，保证本 DAO 已注册的表存在
  ///（即使库更早被其它模块打开过）。
  Future<Database> get db async {
    final database = await ref.watch(databaseProvider.future);
    await AppDatabase.ensureSchemas(database);
    return database;
  }

  /// 不存在则插入、存在则按主键覆盖。
  Future<void> insertOrReplace(String table, Map<String, Object?> row) async {
    final database = await db;
    await database.insert(
      table,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批量 upsert（事务内执行，避免逐条提交开销）。
  Future<void> insertOrReplaceBatch(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final database = await db;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// 统计表行数（可选 [where] 条件）。
  Future<int> count(String table, {String? where, List<Object?>? whereArgs}) async {
    final database = await db;
    final result = await database.query(
      table,
      columns: ['COUNT(*)'],
      where: where,
      whereArgs: whereArgs,
    );
    return result.first.values.first as int;
  }
}
