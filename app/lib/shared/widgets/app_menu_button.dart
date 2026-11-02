import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

/// 全局可用的 M3E 风格菜单按钮。
///
/// 内部用 [M3EButton] 作为触发器，点击后弹出锚定在按钮上的菜单面板：
/// - **边缘自适应**：菜单总是落在屏幕可视范围内（含安全区）。垂直方向优先
///   锚点下方、空间不足自动翻转到上方（向上生长，无需预知菜单高度）；水平
///   方向按按钮边缘对齐后收进屏幕内。
/// - **motor 弹簧动画**：入场用 [M3EMotion.standardPopup]（M3E 弹出菜单专用
///   弹簧，带轻微回弹），退场用 `expressiveEffectsFast`（快速无回弹）；缩放
///   原点朝向按钮一侧，菜单像「从按钮长出来」。
/// - **稳定关闭**：点外部 / 选中项 / 系统返回键 / Esc / 按钮所在列表滚动
///   均会关闭；按钮随页面销毁时悬浮层一并移除，不会残留。
///
/// ```dart
/// AppMenuButton<String>(
///   label: '更多',
///   items: [
///     AppMenuEntry(value: 'edit', label: '编辑', icon: Icons.edit_rounded),
///     AppMenuEntry(value: 'delete', label: '删除', icon: Icons.delete_rounded, isDestructive: true),
///   ],
///   onSelected: (entry) => handle(entry.value),
/// )
/// ```
///
/// 提供 [child] 时不再构建内置 M3EButton，改为包裹任意触发器组件（图标、
/// ListTile、自绘按钮等），点击即展开菜单，动画 / 定位 / 关闭行为完全一致：
///
/// ```dart
/// AppMenuButton<String>(
///   child: IconButton(onPressed: () {}, icon: Icon(Icons.more_vert)),
///   items: [AppMenuEntry(value: 'share', label: '分享')],
///   onSelected: (entry) => handle(entry.value),
/// )
/// ```
class AppMenuButton<T> extends StatefulWidget {
  const AppMenuButton({
    super.key,
    required this.items,
    this.onSelected,
    this.child,
    this.label,
    this.icon,
    this.iconSize,
    this.style = M3EButtonStyle.tonal,
    this.size = M3EButtonSize.md,
    this.shape = M3EButtonShape.round,
    this.circular = false,
    this.enabled = true,
    this.semanticLabel,
    this.buttonPadding,
    this.controller,
    this.onOpen,
    this.onClose,
    this.menuWidth,
    this.maxHeight,
    this.edgePadding = 12,
    this.gap = 8,
    this.verticalPlacement = AppMenuVerticalPlacement.auto,
    this.horizontalPlacement = AppMenuHorizontalPlacement.auto,
    this.surfaceColor,
    this.itemHeight = 48,
    this.cornerRadius = 24,
    this.elevation = 3,
    this.header,
    this.barrierColor,
    this.dismissOnOutsideTap = true,
    this.closeOnScroll = true,
    this.closeOnRoutePop = true,
    this.closeOnSelect = true,
    this.enableHaptics = true,
    this.motion = M3EMotion.standardPopup,
    this.useRootOverlay = true,
    this.selectable = false,
  }) : assert(items.length > 0, '菜单至少需要一个 AppMenuEntry');

  /// 菜单项列表，至少一项。
  final List<AppMenuEntry<T>> items;

  /// 选中某项时回调（该项自带 [AppMenuEntry.onTap] 时不会触发）。
  final ValueChanged<AppMenuEntry<T>>? onSelected;

  /// 自定义触发器；提供时替代内置 M3EButton，点击该组件即展开菜单。
  final Widget? child;

  // ---- 触发按钮（透传 M3EButton）----

  /// 按钮文字；与 [icon] 同时提供时使用 M3EButton.icon 布局。
  final String? label;

  /// 按钮图标。
  final IconData? icon;

  /// 触发按钮图标尺寸；null 用 M3E 按按钮尺寸推导的默认值。
  final double? iconSize;

