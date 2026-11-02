import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 更新后「有什么新内容」的轻量实现。
///
/// 首次打开某版本时，与本地记录的上次见过的版本比较；版本升级则展示更新点，
/// 并写回当前版本号，避免重复弹窗。首次安装（无记录）不弹。
class ChangelogService {
  static const _lastSeenKey = 'app.last_seen_version';

  /// 以版本号为键的更新说明；缺失版本回退到通用文案。
  static const Map<String, List<String>> _changelog = {
    '1.0.0': [
      '首个版本发布',
      '训练会话 / 动作库 / 个人中心',
    ],
  };

  /// 返回需要展示的更新条目；无需展示时返回 null。
  static Future<List<String>?> check(PackageInfo info, SharedPreferences prefs) async {
    final lastSeen = prefs.getString(_lastSeenKey);
    await prefs.setString(_lastSeenKey, info.version);
    if (lastSeen == null || lastSeen == info.version) return null;
    return _changelog[info.version] ?? const ['修复若干已知问题，体验更顺畅。'];
  }
}
