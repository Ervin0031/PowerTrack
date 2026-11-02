import 'package:dio/dio.dart';
import 'package:pretty_dio_clean_logger/pretty_dio_clean_logger.dart';

/// 请求/响应/错误日志拦截器。
///
/// 打印交给 [PrettyDioCleanLogger]。打印前把敏感字段换成副本，
/// 打完再还原，真实请求和响应不被改写。
class LoggingInterceptor extends Interceptor {
  /// [logPrint] 可注入自定义输出（测试用）。
  /// [logSensitive] 为 `true` 时输出原始内容（仅建议临时排障用）。
  LoggingInterceptor({void Function(Object object)? logPrint, this.logSensitive = false})
    : _logger = PrettyDioCleanLogger(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        compact: true,
        maxWidth: 120,
        logPrint: logPrint,
        // 是否挂上本拦截器由 [DioClient] 的 enableLogging 决定。
        enableLogOnRelease: true,
      );

  final PrettyDioCleanLogger _logger;
  final bool logSensitive;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (logSensitive) {
      _logger.onRequest(options, handler);
      return;
    }

    final headers = options.headers;
    final query = options.queryParameters;
    final data = options.data;
    options.headers = _stringKeyMap(sanitizeLogValue(headers));
    options.queryParameters = _stringKeyMap(sanitizeLogValue(query));
    options.data = sanitizeLogValue(data);

    _logger.onRequest(
      options,
      _RestoreRequestHandler(handler, () {
        options.headers = headers;
        options.queryParameters = query;
        options.data = data;
      }),
    );
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (logSensitive) {
      _logger.onResponse(response, handler);
      return;
    }

    final data = response.data;
    response.data = sanitizeLogValue(data);
    _logger.onResponse(
      response,
      _RestoreResponseHandler(handler, () => response.data = data),
    );
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (logSensitive || response == null) {
      _logger.onError(err, handler);
      return;
    }

    final data = response.data;
    response.data = sanitizeLogValue(data);
    _logger.onError(
      err,
      _RestoreErrorHandler(handler, () => response.data = data),
    );
  }
}

Map<String, dynamic> _stringKeyMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  return Map<String, dynamic>.from(value as Map);
}

/// 日志脱敏键名（小写匹配）：命中则值替换为 `***`。
const _sensitiveKeys = {
  'authorization',
  'password',
  'old_password',
  'new_password',
  'confirm_password',
  'token',
  'access_token',
  'refresh_token',
  'client_secret',
};

final _bearerPattern = RegExp(r'(Bearer\s+)\S+', caseSensitive: false);

/// 递归遮蔽敏感键，并把字符串里的 `Bearer xxx` 替换为 `Bearer ***`。
///
/// [logSensitive] 为 `true` 时原样返回（临时排障）。公开以便单测。
dynamic sanitizeLogValue(dynamic value, {bool logSensitive = false}) {
  if (logSensitive) return value;
  if (value is Map) {
    return value.map((key, v) {
      if (_sensitiveKeys.contains(key.toString().toLowerCase())) {
        return MapEntry(key, '***');
      }
      return MapEntry(key, sanitizeLogValue(v));
    });
  }
  if (value is List) return value.map((v) => sanitizeLogValue(v)).toList();
  if (value is String) return value.replaceAllMapped(_bearerPattern, (m) => '${m[1]}***');
  return value;
}

final class _RestoreRequestHandler extends RequestInterceptorHandler {
  _RestoreRequestHandler(this._inner, this._restore);

  final RequestInterceptorHandler _inner;
  final void Function() _restore;

  @override
  void next(RequestOptions requestOptions) {
    _restore();
    _inner.next(requestOptions);
  }
}

final class _RestoreResponseHandler extends ResponseInterceptorHandler {
  _RestoreResponseHandler(this._inner, this._restore);

  final ResponseInterceptorHandler _inner;
  final void Function() _restore;

  @override
  void next(Response<dynamic> response) {
    _restore();
    _inner.next(response);
  }
}

final class _RestoreErrorHandler extends ErrorInterceptorHandler {
  _RestoreErrorHandler(this._inner, this._restore);

  final ErrorInterceptorHandler _inner;
  final void Function() _restore;

  @override
  void next(DioException error) {
    _restore();
    _inner.next(error);
  }
}
