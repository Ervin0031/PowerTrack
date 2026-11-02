import 'dart:convert';
import 'dart:typed_data';

import 'package:app_flutter/core/network/dio_client.dart';
import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/core/storage/token_storage.dart';
import 'package:app_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 模拟 HTTP 层：所有请求返回 401（如密码错误）。
class _UnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'status': 401,
        'error': 'Incorrect username or password, or email not verified',
      }),
      401,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 验证登录失败（401）时，登录页能正确捕获错误并弹出 SnackBar。
///
/// 关键点：
/// - 用 [DioClient.create]（含真实 Auth/Logging/Error 拦截器链）+ 自定义 HTTP 适配器，
///   完整走一遍生产环境的错误处理链路。
/// - 回归点：AsyncNotifier 状态切换会保留上一次 hasValue，登录失败后
///   AsyncError.hasValue 仍为 true，UI 必须先判 hasError 再判 hasValue。
void main() {
  testWidgets('登录 401 时显示错误 SnackBar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final dio = DioClient.create(
      baseUrl: 'http://mock',
      tokenStorage: TokenStorage.memory(),
    )..httpClientAdapter = _UnauthorizedAdapter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dioProvider.overrideWithValue(dio),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, '邮箱'),
      'root@powertrack.com',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '密码'), '12345678');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Incorrect username or password, or email not verified'),
      findsOneWidget,
    );
  });
}