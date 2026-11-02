import 'package:app_flutter/core/network/interceptors/logging_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeLogValue', () {
    test('遮蔽敏感键，保留其余字段', () {
      final result = sanitizeLogValue({
        'email': 'a@b.com',
        'password': '12345678',
        'access_token': 'abc',
      });
      expect(result, {'email': 'a@b.com', 'password': '***', 'access_token': '***'});
    });

    test('递归处理嵌套 Map 与 List', () {
      final result = sanitizeLogValue({
        'data': [
          {'refresh_token': 'r1', 'name': 'keep'},
        ],
      });
      expect(result, {
        'data': [
          {'refresh_token': '***', 'name': 'keep'},
        ],
      });
    });

    test('字符串中的 Bearer 令牌被替换', () {
      expect(sanitizeLogValue('Bearer abc.def.ghi'), 'Bearer ***');
    });

    test('logSensitive 为 true 时原样返回', () {
      const raw = {'password': '12345678'};
      expect(sanitizeLogValue(raw, logSensitive: true), same(raw));
    });
  });

  test('PrettyDioCleanLogger 只脱敏日志，不改写请求和响应', () async {
    final lines = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.interceptors.add(LoggingInterceptor(logPrint: (object) => lines.add('$object')));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.data, {'email': 'a@b.com', 'password': 'secret-pass'});
          expect(options.headers['Authorization'], 'Bearer real-token');
          expect(options.queryParameters['token'], 'query-token');
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {'access_token': 'live-token', 'name': 'ada'},
            ),
          );
        },
      ),
    );

    final response = await dio.post<Map<String, dynamic>>(
      '/login',
      queryParameters: {'token': 'query-token'},
      data: {'email': 'a@b.com', 'password': 'secret-pass'},
      options: Options(headers: {'Authorization': 'Bearer real-token'}),
    );

    expect(response.data, {'access_token': 'live-token', 'name': 'ada'});
    final log = lines.join('\n');
    expect(log, contains('***'));
    expect(log, isNot(contains('secret-pass')));
    expect(log, isNot(contains('real-token')));
    expect(log, isNot(contains('query-token')));
    expect(log, isNot(contains('live-token')));
  });
}