  /// M3E 按钮风格，默认 tonal。
  final M3EButtonStyle style;

  /// M3E 按钮尺寸。
  final M3EButtonSize size;

  /// M3E 按钮形状（round 药丸 / square 圆角矩形）。
  final M3EButtonShape shape;

  /// 触发按钮是否为圆形（固定为正方形 + 半径一半）。
  final bool circular;

  /// 是否可用。
  final bool enabled;

  /// 按钮无障碍语义标签。
  final String? semanticLabel;

  /// 触发按钮内边距；null 用 M3EButton 默认值。
  final EdgeInsetsGeometry? buttonPadding;

  // ---- 编程式控制 / 生命周期 ----

  /// 外部控制器：`open()` / `close()` / `toggle()` / `isOpen`。
  final AppMenuController? controller;

  /// 菜单开始展开时回调。
  final VoidCallback? onOpen;

  /// 菜单完全关闭（含退场动画结束）后回调。
  final VoidCallback? onClose;

  // ---- 定位 ----

  /// 菜单宽度；null 时默认 260，且始终不超过屏幕减去边距。
  final double? menuWidth;

  /// 菜单最大高度；超出内部滚动。null 不额外限制（仍受屏幕约束）。
  final double? maxHeight;

  /// 菜单距屏幕边缘的最小间距（与安全区取大者）。
  final double edgePadding;

  /// 菜单与按钮的间距。
  final double gap;

  /// 垂直放置偏好；auto 时选空间更宽裕的一侧。
  final AppMenuVerticalPlacement verticalPlacement;

  /// 水平对齐偏好；auto / start 时与按钮「起始边」对齐，越界后自动收进屏幕。
  final AppMenuHorizontalPlacement horizontalPlacement;

  // ---- 外观 ----

  /// 菜单底色；null 用 `colorScheme.surfaceContainer`。
  final Color? surfaceColor;

  /// 单个菜单项高度。
  final double itemHeight;

  /// 菜单圆角（M3E 超椭圆形状）。
  final double cornerRadius;

  /// 菜单投影高度。
  final double elevation;

  /// 菜单顶部自定义内容（如标题），在菜单项之上。
  final Widget? header;

  /// 遮罩颜色；null 为全透明（默认，仅拦截点击）。
  final Color? barrierColor;

  // ---- 行为开关 ----

  /// 点击菜单外部是否关闭。
  final bool dismissOnOutsideTap;

  /// 按钮所在的可滚动容器开始滚动时是否自动关闭（M3 行为）。
  final bool closeOnScroll;

  /// 系统返回键 / 路由 pop 是否先关闭菜单而不是离开页面。
  final bool closeOnRoutePop;

  /// 选中菜单项后是否自动关闭。
  final bool closeOnSelect;

  /// 选中时是否触发轻微触感反馈。
  final bool enableHaptics;

  /// 入场弹簧（M3E 动效令牌）；退场固定用 expressiveEffectsFast。
  final M3EMotion motion;

  /// 菜单是否插入根 Overlay（默认 true，不受嵌套 Navigator 影响）。
  final bool useRootOverlay;

  /// 是否「记住选择」型菜单（如组数选择）：
  ///
  /// - `true`：点击切换选中态，选中项高亮（[AppMenuEntry.selected] 驱动的
  ///   `selectedIndices` 实时变化），同时仍触发 [onSelected] 供外部处理。
  /// - `false`（默认）：普通动作菜单，点击即触发 [onSelected] 并关闭，无选中态。
  final bool selectable;

  @override
  State<AppMenuButton<T>> createState() => _AppMenuButtonState<T>();
}

/// 垂直放置偏好。
enum AppMenuVerticalPlacement {
  /// 自动：选按钮下方 / 上方中空间更宽裕的一侧。
  auto,

  /// 强制按钮下方。
  below,

  /// 强制按钮上方。
  above,
}

/// 水平对齐偏好。
enum AppMenuHorizontalPlacement {
  /// 自动：与按钮起始边对齐（RTL 反转），越界后收进屏幕。
  auto,

  /// 与按钮起始边对齐（LTR 为左对齐）。
  start,

