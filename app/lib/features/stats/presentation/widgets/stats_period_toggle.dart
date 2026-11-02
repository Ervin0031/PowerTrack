import 'package:app_flutter/features/stats/application/providers/stats_overview_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// 数据页周期选项：近 7 天 / 本月 / 近 90 天。
const statsPeriodOptions = [(7, '近 7 天'), (30, '本月'), (90, '近 90 天')];

/// AppBar 底部周期切换。
class StatsPeriodToggle extends ConsumerWidget {
  const StatsPeriodToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(statsPeriodDaysProvider);
    final periodIndex = statsPeriodOptions.indexWhere((e) => e.$1 == days).clamp(0, 2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth - 8) / 3;
          return M3EToggleButtonGroup(
            selectedIndex: periodIndex,
            onSelectedIndexChanged: (index) {
              if (index == null) return;
              ref.read(statsPeriodDaysProvider.notifier).state = statsPeriodOptions[index].$1;
            },
            type: M3EButtonGroupType.connected,
            style: M3EButtonStyle.tonal,
            shape: M3EButtonShape.round,
            size: M3EButtonSize.sm,
            neighborSquish: false,
            actions: [
              for (final (_, label) in statsPeriodOptions)
                M3EToggleButtonGroupAction(label: Text(label), width: w),
            ],
          );
        },
      ),
    );
  }
}
