import 'package:material_ui/material_ui.dart';

/// 安全区快捷扩展。
///
/// 适用于自定义全屏布局、底部按钮、沉浸式 AppBar 等需要读取刘海/手势区域的场景。
extension SafeAreaExt on BuildContext {
  EdgeInsets get safeAreaPadding => MediaQuery.paddingOf(this);
  /// `extendBodyBehindAppBar` 下内容顶部的安全留白（状态栏 + 工具栏）。
  /// 带 `bottom:` 的页面自行加 bottom 高度，用同一个文件级 const 驱动。
  double get appBarInset => kToolbarHeight + safeAreaPadding.top;
  double get safeTop => safeAreaPadding.top;
  double get safeBottom => safeAreaPadding.bottom;
  double get safeLeft => safeAreaPadding.left;
  double get safeRight => safeAreaPadding.right;
}
