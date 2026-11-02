import 'package:app_flutter/features/settings/data/repositories/ai_settings_repository.dart';
import 'package:app_flutter/features/settings/domain/entities/ai_settings.dart';
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

  test('接口地址归一化：去尾斜杠、补 /v1、兼容完整 completions 地址', () {
    expect(normalizeAiBaseUrl(' https://api.deepseek.com/v1/ '), 'https://api.deepseek.com/v1');
    expect(normalizeAiBaseUrl('https://api.deepseek.com'), 'https://api.deepseek.com/v1');
    expect(
      normalizeAiBaseUrl('https://api.deepseek.com/v1/chat/completions'),
      'https://api.deepseek.com/v1',
    );
  });

  test('接口地址校验：只放行 HTTPS，本机回环可用 HTTP', () {
    expect(validateAiBaseUrl(''), isNotNull);
    expect(validateAiBaseUrl('http://example.com/v1'), isNotNull);
    expect(validateAiBaseUrl('http://localhost:8080/v1'), isNull);
    expect(validateAiBaseUrl('http://127.0.0.1:8080/v1'), isNull);
    expect(validateAiBaseUrl('https://user:pass@example.com/v1'), isNotNull);
    expect(validateAiBaseUrl('https://example.com/v1?x=1'), isNotNull);
    expect(validateAiBaseUrl('https://api.deepseek.com/v1'), isNull);
  });

  test('Key 只写安全存储，偏好里只有地址和模型', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = AiSettingsRepository(prefs);

    await repo.save(
      baseUrl: 'https://api.deepseek.com/v1/',
      model: ' deepseek-flash ',
      apiKey: ' sk-test ',
    );

    expect(secureData['ai.api_key'], 'sk-test');
    expect(await repo.readApiKey(), 'sk-test');
    expect(prefs.getString('ai.api_key'), isNull);
    expect(prefs.getString('ai.base_url'), 'https://api.deepseek.com/v1');
    expect(prefs.getString('ai.model'), 'deepseek-flash');

    final loaded = await repo.load();
    expect(loaded.hasKey, isTrue);
    expect(loaded.baseUrl, 'https://api.deepseek.com/v1');
    expect(loaded.model, 'deepseek-flash');

    await repo.clearApiKey();
    expect(await repo.readApiKey(), isNull);
    expect((await repo.load()).hasKey, isFalse);
  });

  test('留空 apiKey 保留已存 Key', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = AiSettingsRepository(prefs);
    await repo.save(baseUrl: 'https://api.deepseek.com/v1', model: 'm', apiKey: 'k');

    await repo.save(baseUrl: 'https://api.deepseek.com/v1', model: 'm2');

    expect(await repo.readApiKey(), 'k');
  });
}
