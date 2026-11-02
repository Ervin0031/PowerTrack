import 'package:app_flutter/shared/widgets/app_menu_button.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 固定 400x800 视口，边缘断言基于该尺寸。
  Future<void> setViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host(Widget child, {AlignmentGeometry alignment = Alignment.center}) => MaterialApp(
    home: Scaffold(body: Stack(children: [Align(alignment: alignment, child: child)])),
  );

  AppMenuButton<String> menuButton({ValueChanged<AppMenuEntry<String>>? onSelected}) =>
      AppMenuButton<String>(
        label: '更多',
        items: const [
          AppMenuEntry(value: 'edit', label: '编辑'),
          AppMenuEntry(value: 'delete', label: '删除'),
        ],
        onSelected: onSelected,
      );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(AppMenuButton<String>));
    await tester.pump(); // 启动入场动画
    await tester.pumpAndSettle(); // 等弹簧收敛
  }

  testWidgets('点击按钮弹出菜单，选中后回传值并自动关闭', (tester) async {
    await setViewport(tester);
    AppMenuEntry<String>? selected;
    await tester.pumpWidget(host(menuButton(onSelected: (entry) => selected = entry)));
    await tester.pumpAndSettle();

    await openMenu(tester);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(selected?.value, 'edit');
    expect(find.text('编辑'), findsNothing, reason: '选中后菜单应关闭');
  });

  testWidgets('按钮贴屏幕左缘：菜单不越出左边界，点外部可关闭', (tester) async {
    await setViewport(tester);
    await tester.pumpWidget(host(menuButton(), alignment: Alignment.topLeft));
    await tester.pumpAndSettle();

    await openMenu(tester);
    // 菜单项文本左侧 = 菜单左缘 + 项内边距，应不小于 edgePadding(12)。
    expect(tester.getTopLeft(find.text('编辑')).dx, greaterThanOrEqualTo(12.0));

    await tester.tapAt(const Offset(390, 500));
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsNothing, reason: '点击菜单外部应关闭');
  });

  testWidgets('按钮贴屏幕右缘：菜单收进右边界内', (tester) async {
    await setViewport(tester);
    await tester.pumpWidget(host(menuButton(), alignment: Alignment.topRight));
    await tester.pumpAndSettle();

    await openMenu(tester);
    expect(
      tester.getTopRight(find.text('编辑')).dx,
      lessThanOrEqualTo(400 - 12.0),
      reason: '菜单右缘应不越过屏幕右边界减 edgePadding',
    );
  });

  testWidgets('按钮贴近屏幕底部：菜单自动翻转到按钮上方', (tester) async {
    await setViewport(tester);
    await tester.pumpWidget(host(menuButton(), alignment: Alignment.bottomCenter));
    await tester.pumpAndSettle();

    await openMenu(tester);
    final menuBottom = tester.getBottomRight(find.text('删除')).dy;
    final buttonTop = tester.getTopLeft(find.byType(AppMenuButton<String>)).dy;
    expect(menuBottom, lessThan(buttonTop), reason: '下方空间不足时菜单应在按钮上方展开');
  });

  testWidgets('dispose 后悬浮层被移除，不残留', (tester) async {
    await setViewport(tester);
    await tester.pumpWidget(host(menuButton()));
    await tester.pumpAndSettle();

    await openMenu(tester);
    expect(find.text('编辑'), findsOneWidget);

    // 整页替换（模拟路由被替换/页面销毁）。
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsNothing, reason: '按钮销毁时菜单悬浮层应一并移除');
  });

  testWidgets('菜单展开时按钮加背景色，关闭后恢复原样', (tester) async {
    await setViewport(tester);
    await tester.pumpWidget(host(menuButton()));
    await tester.pumpAndSettle();

    M3EButtonDecoration? buttonDecoration() {
      final button = tester.widget<M3EButton>(find.byType(M3EButton));
      return button.decoration;
    }

    expect(buttonDecoration(), isNull, reason: '菜单关闭时按钮无自定义装饰');

    await openMenu(tester);
    final open = buttonDecoration();
    expect(open, isNotNull, reason: '菜单展开时按钮应带背景装饰');
    expect(open!.backgroundColor, isNotNull, reason: '展开时应加背景色');

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(buttonDecoration(), isNull, reason: '菜单关闭后按钮装饰应恢复原样');
  });
}