  /// 与按钮结束边对齐（LTR 为右对齐）。
  end,

  /// 水平居中于按钮。
  center,
}

/// 程序化控制 [AppMenuButton] 的开合。
///
/// ```dart
/// final menuController = AppMenuController();
/// AppMenuButton(controller: menuController, ...);
/// menuController.toggle(); // 在任意处触发
/// ```
class AppMenuController {
  _AppMenuBridge? _bridge;

  void _attach(_AppMenuBridge bridge) => _bridge = bridge;

  void _detach(_AppMenuBridge bridge) {
    if (identical(_bridge, bridge)) _bridge = null;
  }

  /// 菜单当前是否处于展开状态（含退场动画中）。
  bool get isOpen => _bridge?._getIsOpen() ?? false;

  /// 展开菜单；按钮未挂载时静默忽略。
  void open() => _bridge?._open();

  /// 关闭菜单（带退场动画）。
  void close() => _bridge?._close();

  /// 未展开则展开，已展开则关闭。
  void toggle() => _bridge?._toggle();
}

/// [AppMenuController] 与按钮 State 之间的私有桥接（同库内可见）。
abstract interface class _AppMenuBridge {
  void _open();
  void _close();
  void _toggle();
  bool _getIsOpen();
}

class _AppMenuButtonState<T> extends State<AppMenuButton<T>>
    implements _AppMenuBridge, PopEntry<Object?> {
  OverlayEntry? _entry;
  bool _isOpen = false;
  ScrollableState? _parentScrollable;

  // ---- 返回键拦截（PopEntry）----
  ModalRoute<Object?>? _route;
  bool _popEntryRegistered = false;
  // 菜单展开期间 false：系统返回先关菜单；关闭/退场即恢复 true，允许正常返回。
  final ValueNotifier<bool> _canPop = ValueNotifier<bool>(true);

  @override
  ValueListenable<bool> get canPopNotifier => _canPop;

  @override
  void onPopInvoked(bool didPop) => onPopInvokedWithResult(didPop, null);

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (!didPop && _isOpen) close();
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant AppMenuButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    // 按钮随页面销毁：直接摘除悬浮层与监听，不做退场动画（页面已不在）。
    _entry?.remove();
    _entry = null;
    _parentScrollable?.position.isScrollingNotifier.removeListener(_onScroll);
    _parentScrollable = null;
    if (_popEntryRegistered) {
      _route?.unregisterPopEntry(this);
      _popEntryRegistered = false;
    }
    _route = null;
    _canPop.dispose();
    widget.controller?._detach(this);
    super.dispose();
  }

  // ---- _AppMenuBridge ----

  @override
  void _open() => show();

  @override
  void _close() => close();

  @override
  void _toggle() => _isOpen ? close() : show();

  @override
  bool _getIsOpen() => _isOpen;

  // ---- 开合 ----

  /// 展开菜单（幂等；退场动画未结束时复用同一覆盖层直接反向展开）。
  void show() {
    if (_isOpen || !mounted || !widget.enabled || widget.items.isEmpty) return;

    if (_entry != null) {
      // 上一次退场动画尚未结束：不重复插入覆盖层，直接翻回展开态，
      // 滚动 / 返回键监听仍挂着，动画由 spring 从当前值无缝续接。
      setState(() => _isOpen = true);
      _canPop.value = false;
      _entry!.markNeedsBuild();
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    setState(() => _isOpen = true);
    _entry = OverlayEntry(builder: (_) => _buildOverlayPanel());
    Overlay.of(context, rootOverlay: widget.useRootOverlay).insert(_entry!);

    // 按钮所在可滚动容器开始滚动时自动关闭（菜单自身的滚动不受影响）。
    if (widget.closeOnScroll) {
      _parentScrollable = Scrollable.maybeOf(context);
      _parentScrollable?.position.isScrollingNotifier.addListener(_onScroll);
    }

    // 系统返回键先关菜单而不是离开页面。
    if (widget.closeOnRoutePop && !_popEntryRegistered) {
      _route = ModalRoute.of(context);
      if (_route != null) {
        _canPop.value = false;
        _route!.registerPopEntry(this);
        _popEntryRegistered = true;
      }
    }
    widget.onOpen?.call();
  }

  /// 关闭菜单（带退场动画，幂等）；监听器等退场结束后再统一拆除。
  void close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _canPop.value = true;
    _entry?.markNeedsBuild();
  }

  void _teardownListeners() {
    _parentScrollable?.position.isScrollingNotifier.removeListener(_onScroll);
    _parentScrollable = null;
  }

  void _onScroll() {
    if (_parentScrollable?.position.isScrollingNotifier.value ?? false) close();
  }

  void _select(AppMenuEntry<T> entry) {
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    if (widget.closeOnSelect) close();
    if (entry.onTap != null) {
      entry.onTap!();
    } else {
      widget.onSelected?.call(entry);
    }
  }

  Widget _buildOverlayPanel() {
    return _MenuPanel<T>(
      anchorRect: _anchorRect(),
      items: widget.items,
      visible: _isOpen,
      onSelected: _select,
      onDismiss: widget.dismissOnOutsideTap ? close : null,
      onExitComplete: () {
        _teardownListeners();
        _entry?.remove();
        _entry = null;
        if (_popEntryRegistered) {
          _route?.unregisterPopEntry(this);
          _popEntryRegistered = false;
          _route = null;
        }
        widget.onClose?.call();
      },
      menuWidth: widget.menuWidth,
      maxHeight: widget.maxHeight,
      edgePadding: widget.edgePadding,
      gap: widget.gap,
      verticalPlacement: widget.verticalPlacement,
      horizontalPlacement: widget.horizontalPlacement,
      surfaceColor: widget.surfaceColor,
      itemHeight: widget.itemHeight,
      cornerRadius: widget.cornerRadius,
      elevation: widget.elevation,
      header: widget.header,
      barrierColor: widget.barrierColor,
      entranceMotion: widget.motion.toMotion(),
      exitMotion: M3EMotion.expressiveEffectsFast.toMotion(),
      selectable: widget.selectable,
    );
  }

  Rect _anchorRect() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    void press() => show();

    // 自定义触发器：包裹任意组件，点击展开菜单。
    if (widget.child != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? press : null,
        child: widget.child,
      );
    }

    final hasIcon = widget.icon != null;
    final hasLabel = widget.label != null;
    final h = widget.circular
        ? M3EButtonTokensAdapter(context).measurements(widget.size).height
        : null;
    final openColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    // 菜单展开时给触发按钮加背景色 + 轻微圆角（M3E 弹出状态），关闭后恢复原样。
    final openState = _isOpen
        ? M3EButtonDecoration(
            backgroundColor: WidgetStatePropertyAll(openColor),
            borderRadius: widget.circular ? h! / 2 : 12,
          )
        : null;
    final baseDecoration =
        widget.buttonPadding == null &&
            !widget.circular &&
            widget.iconSize == null
        ? null
        : M3EButtonDecoration(
            padding: widget.buttonPadding,
            fixedSize: widget.circular ? Size.square(h!) : null,
            borderRadius: widget.circular ? h! / 2 : null,
            iconSize: widget.iconSize,
          );
    // 叠加：open 状态样式优先，其余透传 base。
    final decoration = openState == null
        ? baseDecoration
        : M3EButtonDecoration(
            backgroundColor: openState.backgroundColor,
            borderRadius: openState.borderRadius,
            padding: baseDecoration?.padding,
            fixedSize: baseDecoration?.fixedSize,
            iconSize: baseDecoration?.iconSize,
          );

    final Widget button;
    if (hasIcon && hasLabel) {
      button = M3EButton.icon(
        onPressed: press,
        style: widget.style,
        size: widget.size,
        shape: widget.shape,
        enabled: widget.enabled,
        semanticLabel: widget.semanticLabel,
        decoration: decoration,
        icon: Icon(widget.icon),
        label: Text(widget.label!),
      );
    } else if (hasIcon) {
      button = M3EButton(
        onPressed: press,
        style: widget.style,
        size: widget.size,
        shape: widget.shape,
        enabled: widget.enabled,
        semanticLabel: widget.semanticLabel,
        decoration: decoration,
        child: Icon(widget.icon),
      );
    } else {
      button = M3EButton(
        onPressed: press,
        style: widget.style,
        size: widget.size,
        shape: widget.shape,
        enabled: widget.enabled,
        semanticLabel: widget.semanticLabel,
        decoration: decoration,
        child: Text(widget.label ?? '菜单'),
      );
    }

    if (!widget.circular) return button;
    // 圆形成型于外层：Center 松掉父级强约束（如 AppBar.leading 的 56 宽），
    // SizedBox 锁死正方形，避免按钮被拉伸变形。
    return Center(
      child: SizedBox.square(dimension: h!, child: button),
    );
  }
}

