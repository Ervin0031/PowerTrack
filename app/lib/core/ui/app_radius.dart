/// 圆角 token。
///
/// 规范标尺：8(小徽标/柱顶) / 12(输入框/缩略图/卡内块) / 24(卡片/面板) /
/// 28(弹层) / pill(胶囊)。锚点：cardTheme 24 = M3ESegmentedList.outerRadius；
/// 12 = AppNetworkImage 默认。
abstract final class AppRadius {
  static const double chip = 8;
  static const double field = 12;
  static const double card = 24;
  static const double sheet = 28;
  static const double pill = 999;
}
