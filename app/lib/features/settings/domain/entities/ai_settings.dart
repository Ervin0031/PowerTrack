/// 用户自带 AI Key 的配置。Key 本身不在这里，只记录是否已保存。
class AiSettings {
  const AiSettings({
    required this.baseUrl,
    required this.model,
    required this.hasKey,
  });

  static const defaultBaseUrl = 'https://api.deepseek.com/v1';
  static const defaultModel = 'deepseek-flash';

  final String baseUrl;
  final String model;
  final bool hasKey;

  AiSettings copyWith({String? baseUrl, String? model, bool? hasKey}) {
    return AiSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      hasKey: hasKey ?? this.hasKey,
    );
  }
}

/// 未配置 Key 时抛出，UI 据此引导去设置页。
class AiNotConfiguredException implements Exception {
  const AiNotConfiguredException();

  @override
  String toString() => 'AI API Key 未配置';
}

/// 去掉尾部斜杠；补 `/v1`；容忍用户直接粘贴完整的 chat/completions 地址。
String normalizeAiBaseUrl(String input) {
  var text = input.trim();
  while (text.endsWith('/')) {
    text = text.substring(0, text.length - 1);
  }
  const suffix = '/chat/completions';
  if (text.endsWith(suffix)) {
    text = text.substring(0, text.length - suffix.length);
    while (text.endsWith('/')) {
      text = text.substring(0, text.length - 1);
    }
  }
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return text;
  if (uri.path.isEmpty || uri.path == '/') return '$text/v1';
  return text;
}

/// 返回校验错误；null 表示可用。只接受 HTTPS，本机回环地址允许 HTTP。
String? validateAiBaseUrl(String? input) {
  final text = normalizeAiBaseUrl(input ?? '');
  if (text.isEmpty) return '请输入接口地址';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return '接口地址格式不对';
  if (uri.userInfo.isNotEmpty) return '接口地址不能带账号密码';
  if (uri.hasQuery || uri.hasFragment) return '接口地址不能带查询参数或锚点';
  final loopback = uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
  if (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)) {
    return '请使用 HTTPS 地址（本机调试可用 http://localhost）';
  }
  return null;
}
