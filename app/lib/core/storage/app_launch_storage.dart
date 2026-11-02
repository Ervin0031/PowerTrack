import 'package:shared_preferences/shared_preferences.dart';

/// 首次启动状态存储。
///
/// 职责：
/// - 记录用户是否已经看过 Welcome 页面。
/// - 记录是否已完成系统权限引导。
/// - 为路由守卫提供轻量、同步读取的启动状态。
///
/// ⚠️ 注意：
/// 这类状态不属于账号数据；登出时是否重置应按产品需求决定。
class AppLaunchStorage {
  AppLaunchStorage(this._prefs);

  final SharedPreferences _prefs;

  /// 本地键名集中定义，避免字符串散落在页面逻辑里。
  static const _hasSeenWelcomeKey = 'app.has_seen_welcome';
  static const _hasSeenPermissionsKey = 'app.has_seen_permissions_guide';

  /// 是否已经完成首次欢迎流程。
  bool get hasSeenWelcome => _prefs.getBool(_hasSeenWelcomeKey) ?? false;

  /// 是否已经看过（完成或跳过）权限引导。
  bool get hasSeenPermissionsGuide => _prefs.getBool(_hasSeenPermissionsKey) ?? false;

  /// 在用户点击开始使用后写入，后续启动可直接进入登录或首页分流。
  Future<void> markWelcomeSeen() async {
    await _prefs.setBool(_hasSeenWelcomeKey, true);
  }

  /// 权限引导页点「继续 / 稍后再说」后写入。
  Future<void> markPermissionsGuideSeen() async {
    await _prefs.setBool(_hasSeenPermissionsKey, true);
  }

  /// 测试、调试或“重新体验引导页”时使用。
  Future<void> reset() async {
    await _prefs.remove(_hasSeenWelcomeKey);
    await _prefs.remove(_hasSeenPermissionsKey);
  }
}
