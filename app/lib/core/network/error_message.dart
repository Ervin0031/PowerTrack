import 'package:dio/dio.dart';

import 'api_exception.dart';

/// UI 展示用：仅业务文案，不含 Dio / ApiException 等包装前缀。
String userFacingErrorMessage(Object? error, {String fallback = '操作失败，请稍后重试'}) {
  if (error == null) return fallback;

  String? fromApi(ApiException api) {
    final m = api.message.trim();
    return m.isEmpty ? null : m;
  }

  if (error is ApiException) return fromApi(error) ?? fallback;

  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) return fromApi(inner) ?? fallback;

    final data = error.response?.data;
    if (data is Map) {
      for (final key in ['message', 'msg', 'error']) {
        final v = data[key];
        if (v is String) {
          final t = v.trim();
          if (t.isNotEmpty) return t;
        }
      }
    }

    final m = error.message?.trim();
    if (m != null && m.isNotEmpty) return m;
    return fallback;
  }

  final raw = error.toString();
  // 兜底：toString 默认值（"Instance of 'X'"、空串）一律回退到 fallback，
  // 避免给用户看到类名或空文案。
  if (raw.isEmpty || raw.startsWith("Instance of '") || raw == 'null') {
    return fallback;
  }
  return raw;
}
