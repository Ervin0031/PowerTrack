import 'package:app_flutter/features/settings/domain/entities/ai_settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI Key 存系统安全存储，地址和模型存普通偏好；Key 不进入 Riverpod state。
class AiSettingsRepository {
  AiSettingsRepository(this._prefs, {FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const _kApiKey = 'ai.api_key';
  static const _kBaseUrl = 'ai.base_url';
  static const _kModel = 'ai.model';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<AiSettings> load() async {
    var hasKey = false;
    try {
      hasKey = (await _secure.read(key: _kApiKey))?.trim().isNotEmpty ?? false;
    } catch (_) {
      // 安全存储不可用时按未配置处理，不阻断设置页打开。
    }
    return AiSettings(
      baseUrl: _prefs.getString(_kBaseUrl) ?? AiSettings.defaultBaseUrl,
      model: _prefs.getString(_kModel) ?? AiSettings.defaultModel,
      hasKey: hasKey,
    );
  }

  /// 留空 [apiKey] 表示保留已保存的 Key。
  Future<void> save({
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    await _prefs.setString(_kBaseUrl, normalizeAiBaseUrl(baseUrl));
    await _prefs.setString(_kModel, model.trim());
    final key = apiKey?.trim();
    if (key != null && key.isNotEmpty) {
      await _secure.write(key: _kApiKey, value: key);
    }
  }

  Future<String?> readApiKey() async {
    try {
      final key = (await _secure.read(key: _kApiKey))?.trim();
      return key == null || key.isEmpty ? null : key;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearApiKey() => _secure.delete(key: _kApiKey);

  /// 发一次最小 chat 请求，验证 Key、地址和模型名。
  Future<void> testConnection({
    required String baseUrl,
    required String model,
    required String apiKey,
  }) async {
    final client = OpenAIClient(
      config: OpenAIConfig(
        authProvider: ApiKeyProvider(apiKey),
        baseUrl: normalizeAiBaseUrl(baseUrl),
        timeout: const Duration(seconds: 25),
        retryPolicy: const RetryPolicy(maxRetries: 0),
      ),
    );
    try {
      await client.chat.completions.create(
        ChatCompletionCreateRequest(
          model: model.trim(),
          messages: [ChatMessage.user('ping')],
          maxTokens: 1,
        ),
      );
    } finally {
      client.close();
    }
  }
}
