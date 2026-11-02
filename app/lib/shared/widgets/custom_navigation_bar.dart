import 'dart:ui';

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

// ============================================================================
// BottomNavItem & BottomNavActionButton
// ============================================================================

class BottomNavItem {
  final PhosphorDuotoneIconData icon;
  final String label;

  const BottomNavItem({required this.icon, required this.label});
}

class BottomNavActionButton {
  final PhosphorDuotoneIconData icon;
  final VoidCallback onPressed;

  const BottomNavActionButton({required this.icon, required this.onPressed});
}

/// 对应 iOS 26 `tabBarMinimizeBehavior` / `UITabBarController.MinimizeBehavior`。
enum TabBarMinimizeBehavior {
  /// 不缩小（iOS/iPadOS 默认）。
  never,

  /// 向下滚动时收成选中 Tab 胶囊，向上滚动时展开。
  onScrollDown,

  /// 向上滚动时收起，向下滚动时展开（底部锚定内容用）。
  onScrollUp,
}

// ============================================================================
// AppBottomNavigationBar
// ============================================================================

class AppBottomNavigationBar extends StatefulWidget {
  final List<BottomNavItem> items;
  final Function(int) onTabChanged;
  final int initialIndex;
  final BottomNavActionButton? secondaryButton;
  final bool isTrain;
  final Widget? topWidget;

  // --- 可配置参数（尺寸/弧度参考 iOS 胶囊 Tab Bar 比例，视觉走 M3） ---
  final double height;
  final EdgeInsetsGeometry margin;
  final double innerPadding;
  final double borderWidth;
  final double buttonSpacing;
  final Duration animationDuration;

  // --- 毛玻璃配置 ---
  final double blurSigma;
  final double bgAlpha;

  // --- 滚动联动：iOS 26 tabBarMinimizeBehavior(.onScrollDown) ---
  // 传入当前 Tab 页的主 ScrollController；向下滚动时导航栏收成
  // 仅含选中项的胶囊，向上滚动时展开；有 topWidget 时收成
  // 「左选中胶囊 | 中间配件 | 右次要胶囊」布局。
  final ScrollController? scrollController;
  final TabBarMinimizeBehavior minimizeBehavior;
  // 距顶部多少像素内强制展开，避免顶部回弹误触。
  final double minimizeStartOffset;
  // 同方向连续滚动累计达到该像素后才切换收起/展开（越大越不敏感）。
  final double minimizeDeltaThreshold;

  const AppBottomNavigationBar({
    super.key,
    this.items = const [BottomNavItem(icon: PhosphorIconsDuotone.storefront, label: '训练')],
    required this.onTabChanged,
    this.initialIndex = 0,
    this.secondaryButton,
    this.isTrain = false,
    this.topWidget,
    this.height = 64.0,
    this.margin = const EdgeInsets.only(left: 14, right: 14, bottom: 20),
    this.innerPadding = 3.0,
    this.borderWidth = .3,
    this.buttonSpacing = 8.0,
    this.animationDuration = const Duration(milliseconds: 280),
    this.blurSigma = 12.0,
    this.bgAlpha = .75,
    this.scrollController,
    this.minimizeBehavior = TabBarMinimizeBehavior.onScrollDown,
    this.minimizeStartOffset = 48.0,
    this.minimizeDeltaThreshold = 36.0,
  });

  @override
  State<AppBottomNavigationBar> createState() => _AppBottomNavigationBarState();
}

class _AppBottomNavigationBarState extends State<AppBottomNavigationBar> {
  late int _selectedIndex;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  int? _pressedIndex;

  /// true = 已收成选中胶囊；由滚动方向驱动，经弹簧插值到 0→1。
  bool _isMinimized = false;
  double _lastScrollOffset = 0.0;

  /// 同方向累计位移，达到 [minimizeDeltaThreshold] 才切换，降低灵敏度。
  double _scrollDirectionAccum = 0.0;
  ScrollDirection _lastToggleDirection = ScrollDirection.idle;

  /// 保证 topWidget 在「上方展开 / 行内收起」之间切换时只挂载一份（Heroine 需要）。
  final GlobalKey _accessoryKey = GlobalKey();

