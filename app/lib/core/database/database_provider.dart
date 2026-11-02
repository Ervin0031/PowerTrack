import 'package:app_flutter/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

part 'database_provider.g.dart';

/// 应用级 SQLite 数据库 Provider。
///
/// `keepAlive: true`：作为基础设施依赖，生命周期跟随应用，整个进程共享同一
/// 打开的 [Database] 实例。
@Riverpod(keepAlive: true)
Future<Database> database(Ref ref) => AppDatabase.open();
