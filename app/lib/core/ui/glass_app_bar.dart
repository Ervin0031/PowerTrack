import 'package:material_ui/material_ui.dart';

/// 实心 AppBar：背景取色、抬升与状态栏样式统一由主题 AppBarTheme 配置
/// （见 `AppTheme`），页面层不再硬编码背景或画分割线。
///
/// 页面需 `extendBodyBehindAppBar: true`。
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading,
    this.centerTitle,
    this.foregroundColor,
    this.actionsPadding,
    this.toolbarHeight,
    this.bottom,
    this.leadingWidth,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool? automaticallyImplyLeading;
  final bool? centerTitle;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? actionsPadding;
  final double? toolbarHeight;
  final PreferredSizeWidget? bottom;
  final double? leadingWidth;

  @override
  Size get preferredSize => Size.fromHeight((toolbarHeight ?? kToolbarHeight) + (bottom?.preferredSize.height ?? 0));

  // Widget? _backLeading(BuildContext context) {
  //   if (leading != null || automaticallyImplyLeading == false) return null;
  //   final route = ModalRoute.of(context);
  //   if (route?.impliesAppBarDismissal != true) return null;
  //   final close = route is PageRoute && route.fullscreenDialog;
  //   final localizations = MaterialLocalizations.of(context);
  //   return AppBarCircleButton(
  //     tooltip: close ? localizations.closeButtonTooltip : localizations.backButtonTooltip,
  //     icon: close ? Icons.close : Symbols.arrow_back_ios_new_rounded,
  //     onPressed: () => Navigator.maybePop(context),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    // final backLeading = _backLeading(context);
    return AppBar(
      leadingWidth: leadingWidth,
      title: title,
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading ?? true,
      centerTitle: centerTitle,
      foregroundColor: foregroundColor,
      actionsPadding: actionsPadding,
      toolbarHeight: toolbarHeight,
      bottom: bottom,
      primary: true,
    );
  }
}

/// AppBar 工具栏上的圆形图标按钮，用于返回和关闭。
class AppBarCircleButton extends StatelessWidget {
  const AppBarCircleButton({super.key, required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,

        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: colorScheme.onSurface,
          minimumSize: const Size(32, 32),
          fixedSize: const Size(32, 32),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, size: 24),
      ),
    );
  }
}
