import 'dart:convert';
import 'dart:typed_data';

import 'package:app_flutter/features/training/data/models/session_models.dart';
import 'package:app_flutter/features/training/data/repositories/session_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 前 [failures] 次请求返回 [status]，之后返回 200；同时记录实际请求次数。
class _FlakyAdapter implements HttpClientAdapter {
  _FlakyAdapter({this.failures = 0, this.status = 500});

  final int failures;
  final int status;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    final code = calls <= failures ? status : 200;
    return ResponseBody.fromString(
      jsonEncode({'id': 1}),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  SessionComplete body() => SessionComplete(
        clientUuid: 'u',
        startedAt: DateTime.utc(2026, 9, 2, 12),
        completedAt: DateTime.utc(2026, 9, 2, 13),
      );

  ({Dio dio, _FlakyAdapter adapter}) client(_FlakyAdapter adapter) {
    return (dio: Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter, adapter: adapter);
  }

  test('500 后自动重试，成功后不再重发', () async {
    final adapter = _FlakyAdapter(failures: 1);
    final c = client(adapter);

    await SessionRepository(c.dio).completeSession(1, body());

    expect(c.adapter.calls, 2, reason: '首次失败 + 一次重试');
  });

  test('4xx 不重试，直接抛', () async {
    final adapter = _FlakyAdapter(failures: 99, status: 400);
    final c = client(adapter);

    await expectLater(
      SessionRepository(c.dio).completeSession(1, body()),
      throwsA(isA<DioException>()),
    );
    expect(c.adapter.calls, 1, reason: '请求本身有问题，重试无意义');
  });
}
