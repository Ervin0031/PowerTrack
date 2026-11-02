import 'package:app_flutter/core/storage/token_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Map<String, String> secureData;

  setUp(() {
    secureData = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(secureData);
  });

  test('hydrate 把旧版明文令牌迁进安全存储并删掉旧键', () async {
    SharedPreferences.setMockInitialValues({
      'auth.access_token': 'old-access',
      'auth.refresh_token': 'old-refresh',
      'auth.expires_at': 1234,
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = TokenStorage(prefs);

    expect(storage.hasToken, isFalse, reason: '未 hydrate 前不算已登录');

    await storage.hydrate();

    expect(storage.accessToken, 'old-access');
    expect(storage.refreshToken, 'old-refresh');
    expect(storage.expiresAt, 1234);
    expect(secureData['auth.access_token'], 'old-access');
    expect(prefs.getString('auth.access_token'), isNull, reason: '明文旧键必须删掉');
    expect(prefs.getInt('auth.expires_at'), isNull);
  });

  test('save 落盘、新实例 hydrate 能读回，clear 全清', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await TokenStorage(prefs).save(accessToken: 'a', refreshToken: 'r', expiresInSeconds: 60);

    final restored = TokenStorage(prefs);
    await restored.hydrate();
    expect(restored.accessToken, 'a');
    expect(restored.refreshToken, 'r');
    expect(restored.expiresAt, isNotNull);

    await restored.clear();

    final afterLogout = TokenStorage(prefs);
    await afterLogout.hydrate();
    expect(afterLogout.hasToken, isFalse);
    expect(secureData, isEmpty);
  });
}
