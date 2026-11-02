import 'package:app_flutter/features/training/application/providers/fatigue_auto_reduce_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 训练设置：力竭自动降重等会话偏好。
class TrainingSettingsSheet extends ConsumerWidget {
  const TrainingSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final autoReduce = ref.watch(fatigueAutoReduceEnabledProvider);

    return M3EBottomSheet(
      title: const Text('训练设置'),
      padding: EdgeInsets.zero,
      actions: [
        M3EButton(
          style: M3EButtonStyle.text,
          shape: M3EButtonShape.round,
          size: M3EButtonSize.sm,
          onPressed: () => Navigator.pop(context),
          child: const Icon(Symbols.close_rounded, size: 20),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          M3ESegmentedColumn(
            margin: EdgeInsets.zero,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('力竭自动降重'),
                trailing: Switch(
                  value: autoReduce,
                  onChanged: (v) => ref
                      .read(fatigueAutoReduceEnabledProvider.notifier)
                      .setEnabled(v),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              '记到 RPE 10 时，按次数把后面不比这组轻的正式组调低。更轻的组不动；这个动作再力竭一次就不再降。',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
