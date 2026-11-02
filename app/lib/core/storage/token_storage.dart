import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 访问令牌在设备上的持久化封装。
///
/// 令牌属敏感凭证，落盘走系统安全存储（iOS Keychain / Android Keystore），
/// 内存里保留一份缓存供 [accessToken] 等**同步** getter 读取——路由守卫与
/// 鉴权拦截器都在同步链路上取 token，因此 getter 不能改成 async。
///
/// 启动时必须先 `await hydrate()`（见 `main.dart`）把磁盘上的令牌读进内存；
/// 未 hydrate 或读取失败时 getter 一律返回 `null`（按未登录处理），不会抛错。
class TokenStorage {
  /// 生产用；[prefs] 仅用于把旧版本存在 [SharedPreferences] 里的明文令牌迁移走。
  TokenStorage(this._prefs);

  /// 测试用：不落盘、不碰平台插件，只在内存里读写。
  TokenStorage.memory()
      : _prefs = null,
        _hydrated = true;

  /// 与业务无关的存储键前缀，避免与其它模块键名冲突。
  static const _kAccessToken = 'auth.access_token';
  static const _kRefreshToken = 'auth.refresh_token';
  static const _kExpiresAt = 'auth.expires_at';

  static const _secure = FlutterSecureStorage();

  final SharedPreferences? _prefs;

  String? _accessToken;
  String? _refreshToken;
  int? _expiresAt;
  bool _hydrated = false;

  /// 当前保存的访问令牌；未写入或尚未 [hydrate] 时为 `null`。
  String? get accessToken => _accessToken;

  /// 刷新令牌，用于在访问令牌过期后向服务端换取新令牌。
  String? get refreshToken => _refreshToken;

  /// 访问令牌过期的绝对时间戳（毫秒，与 [DateTime.now] 的 epoch 一致）。
  int? get expiresAt => _expiresAt;

  /// 把持久化的令牌读进内存；启动时（`runApp` 前）调用一次即可。
  ///
  /// 同时承担一次性迁移：旧版本把令牌明文存在 [SharedPreferences] 里，
  /// 这里搬进安全存储并删掉旧键，既避免已登录用户升级后被登出，也避免明文残留。
  ///
  /// 安全存储不可用（如测试环境没有平台插件）时按未登录处理，不阻断启动。
  Future<void> hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    try {
      _accessToken = await _secure.read(key: _kAccessToken);
      if (_accessToken == null) return await _migrateFromPrefs();
      _refreshToken = await _secure.read(key: _kRefreshToken);
      _expiresAt = int.tryParse(await _secure.read(key: _kExpiresAt) ?? '');
    } catch (_) {
      // 读不到就当未登录：重新登录会再写一次盘。
    }
  }

  /// 写入登录/刷新接口返回的令牌信息。
  ///
  /// 1. 更新内存缓存并持久化 `accessToken`、`refreshToken`。
  /// 2. 若传入 [expiresInSeconds]，则根据「当前时刻 + 有效秒数」计算过期时间戳并写入。
  ///
  /// [expiresInSeconds] 通常为服务端返回的「剩余有效时间」，相对当前时间累加更贴近实际。
  /// ⚠️ 设备系统时间被用户修改会导致本地计算的过期时刻不可靠；严谨场景可结合服务端时间或短期校验。
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    int? expiresInSeconds,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (expiresInSeconds != null) {
      _expiresAt =
          DateTime.now().millisecondsSinceEpoch + expiresInSeconds * 1000;
    }
    try {
      await _secure.write(key: _kAccessToken, value: accessToken);
      await _secure.write(key: _kRefreshToken, value: refreshToken);
      if (_expiresAt != null) {
        await _secure.write(key: _kExpiresAt, value: '$_expiresAt');
      }
    } catch (_) {
      // 落盘失败不打断登录：本次会话内存里可用，下次启动需重新登录。
    }
  }

  /// 登出或令牌失效时清除本地三项数据，避免残留导致误用旧会话。
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    try {
      await _secure.delete(key: _kAccessToken);
      await _secure.delete(key: _kRefreshToken);
      await _secure.delete(key: _kExpiresAt);
    } catch (_) {
      // 内存已清空，本次会话不会再带上旧票。
    }
    // 迁移失败等情况可能仍在 prefs 里留着明文，一并清掉。
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kExpiresAt);
  }

  /// 是否具备非空的访问令牌；路由守卫、拦截器可据此判断是否视为「已登录态」。
  ///
  /// ⚠️ 仅有令牌不代表一定有效（可能已服务端吊销）；网络层仍应以 401 等为准做刷新或清会话。
  bool get hasToken {
    final t = accessToken;
    return t != null && t.isNotEmpty;
  }

  /// 旧版本明文存在 [SharedPreferences] 的令牌：写入安全存储后删除旧键。
  Future<void> _migrateFromPrefs() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final access = prefs.getString(_kAccessToken);
    final refresh = prefs.getString(_kRefreshToken);
    final expires = prefs.getInt(_kExpiresAt);
    if (access == null && refresh == null && expires == null) return;

    if (access != null) await _secure.write(key: _kAccessToken, value: access);
    if (refresh != null) {
      await _secure.write(key: _kRefreshToken, value: refresh);
    }
    if (expires != null) await _secure.write(key: _kExpiresAt, value: '$expires');

    _accessToken = access;
    _refreshToken = refresh;
    _expiresAt = expires;

    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kExpiresAt);
  }
}