/// 菜单的最终定位结果（屏幕坐标 + 生长原点）。
class _MenuLayout {
  const _MenuLayout({
    required this.left,
    required this.width,
    required this.maxHeight,
    required this.origin,
    this.top,
    this.bottom,
  });

  final double left;
  final double? top;
  final double? bottom;
  final double width;
  final double maxHeight;

  /// 缩放/淡入的生长原点，指向按钮一侧。
  final Alignment origin;
}

/// 覆盖层中的菜单面板：负责定位、遮罩与 motor 弹簧动画。
class _MenuPanel<T> extends StatefulWidget {
  const _MenuPanel({
    required this.anchorRect,
    required this.items,
    required this.visible,
    required this.onSelected,
    required this.onExitComplete,
    this.onDismiss,
    this.menuWidth,
    this.maxHeight,
    required this.edgePadding,
    required this.gap,
    required this.verticalPlacement,
    required this.horizontalPlacement,
    this.surfaceColor,
    required this.itemHeight,
    required this.cornerRadius,
    required this.elevation,
    this.header,
    this.barrierColor,
    required this.entranceMotion,
    required this.exitMotion,
    this.selectable = false,
  });

  final Rect anchorRect;
  final List<AppMenuEntry<T>> items;
  final bool visible;
  final ValueChanged<AppMenuEntry<T>> onSelected;
  final VoidCallback? onDismiss;
  final VoidCallback onExitComplete;
  final double? menuWidth;
  final double? maxHeight;
  final double edgePadding;
  final double gap;
  final AppMenuVerticalPlacement verticalPlacement;
  final AppMenuHorizontalPlacement horizontalPlacement;
  final Color? surfaceColor;
  final double itemHeight;
  final double cornerRadius;
  final double elevation;
  final Widget? header;
  final Color? barrierColor;
  final Motion entranceMotion;
  final Motion exitMotion;

