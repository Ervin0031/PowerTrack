import 'dart:async';

import 'package:openai_dart/openai_dart.dart';

/// 把第三方 AI 服务的异常转成固定中文文案。
///
/// 不拼接 provider 的 message / body / URL / Key，避免把密钥或服务端细节
/// 透到用户界面。调用方只在需要展示时使用。
String aiErrorMessage(Object error) {
  if (error is AuthenticationException) return 'API Key 无效或已过期';
  if (error is PermissionDeniedException) return '这个 Key 没有访问该模型的权限';
  if (error is RateLimitException) return 'AI 服务请求太频繁，请稍后再试';
  if (error is ApiException) {
    if (error.statusCode == 402) return 'AI 账户余额不足';
    if (error.statusCode == 400 ||
        error.statusCode == 404 ||
        error.statusCode == 422) {
      return '接口地址或模型名可能不对';
    }
    if (error.statusCode >= 500) return 'AI 服务暂时不可用';
    return 'AI 服务返回了错误（${error.statusCode}）';
  }
  if (error is RequestTimeoutException ||
      error is ConnectionException ||
      error is TimeoutException) {
    return '连接 AI 服务失败或超时';
  }
  return 'AI 请求失败，请稍后再试';
}