  double get _outerRadius => widget.height / 2;
  double get _innerRadius =>
      widget.innerPadding > 0 ? _outerRadius - widget.innerPadding - widget.borderWidth : _outerRadius;
  double get _innerHeight => widget.height - (widget.innerPadding * 2) - (widget.borderWidth * 2);
  double get _compactWidth => widget.height;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _attachScroll(widget.scrollController);
  }

  @override
  void didUpdateWidget(covariant AppBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _detachScroll(oldWidget.scrollController);
      _attachScroll(widget.scrollController);
      _setMinimized(false);
      _scrollDirectionAccum = 0;
      _lastToggleDirection = ScrollDirection.idle;
      _lastScrollOffset = widget.scrollController?.hasClients == true ? widget.scrollController!.offset : 0.0;
    }
    if (oldWidget.initialIndex != widget.initialIndex && widget.initialIndex != _selectedIndex) {
      _selectedIndex = widget.initialIndex;
      _setMinimized(false);
    }
    if (oldWidget.minimizeBehavior != widget.minimizeBehavior &&
        widget.minimizeBehavior == TabBarMinimizeBehavior.never) {
      _setMinimized(false);
    }
  }

  @override
  void dispose() {
    _detachScroll(widget.scrollController);
    super.dispose();
  }

  void _attachScroll(ScrollController? controller) {
    controller?.addListener(_handleScroll);
    if (controller != null && controller.hasClients) {
      _lastScrollOffset = controller.offset;
    }
  }

  void _detachScroll(ScrollController? controller) {
    controller?.removeListener(_handleScroll);
  }

  /// 映射自 iOS 26 MinimizeBehavior：同方向累计滚动超过阈值后才切换。
  /// reverse = 向下浏览（内容上移）→ onScrollDown 时收起。
  void _handleScroll() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    if (widget.minimizeBehavior == TabBarMinimizeBehavior.never) return;

    final offset = controller.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;

    // 忽略 Tab 切换等造成的大幅跳变。
    if (delta.abs() > 120) {
      _scrollDirectionAccum = 0;
      return;
    }

    // 顶部区域始终展开，并清空累计。
    if (offset <= widget.minimizeStartOffset) {
      _scrollDirectionAccum = 0;
      _lastToggleDirection = ScrollDirection.idle;
      if (_isMinimized) _setMinimized(false);
      return;
    }

    final direction = controller.position.userScrollDirection;
    if (direction == ScrollDirection.idle || delta.abs() < 0.5) return;

    // 换向则重新累计，避免轻微来回抖动反复切换。
    if (direction != _lastToggleDirection) {
      _lastToggleDirection = direction;
      _scrollDirectionAccum = 0;
    }
    _scrollDirectionAccum += delta.abs();
    if (_scrollDirectionAccum < widget.minimizeDeltaThreshold) return;

    final target = _resolveMinimized(direction: direction, behavior: widget.minimizeBehavior, current: _isMinimized);
    if (target != _isMinimized) {
      _scrollDirectionAccum = 0;
      _setMinimized(target);
    }
  }

  bool _resolveMinimized({
    required ScrollDirection direction,
    required TabBarMinimizeBehavior behavior,
    required bool current,
  }) {
    switch (behavior) {
      case TabBarMinimizeBehavior.never:
        return false;
      case TabBarMinimizeBehavior.onScrollDown:
        return switch (direction) {
          ScrollDirection.reverse => true,
          ScrollDirection.forward => false,
          ScrollDirection.idle => current,
        };
      case TabBarMinimizeBehavior.onScrollUp:
        return switch (direction) {
          ScrollDirection.forward => true,
          ScrollDirection.reverse => false,
          ScrollDirection.idle => current,
        };
    }
  }

  void _setMinimized(bool minimized) {
    if (_isMinimized == minimized) return;
    setState(() => _isMinimized = minimized);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: widget.margin,
      child: SingleMotionBuilder(
        motion: CupertinoMotion.smooth(duration: widget.animationDuration),
        value: _isMinimized ? 1.0 : 0.0,
        builder: (context, minimizeT, _) {
          return _buildBarContent(colorScheme, minimizeT.clamp(0.0, 1.0));
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 整体布局：有配件时用 Stack 插值，配件从上方滑入左右胶囊中间。
  // --------------------------------------------------------------------------
  Widget _buildBarContent(ColorScheme colorScheme, double t) {
    if (widget.topWidget != null) {
      return _buildMorphingAccessoryBar(colorScheme, t);
    }
    return _buildNavOnlyRow(colorScheme, t);
  }

  /// 无 topWidget：导航栏宽度收缩，次要按钮固定在右侧。
  Widget _buildNavOnlyRow(ColorScheme colorScheme, double t) {
    final hasSecondary = widget.secondaryButton != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final secondarySlot = hasSecondary ? widget.height + widget.buttonSpacing : 0.0;
        final expandedNavW = (constraints.maxWidth - secondarySlot).clamp(0.0, constraints.maxWidth);
        final navW = lerpDouble(expandedNavW, _compactWidth, t)!.clamp(0.0, expandedNavW);

        return SizedBox(
          height: widget.height,
          child: Row(
            children: [
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(width: navW, height: widget.height, child: _buildNavigationBar(colorScheme, t)),
                ),
              ),
              if (hasSecondary) ...[SizedBox(width: widget.buttonSpacing), _buildSecondaryButton(colorScheme)],
            ],
          ),
        );
      },
    );
  }

  /// 有 topWidget：单实例配件在 Stack 里从「上方全宽」插值到「左右胶囊中间」。
  Widget _buildMorphingAccessoryBar(ColorScheme colorScheme, double t) {
    final hasSecondary = widget.secondaryButton != null;
    final gap = widget.buttonSpacing;
    final pill = _compactWidth;
    final barH = widget.height;
    // 展开时配件与导航同高，形态统一，插值更稳。
    const gapY = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final secW = hasSecondary ? pill : 0.0;
        final secGap = hasSecondary ? gap : 0.0;

        // 总高度：双行 → 单行
        final totalH = lerpDouble(barH + gapY + barH, barH, t)!;

        // 导航胶囊：底部全宽 → 左下角小胶囊，并上移到与配件同一行
        final navW = lerpDouble(w - secW - secGap, pill, t)!.clamp(pill, w);
        final navTop = lerpDouble(barH + gapY, 0.0, t)!;

        // 次要按钮：右下 → 右上（与导航同步上移）
        final secLeft = w - secW;
        final secTop = navTop;

        // 配件：上方全宽 → 左右胶囊夹着的中间槽
        final accLeft = lerpDouble(0.0, pill + gap, t)!;
        final accWidth = lerpDouble(w, w - pill - gap - secGap - secW, t)!.clamp(0.0, w);
        final accTop = 0.0;
        final accH = barH;
        final accRadius = lerpDouble(100.0, _outerRadius, t)!;

        return SizedBox(
          height: totalH,
          width: w,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 配件（单实例，位置连续插值）
              Positioned(
                left: accLeft,
                top: accTop,
                width: accWidth,
                height: accH,
                child: _buildAccessoryGlass(colorScheme, radius: accRadius),
              ),
              // 导航胶囊
              Positioned(left: 0, top: navTop, width: navW, height: barH, child: _buildNavigationBar(colorScheme, t)),
              // 次要按钮
              if (hasSecondary)
                Positioned(
                  left: secLeft,
                  top: secTop,
                  width: secW,
                  height: barH,
                  child: _buildSecondaryButton(colorScheme),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccessoryGlass(ColorScheme colorScheme, {double radius = 100}) {
    return KeyedSubtree(
      key: _accessoryKey,
      child: _buildGlassContainer(
        showShadow: true,
        colorScheme: colorScheme,
        radius: radius,
        height: widget.height,
        child: widget.topWidget!,
        color: colorScheme.surfaceContainerHigh,
        // 配件胶囊每秒计时刷新 + 滚动时背景逐帧变化，第二层 BackdropFilter 会
        // 让滚动区域反复走离屏模糊（实测掉到 ~20fps）。小面积用高不透明度纯色代替。
        blur: false,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 通用毛玻璃容器构建器
  // --------------------------------------------------------------------------
  Widget _buildGlassContainer({
    required ColorScheme colorScheme,
    required double radius,
    required Widget child,
    required Color color,
    double? width,
    double? height,
    bool showShadow = true,
    bool blur = false,
  }) {
    final shape = SmoothRectangleBorder(
      // side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: widget.borderWidth),
      borderRadius: SmoothBorderRadius(cornerRadius: radius, cornerSmoothing: 1),
    );

    final fill = Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(color: color, shape: shape),
      child: child,
    );

    return Container(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: showShadow
            ? [BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: blur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
                child: fill,
              )
            : fill,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 侧边次要按钮
  // --------------------------------------------------------------------------
  Widget _buildSecondaryButton(ColorScheme colorScheme) {
    final double iconSize = (_innerHeight * 0.55).clamp(16.0, 32.0);

    return _buildGlassContainer(
      colorScheme: colorScheme,
      radius: _outerRadius,
      width: widget.height,
      height: widget.height,
      color: colorScheme.tertiaryContainer,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.secondaryButton!.onPressed,
          borderRadius: BorderRadius.circular(_outerRadius),
          child: Center(
            child: _duotoneIcon(widget.secondaryButton!.icon, size: iconSize, color: colorScheme.tertiary),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 导航栏主体：展开层 ↔ 收起选中胶囊 交叉淡入
  // --------------------------------------------------------------------------
  Widget _buildNavigationBar(ColorScheme colorScheme, double minimizeT) {
    final expandedOpacity = (1.0 - minimizeT / 0.5).clamp(0.0, 1.0);
    final compactOpacity = ((minimizeT - 0.5) / 0.5).clamp(0.0, 1.0);

    return _buildGlassContainer(
      colorScheme: colorScheme,
      radius: _outerRadius,
      height: widget.height,
      color: colorScheme.surfaceContainerHigh,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: minimizeT > 0.5,
            child: Opacity(opacity: expandedOpacity, child: _buildExpandedNavContent(colorScheme)),
          ),
          IgnorePointer(
            ignoring: minimizeT <= 0.5,
            child: Opacity(opacity: compactOpacity, child: _buildCompactNavContent(colorScheme)),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedNavContent(ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - (widget.innerPadding * 2) - (widget.borderWidth * 2);
        if (availableWidth <= 0) return const SizedBox.shrink();
        final itemWidth = availableWidth / widget.items.length;

        return Stack(
          clipBehavior: Clip.none,
          children: [_buildSlidingIndicator(colorScheme, itemWidth), _buildNavigationItems(colorScheme, itemWidth)],
        );
      },
    );
  }

  /// 收起态：仅显示当前选中 Tab 图标；点击展开。
  Widget _buildCompactNavContent(ColorScheme colorScheme) {
    final item = widget.items[_selectedIndex];
    final double iconSize = (_innerHeight * 0.5).clamp(20.0, 30.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setMinimized(false),
      child: Center(
        child: _duotoneIcon(item.icon, size: iconSize, color: colorScheme.primary, semanticLabel: item.label),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 物理滑块
  // --------------------------------------------------------------------------
  Widget _buildSlidingIndicator(ColorScheme colorScheme, double itemWidth) {
    final double maxDragX = (widget.items.length - 1) * itemWidth;

    double targetX = _selectedIndex * itemWidth;
    if (_isDragging) {
      targetX = (targetX + _dragOffset.dx).clamp(0.0, maxDragX);
    }

    final double verticalInset = widget.innerPadding + widget.borderWidth;

    return MotionBuilder<Offset>(
      motion: CupertinoMotion.smooth(duration: widget.animationDuration),
      value: Offset(targetX, 0),
      from: Offset.zero,
      converter: const OffsetMotionConverter(),
      builder: (context, Offset animatedOffset, child) {
        return Positioned(
          left: widget.innerPadding + widget.borderWidth + animatedOffset.dx,
          top: verticalInset,
          bottom: verticalInset,
          width: itemWidth,
          child: Container(
            decoration: ShapeDecoration(
              color: colorScheme.primary,
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(cornerRadius: _innerRadius, cornerSmoothing: 1),
              ),
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // 手势与 Items 布局
  // --------------------------------------------------------------------------
  Widget _buildNavigationItems(ColorScheme colorScheme, double itemWidth) {
    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _isDragging = true),
      onHorizontalDragUpdate: (details) {
        setState(() => _dragOffset = Offset(_dragOffset.dx + details.delta.dx, 0));
      },
      onHorizontalDragEnd: (_) {
        final currentPosition = _selectedIndex * itemWidth + _dragOffset.dx;
        final int targetIndex = (currentPosition / itemWidth).round().clamp(0, widget.items.length - 1);
        setState(() {
          _isDragging = false;
          _dragOffset = Offset.zero;
        });
        _updateSelection(targetIndex);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.innerPadding + widget.borderWidth),
        child: Row(
          children: List.generate(
            widget.items.length,
            (index) => Expanded(child: _buildNavigationItem(index, colorScheme)),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem(int index, ColorScheme colorScheme) {
    final isSelected = _selectedIndex == index;
    final isPressed = _pressedIndex == index;
    final contentColor = isSelected ? colorScheme.surface : colorScheme.onSurfaceVariant;

    final double iconSize = (_innerHeight * 0.52).clamp(18.0, 28.0);
    final double fontSize = (_innerHeight * 0.18).clamp(10.0, 13.0);
    final double spacing = (_innerHeight * 0.04).clamp(2.0, 5.0);

    return GestureDetector(
      onTap: () => _updateSelection(index),
      onTapDown: (_) => setState(() => _pressedIndex = index),
      onTapCancel: () => setState(() => _pressedIndex = null),
      onTapUp: (_) => setState(() => _pressedIndex = null),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _duotoneIcon(
                widget.items[index].icon,
                size: iconSize,
                color: contentColor,
                semanticLabel: widget.items[index].label,
              ),
              SizedBox(height: spacing),
              Text(
                widget.items[index].label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: contentColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: fontSize,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Duotone 的填充层默认 0.20，在导航尺寸下几乎看不见。提到 0.45 让双层能读出来。
  Widget _duotoneIcon(
    PhosphorDuotoneIconData icon, {
    required double size,
    required Color color,
    String? semanticLabel,
  }) {
    return PhosphorIcon(icon, size: size, color: color, semanticLabel: semanticLabel, duotoneSecondaryOpacity: 0.35);
  }

  void _updateSelection(int newIndex) {
    if (_isMinimized) {
      _setMinimized(false);
      if (newIndex == _selectedIndex) return;
    }
    if (newIndex != _selectedIndex) {
      HapticFeedback.lightImpact();
      setState(() => _selectedIndex = newIndex);
      widget.onTabChanged(newIndex);
    } else {
      widget.onTabChanged(newIndex);
    }
  }
}
