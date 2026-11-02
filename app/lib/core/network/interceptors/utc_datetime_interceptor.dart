import 'package:app_flutter/core/network/api_datetime.dart';
import 'package:dio/dio.dart';

/// 把响应里无时区的 datetime 标成 UTC（补 `Z`），修复全 app 展示偏时。
class UtcDateTimeInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    response.data = tagNaiveUtcInJson(response.data);
    handler.next(response);
  }
}
