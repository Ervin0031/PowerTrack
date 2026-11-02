import 'dart:convert';

import 'package:app_flutter/core/database/app_database.dart';
import 'package:app_flutter/core/database/base_dao.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

part 'training_session_local_dao.g.dart';

/// 进行中训练会话的本地表建表语句，库加载时注册到 [AppDatabase]。
const _sessionTables = <String>[
  '''
  CREATE TABLE IF NOT EXISTS active_session (
    id INTEGER PRIMARY KEY,
    data TEXT NOT NULL
  )
  ''',
];

/// 训练会话模块的本地数据访问对象。
///
/// 将进行中会话（含全部动作与组）整体序列化为单行 JSON 缓存到 SQLite，
/// 保证离线可用、冷启动可恢复。会话结束或放弃时清除。
// ponytail: 单行 JSON 即可满足「进行中会话」的本地缓存，无需拆表；历史会话走后端。
@Riverpod(keepAlive: true)
TrainingSessionLocalDao trainingSessionLocalDao(Ref ref) => TrainingSessionLocalDao(ref);

class TrainingSessionLocalDao extends BaseDao {
  TrainingSessionLocalDao(super.ref) {
    AppDatabase.registerSchema(_sessionTables);
  }

  static const _rowId = 1;

  /// 库可能已在其他模块之后打开（建表顺序不固定），每次操作前幂等补建表，
  /// 避免「无此表」错误。
  Future<Database> get _sessionDb async {
    final database = await db;
    await database.execute(_sessionTables.first);
    return database;
  }

  Future<ActiveTraining?> getActiveSession() async {
    final rows = await (await _sessionDb).query(
      'active_session',
      where: 'id = ?',
      whereArgs: [_rowId],
    );
    if (rows.isEmpty) return null;
    final data = rows.first['data'] as String;
    return ActiveTraining.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<void> saveActiveSession(ActiveTraining session) async {
    final database = await _sessionDb;
    await database.insert(
      'active_session',
      {'id': _rowId, 'data': jsonEncode(session.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearActiveSession() async {
    final database = await _sessionDb;
    await database.delete('active_session', where: 'id = ?', whereArgs: [_rowId]);
  }
}