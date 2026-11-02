import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 应用级 SQLite 数据库。
///
/// 单库多表：各功能模块的 DAO 在加载时通过 [registerSchema] 注册建表语句。
/// [open] 的 `onCreate` / `onOpen` 会执行已注册语句；DAO 首次访问时还会再调
/// [ensureSchemas]，避免「库先被其它模块打开、本模块表尚未注册」导致缺表。
///
/// 升级：版本号变更后实现 [onUpgrade] 的迁移分支即可。
class AppDatabase {
  AppDatabase._();

  /// 共享库文件名。
  static const fileName = 'powertrack.db';
  static const version = 1;

  /// 共享 SQLite 文件的绝对路径。
  static Future<String> filePath() async =>
      p.join(await getDatabasesPath(), fileName);

  static final List<String> _schemas = [];

  /// 注册建表语句（幂等；功能模块在 DAO 构造时调用）。
  static void registerSchema(List<String> statements) {
    for (final statement in statements) {
      if (!_schemas.contains(statement)) {
        _schemas.add(statement);
      }
    }
  }

  /// 对已打开的库执行当前全部建表语句（`CREATE IF NOT EXISTS`，可重复调用）。
  static Future<void> ensureSchemas(Database db) async {
    if (_schemas.isEmpty) return;
    final batch = db.batch();
    for (final statement in _schemas) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  static Future<Database> open() async {
    final dbPath = await filePath();
    return openDatabase(
      dbPath,
      version: version,
      onCreate: (db, version) async {
        await ensureSchemas(db);
      },
      onOpen: (db) async {
        // 已有库不会再走 onCreate；补执行晚注册的模块表。
        await ensureSchemas(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 后续版本迁移在此按 oldVersion → newVersion 分支处理。
      },
    );
  }
}
