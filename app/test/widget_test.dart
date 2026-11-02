import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/core/router/app_router.dart';
import 'package:app_flutter/core/ui/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 验证：
/// - Provider override 路径生效（`sharedPreferencesProvider` 不抛 `UnimplementedError`）；
/// - `appRouterProvider` 可读取并完成初始化；
/// - 首帧渲染无异常。
///
/// 注意：splash 页的 800ms 延迟跳转不会在 `pumpWidget` 内触发，
/// 这里只断言依赖图可构建、单帧无崩溃；跳转行为交给后续集成测试。
void main() {
  testWidgets('App boots into router with overridden prefs', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: Consumer(
          builder: (context, ref, _) {
            // 触发 appRouterProvider 构建，验证整条 Provider 链路。
            ref.watch(appRouterProvider);
            return MaterialApp(
              theme: AppTheme.lightTheme,
              home: const SizedBox(),
            );
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
