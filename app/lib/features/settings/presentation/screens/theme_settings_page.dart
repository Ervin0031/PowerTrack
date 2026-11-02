import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/settings/application/providers/theme_settings_provider.dart';
import 'package:app_flutter/features/settings/domain/entities/theme_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 主题设置页。
///
/// 用户可实时调整：
/// - 主种子色（驱动整条 Material 3 色板）
/// - 明暗模式（跟随系统 / 亮 / 暗）
/// - 调色策略（m3e_core 的 M3EColorVariant 色板）
///
/// 所有改动通过 [ThemeSettingsNotifier] 即时持久化，并驱动全局换肤。
class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  /// 可选主色预设（Material 3 baseline 风格）。
  static const _presetColors = <int>[
    0xFF6750A4, // Purple
    0xFF2196F3, // Blue
    0xFF3F51B5, // Indigo
    0xFF009688, // Teal
    0xFF4CAF50, // Green
    0xFF8BC34A, // Light Green
    0xFFFB8C00, // Orange
    0xFFF4511E, // Deep Orange
    0xFFE53935, // Red
    0xFFE91E63, // Pink
    0xFF00BCD4, // Cyan
    0xFFFFB300, // Amber
    0xFF607D8B, // Blue Grey
    0xFF795548, // Brown
  ];

  static const _modeOptions = <(AppThemeMode, IconData, String)>[
    (AppThemeMode.system, Symbols.contrast_rounded, '跟随系统'),
    (AppThemeMode.light, Symbols.light_mode_rounded, '亮色'),
    (AppThemeMode.dark, Symbols.dark_mode_rounded, '暗色'),
  ];

  static const _toneOptions = <(ToneStrategy, String)>[
    (ToneStrategy.tonalSpot, '标准'),
    (ToneStrategy.vibrant, '鲜艳'),
    (ToneStrategy.fidelity, '忠实'),
    (ToneStrategy.expressive, '灵动'),
    (ToneStrategy.monochrome, '单色'),
    (ToneStrategy.neutral, '柔和'),
    (ToneStrategy.rainbow, '彩虹'),
    (ToneStrategy.fruitSalad, '果彩'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsNotifierProvider);
    final notifier = ref.watch(themeSettingsNotifierProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('主题设置')),
      body: ListView(
        padding: const EdgeInsets.all(16).add(EdgeInsets.only(top: context.appBarInset)),
        children: [
          _GroupTitle('应用颜色'),
          _ColorGrid(
            selected: settings.primaryColor,
            onSelect: (color) => notifier.update(settings.copyWith(primaryColor: color)),
          ),
          const SizedBox(height: 24),
          _GroupTitle('明暗模式'),
          M3EToggleButtonGroup(
            selectedIndex: _modeOptions.indexWhere((o) => o.$1 == settings.mode),
            onSelectedIndexChanged: (index) {
              if (index == null) return;
              notifier.update(settings.copyWith(mode: _modeOptions[index].$1));
            },
            actions: [
              for (final (_, icon, label) in _modeOptions)
                M3EToggleButtonGroupAction(icon: Icon(icon), label: Text(label)),
            ],
          ),
          const SizedBox(height: 24),
          _GroupTitle('调色风格'),
          M3EToggleButtonGroup(
            selectedIndex: _toneOptions.indexWhere((o) => o.$1 == settings.tone),
            onSelectedIndexChanged: (index) {
              if (index == null) return;
              notifier.update(settings.copyWith(tone: _toneOptions[index].$1));
            },
            actions: [
              for (final (_, label) in _toneOptions) M3EToggleButtonGroupAction(label: Text(label)),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 分组标题。
class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// 主色预设网格，选中项显示对勾。
class _ColorGrid extends StatelessWidget {
  const _ColorGrid({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final color in ThemeSettingsPage._presetColors)
        InkWell(
          // 圆形墨水：半径取 pill 与 52px 圆头像一致。
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: () => onSelect(color),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: Color(color),
            child: selected == color ? const Icon(Symbols.check_rounded, color: Colors.white) : null,
          ),
        ),
    ],
  );
}
