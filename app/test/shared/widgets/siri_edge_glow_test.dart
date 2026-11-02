import 'package:app_flutter/shared/widgets/siri_edge_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('空 Path 不抛 No element', () {
    expect(firstPathMetric(Path()), isNull);
  });

  test('圆角矩形能取出一条闭合路径', () {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 8, 200, 400),
          const Radius.circular(40),
        ),
      );
    final metric = firstPathMetric(path);
    expect(metric, isNotNull);
    expect(metric!.length, greaterThan(0));
  });

  testWidgets('点亮后 CustomPaint 能完成绘制', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SiriEdgeGlow(active: true))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
