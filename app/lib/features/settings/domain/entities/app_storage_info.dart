/// App 本地存储占用的分项快照。
class AppStorageInfo {
  const AppStorageInfo({
    required this.databaseBytes,
    required this.imageCacheBytes,
    required this.otherCacheBytes,
    required this.exerciseCount,
    required this.exerciseDetailCount,
  });

  /// SQLite 数据库文件大小（字节）。
  final int databaseBytes;

  /// 网络图片磁盘缓存大小（字节）。
  final int imageCacheBytes;

  /// 其它临时 / 缓存目录占用（字节）。
  final int otherCacheBytes;

  /// 已缓存的动作列表条数。
  final int exerciseCount;

  /// 已缓存的动作详情条数。
  final int exerciseDetailCount;

  /// 统计范围内的合计占用。
  int get totalBytes => databaseBytes + imageCacheBytes + otherCacheBytes;
}
