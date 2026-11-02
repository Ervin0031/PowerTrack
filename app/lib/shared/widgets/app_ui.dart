// 全应用共享的 UI 原语。
//
// 取代各页面手写的空态 / 错态 / 分区标题 / 搜索框 / 形状图标样板。
// 硬约束（勿破坏）：
// - 原语内不得出现滚动容器（Tab 页由页面自己的 ListView 承载，保单一滚动宿主）；
// - 不得依赖 Riverpod（保页面 select 收窄）；
// - 全部 const 构造，样式一律取自 Theme.of(context)。
import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/ui/app_radius.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 色调档位：容器底色与前景色的 M3 成对取色。
enum AppTint {
  primary,
  secondary,
  tertiary;

  /// 返回 (容器底色, 前景色)。
  (Color, Color) of(ColorScheme cs) => switch (this) {
    AppTint.primary => (cs.primaryContainer, cs.onPrimaryContainer),
    AppTint.secondary => (cs.secondaryContainer, cs.onSecondaryContainer),
    AppTint.tertiary => (cs.tertiaryContainer, cs.onTertiaryContainer),
  };
}

/// M3E 形状裁切容器内的单枚图标。
class AppShapeIcon extends StatelessWidget {
  const AppShapeIcon({
    super.key,
    required this.icon,
    this.shape = Shapes.bun,
    this.size = 40,
    this.height,
    this.iconSize,
    this.tint = AppTint.primary,
    this.filled = true,
  });

  final IconData icon;
  final Shapes shape;
  final double size;

  /// 高于 [size] 时画非正方形容器（如空态的 78×72）。
  final double? height;
  final double? iconSize;
  final AppTint tint;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = tint.of(Theme.of(context).colorScheme);
    return M3EContainer(
      shape,
      width: size,
      height: height ?? size,
      color: background,
      // 0.45 与既有空态「78 容器 / 36 图标」的比例一致。
      child: Icon(icon, size: iconSize ?? size * 0.45, color: foreground, fill: filled ? 1 : 0),
    );
  }
}

/// 分区标题：可选前缀图标 + 标题 + 可选右侧计数/说明。
///
/// 自带 12 的水平内边距与 8 的底部间距，调用方不必再垫 SizedBox。
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({super.key, required this.title, this.trailing, this.leading});

  final String title;
  final String? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Text(title, style: tt.titleMedium),
          if (trailing != null) ...[
            const Spacer(),
            Text(trailing!, style: tt.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// 空状态：形状图标 + 标题 + 可选说明。
///
/// 纯 Column，绝不含滚动容器；放进页面自己的 ListView 即可。
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({super.key, required this.icon, required this.title, this.message, this.tint = AppTint.primary});

  final IconData icon;
  final String title;
  final String? message;
  final AppTint tint;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppShapeIcon(icon: icon, shape: Shapes.puffy, size: 78, height: 72, iconSize: 36, tint: tint),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: tt.titleMedium),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// 错误状态：友好文案 + 重试按钮。纯 Column，同 [AppEmptyState] 不自带滚动容器。
class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, required this.error, required this.onRetry, this.retryLabel = '重试'});

  final Object? error;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(userFacingErrorMessage(error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            M3EButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

/// 统一搜索框：无色块高度、细描边、field 圆角。
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
    this.leading,
    this.padding,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  final Widget? leading;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // 如果外部可能传入 null，确保有一个可用的 controller 实例
    final effectiveController = controller;
    return SearchBar(
      elevation: const WidgetStatePropertyAll(0),
      padding: WidgetStatePropertyAll(padding ?? EdgeInsets.symmetric(horizontal: 12)),
      controller: controller,
      hintText: hintText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      leading: leading ?? const Icon(Symbols.search_rounded),
      trailing: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: effectiveController,
          builder: (context, value, _) {
            if (value.text.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton.filled(
              icon: const Icon(Symbols.close_rounded), // 或 Icons.clear
              onPressed: () {
                effectiveController.clear();
                onChanged.call(''); // 保持 onChanged 回调同步
              },
            );
          },
        ),
      ],
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primaryContainer),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          // side: BorderSide(width: .5, color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
    );
  }
}