  /// 是否「记住选择」型菜单（见 [AppMenuButton.selectable]）。
  final bool selectable;

  @override
  State<_MenuPanel<T>> createState() => _MenuPanelState<T>();
}

class _MenuPanelState<T> extends State<_MenuPanel<T>> {
  /// 当前选中的菜单项索引（初始来自 [AppMenuEntry.selected]）。
  Set<int> _selectedIndices = <int>{};

  @override
  void initState() {
    super.initState();
    _syncSelectedIndices();
  }

  @override
  void didUpdateWidget(covariant _MenuPanel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) _syncSelectedIndices();
  }

  /// 由入口数据里的 [AppMenuEntry.selected] 初始化选中集。
  void _syncSelectedIndices() {
    _selectedIndices = {
      for (var i = 0; i < widget.items.length; i++)
        if (widget.items[i].selected) i,
    };
  }

  @override
  Widget build(BuildContext context) {
    final layout = _resolveLayout(context);
    final motion = widget.visible ? widget.entranceMotion : widget.exitMotion;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onDismiss?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SingleMotionBuilder(
        // visible: false → true 入场，true → false 退场；spring 从当前值无缝续接。
        value: widget.visible ? 1.0 : 0.0,
        from: 0.0,
        motion: motion,
        onAnimationStatusChanged: (status) {
          // 退场回到初始值 0 后再移除覆盖层，避免动画被截断。
          if (!widget.visible && status == AnimationStatus.dismissed) {
            widget.onExitComplete();
          }
        },
        builder: (context, progress, child) {
          final menu = child!;
          return Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: progress.clamp(0.0, 1.0).toDouble(),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDismiss,
                    excludeFromSemantics: true,
                    child: widget.barrierColor == null
                        ? const SizedBox.expand()
                        : ColoredBox(color: widget.barrierColor!),
                  ),
                ),
              ),
              Positioned(
                left: layout.left,
                top: layout.top,
                bottom: layout.bottom,
                width: layout.width,
                child: Opacity(
                  opacity: progress.clamp(0.0, 1.0).toDouble(),
                  child: Transform.scale(
                    // 用未 clamp 的 progress，弹簧回弹（>1）得以保留。
                    scale: 0.8 + 0.2 * progress,
                    alignment: layout.origin,
                    child: menu,
                  ),
                ),
              ),
            ],
          );
        },
        child: _buildMenuSurface(context, layout),
      ),
    );
  }

  /// 计算菜单在屏幕内的最终位置。
  ///
  /// 垂直：auto 时选空间更宽裕的一侧；above 用 `bottom` 锚定让菜单向上生长，
  /// 因此无需预知菜单实际高度即可保证不超出屏幕。水平：按偏好与按钮对齐，
  /// 再整体收进 `[padL, 屏宽 - padR - menuW]`。旋转屏幕时依赖 MediaQuery
  /// 触发重建自动重排。
  _MenuLayout _resolveLayout(BuildContext context) {
    final anchor = widget.anchorRect;
    if (anchor == Rect.zero) {
      return _MenuLayout(
        left: 0,
        width: 0,
        maxHeight: 0,
        origin: Alignment.topLeft,
      );
    }

    final mq = MediaQuery.of(context);
    final screen = mq.size;
    final vp = mq.viewPadding;
    final padL = math.max(widget.edgePadding, vp.left);
    final padR = math.max(widget.edgePadding, vp.right);
    final padT = math.max(widget.edgePadding, vp.top);
    final padB = math.max(widget.edgePadding, vp.bottom);

    final maxAvailableW = math.max(0.0, screen.width - padL - padR);
    final width = (widget.menuWidth ?? math.min(260.0, maxAvailableW))
        .clamp(0.0, maxAvailableW)
        .toDouble();

    final spaceBelow = screen.height - padB - anchor.bottom - widget.gap;
    final spaceAbove = anchor.top - padT - widget.gap;
    final below = switch (widget.verticalPlacement) {
      AppMenuVerticalPlacement.below => true,
      AppMenuVerticalPlacement.above => false,
      AppMenuVerticalPlacement.auto => spaceBelow >= spaceAbove,
    };

    final availableH = below ? spaceBelow : spaceAbove;
    final maxHeight = availableH
        .clamp(0.0, widget.maxHeight ?? double.infinity)
        .toDouble();

    final double? top;
    final double? bottom;
    if (below) {
      top = anchor.bottom + widget.gap;
      bottom = null;
    } else {
      top = null;
      bottom = screen.height - anchor.top + widget.gap;
    }

    final rtl = Directionality.of(context) == TextDirection.rtl;
    final double rawLeft = switch (widget.horizontalPlacement) {
      AppMenuHorizontalPlacement.start || AppMenuHorizontalPlacement.auto =>
        rtl ? anchor.right - width : anchor.left,
      AppMenuHorizontalPlacement.end =>
        rtl ? anchor.left : anchor.right - width,
      AppMenuHorizontalPlacement.center => anchor.center.dx - width / 2,
    };
    final left = rawLeft
        .clamp(padL, math.max(padL, screen.width - padR - width))
        .toDouble();

    // 缩放原点朝向按钮一侧，让菜单「从按钮长出来」。
    final originX = (left - anchor.left).abs() < 1
        ? -1.0
        : (left + width - anchor.right).abs() < 1
        ? 1.0
        : 0.0;

    return _MenuLayout(
      left: left,
      top: top,
      bottom: bottom,
      width: width,
      maxHeight: maxHeight,
      origin: Alignment(originX, below ? -1 : 1),
    );
  }

  Widget _buildMenuSurface(BuildContext context, _MenuLayout layout) {
    final cs = Theme.of(context).colorScheme;
    final maxH = layout.maxHeight;

    final menu = Material(
      color: widget.surfaceColor ?? cs.surfaceContainer,
      shadowColor: cs.shadow,
      elevation: widget.elevation,
      clipBehavior: Clip.antiAlias,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(widget.cornerRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.header != null) widget.header!,
          Flexible(
            child: SingleChildScrollView(
              child: M3ESegmentedColumn(
                // 普通动作菜单不启用选中态；selectable 菜单用 multiple 记住选择。
                selectionMode: widget.selectable
                    ? M3ESelectionMode.multiple
                    : M3ESelectionMode.none,
                selectionTrigger: M3ESelectionTrigger.tap,
                selectedIndices: _selectedIndices,
                onSelectionChanged: (set) =>
                    setState(() => _selectedIndices = set),
                onTap: (index) {
                  final entry = widget.items[index];
                  if (entry.enabled) widget.onSelected(entry);
                },
                decoration: M3ESegmentedListDecoration(
                  outerRadius: 20.0,
                  innerRadius: 4.0,
                  pressedRadius: 8.0,
                  hoveredRadius: 16.0,
                  selectedRadius: 28.0,
                  gap: 2.0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  margin: const EdgeInsets.all(6),
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                ),
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    _MenuItem(
                      entry: widget.items[i],
                      height: widget.itemHeight,
                      selected:
                          widget.selectable && _selectedIndices.contains(i),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final constrained = maxH.isFinite && maxH > 0
        ? ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: menu,
          )
        : menu;

    // 吸收菜单表面空白处的点击，避免落空后误触遮罩关闭。
    return GestureDetector(onTap: () {}, child: constrained);
  }
}

/// 单个菜单项：图标 + 文本 + 尾部内容，支持禁用 / 危险操作 / 选中态。
///
/// 纯展示组件，点击由外层 [M3ESegmentedColumn] 统一处理（避免嵌套 InkWell 吞掉点击）。
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.entry,
    required this.height,
    this.selected = false,
  });

  final AppMenuEntry<dynamic> entry;
  final double height;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = entry.enabled;
    final base = entry.color ?? (entry.isDestructive ? cs.error : cs.onSurface);
    final contentColor = enabled ? base : base.withValues(alpha: 0.38);

    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (entry.icon != null) ...[
            Icon(entry.icon, size: 22, color: contentColor),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              entry.label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: contentColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (entry.trailing != null)
            entry.trailing!
          else if (selected)
            Icon(Symbols.check_rounded, size: 20, color: cs.primary),
        ],
      ),
    );
  }
}

/// 菜单项数据。
///
/// [value] 经 `onSelected` 透传给调用方；[icon] / [trailing] / [selected] /
/// [isDestructive] 控制外观；[onTap] 提供时替代全局 [AppMenuButton.onSelected]。
class AppMenuEntry<T> {
  const AppMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
    this.isDestructive = false,
    this.selected = false,
    this.color,
    this.trailing,
    this.onTap,
  });

  /// 选中后回传给调用方的业务值。
  final T value;

  /// 菜单项文本。
  final String label;

  /// 左侧图标。
  final IconData? icon;

  /// 是否可点；禁用时文本图标降透明度且不响应。
  final bool enabled;

  /// 危险操作（如删除），使用 error 配色。
  final bool isDestructive;

  /// 自定义文本/图标颜色；优先级高于 [isDestructive] 的 error 配色。
  final Color? color;

  /// 选中态，尾部自动显示 ✓。
  final bool selected;

  /// 自定义尾部内容，优先级高于 [selected] 的 ✓。
  final Widget? trailing;

  /// 单项独立回调；提供时不再触发全局 onSelected。
  final VoidCallback? onTap;
}
