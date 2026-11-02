import 'package:app_flutter/features/training/application/providers/rest_audio_cue_provider.dart';
import 'package:app_flutter/features/training/application/rest_alert_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 休息结束提示开关：本地通知 + 前台音效/震动。
class AudioCueSettingsSheet extends ConsumerWidget {
  const AudioCueSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final enabled = ref.watch(restAudioCueEnabledProvider);

    return M3EBottomSheet(
      title: const Text('休息结束提示'),
      actions: [
        M3EButton(
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
                title: const Text('已启用'),
                trailing: Switch(
                  value: enabled,
                  onChanged: (v) async {
                    if (v) {
                      final ok = await RestAlertService.instance.requestPermissions();
                      if (!context.mounted) return;
                      if (!ok) {
                        // 仍写入偏好；用户可稍后在系统设置里打开通知。
                      }
                    } else {
                      await RestAlertService.instance.cancel();
                    }
                    await ref.read(restAudioCueEnabledProvider.notifier).setEnabled(v);
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '开启后，休息倒计时结束会通过系统通知提醒（锁屏/后台也可收到）；'
              'App 在前台时改为音效与震动。',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: M3EButton(
              style: M3EButtonStyle.tonal,
              onPressed: () async {
                await RestAlertService.instance.requestPermissions();
                await RestAlertService.instance.notifyForegroundRestEnded();
              },
              child: const Text('试听提示'),
            ),
          ),
        ],
      ),
    );
  }
}
