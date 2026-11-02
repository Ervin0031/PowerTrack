import 'package:dio/dio.dart';

import '../api_exception.dart';

/// 将 [DioException] 统一映射为业务侧 [ApiException]，挂在 error 字段上。
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final exception = _map(err);
    // 保留原 request/response/type，把业务异常放进 error，便于上层 catch
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
        message: exception.message,
      ),
    );
  }

  /// [err] 按 Dio 错误类型分支映射
  ApiException _map(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkException('网络连接超时');
      case DioExceptionType.cancel:
        return const CancelException('请求已取消');
      case DioExceptionType.connectionError:
        return const NetworkException('网络连接失败');
      case DioExceptionType.badCertificate:
        return const NetworkException('证书校验失败');
      case DioExceptionType.badResponse:
        return _mapStatus(err);
      case DioExceptionType.unknown:
        return UnknownException(err.message ?? '未知错误');
    }
  }

  /// [err] 有响应体时按 HTTP 状态码映射
  ApiException _mapStatus(DioException err) {
    final status = err.response?.statusCode;
    final data = err.response?.data;
    final message = _extractMessage(data) ?? err.message ?? '请求失败';

    switch (status) {
      case 400:
        return BadRequestException(message, data: data);
      case 401:
        return UnauthorizedException(message, data: data);
      case 403:
        return ForbiddenException(message, data: data);
      case 404:
        return NotFoundException(message, data: data);
      case 409:
        return ConflictException(message, data: data);
      case 422:
        // FastAPI 参数校验错误：仍属于「请求不合法」，归入 400 语义。
        return BadRequestException(message, data: data);
      default:
        if (status != null && status >= 500) {
          return ServerException(message, statusCode: status, data: data);
        }
        return UnknownException(message, statusCode: status, data: data);
    }
  }

  /// 从后端 JSON 里取 message / error / msg / detail。
  ///
  /// FastAPI 校验失败的 422 响应体形如 `{"detail": [{"msg": "...", ...}]}`，
  /// 这里取第一条的 msg 作为用户可读文案。
  String? _extractMessage(dynamic data) {
    if (data is Map) {
      final m = data['message'] ?? data['error'] ?? data['msg'];
      if (m is String) return m;

      final detail = data['detail'];
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          final msg = first['msg'];
          if (msg is String && msg.isNotEmpty) return msg;
        }
      }
    }
    return null;
  }
}
