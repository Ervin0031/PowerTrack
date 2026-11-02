import 'package:app_flutter/core/router/fade_forwards_page.dart';
import 'package:app_flutter/core/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('左缘滑动关闭 Fade Forwards 页面', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  FadeForwardsPage<void>(
                    child: const Text('下一页'),
                  ).createRoute(context),
                );
              },
              child: const Text('打开'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('下一页'), findsOneWidget);

    await tester.dragFrom(const Offset(8, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('下一页'), findsNothing);
    expect(find.text('打开'), findsOneWidget);
  });

  testWidgets('关闭手势后左缘滑动留在当前页', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  FadeForwardsPage<void>(
                    popGesture: false,
                    child: const Text('聊天'),
                  ).createRoute(context),
                );
              },
              child: const Text('打开'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(8, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('聊天'), findsOneWidget);
  });
}
