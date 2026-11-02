import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/features/training/application/providers/rest_audio_cue_provider.dart';
import 'package:app_flutter/features/training/application/providers/rest_timer_settings_provider.dart';
import 'package:app_flutter/features/training/application/rest_alert_service.dart';
import 'package:app_flutter/features/training/presentation/widgets/audio_cue_placeholder_sheet.dart';
import 'package:app_flutter/features/training/presentation/widgets/rest_duration_picker_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 休息闹钟设置：开关、目标时长、结束提示。
class RestAudioSettingsSheet extends ConsumerWidget {
  const RestAudioSettingsSheet({super.key});

  Future<void> _pickDuration(BuildContext context, WidgetRef ref, int currentSeconds) async {
    final picked = await showM3EModalBottomSheet<int>(
      context: context,
      builder: (_) => RestDurationPickerSheet(initialSeconds: currentSeconds),
    );
    if (picked == null) return;
    await ref.read(restTimerSettingsProvider.notifier).setSeconds(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final current = ref.watch(restTimerSettingsProvider);
    final enabled = current != null;
    final seconds = current ?? RestTimerSettings.defaultSeconds;
    final cueEnabled = ref.watch(restAudioCueEnabledProvider);

    return M3EBottomSheet(
      title: const Text('休息闹钟'),
      padding: EdgeInsets.zero,
      actions: [
        M3EButton(
          size: M3EButtonSize.sm,
          onPressed: () => Navigator.pop(context),
          child: const Icon(Symbols.close_rounded, size: 20),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          M3ESegmentedColumn(
            margin: EdgeInsets.zero,
            onTap: (index) {
              if (index == 1 && enabled) {
                _pickDuration(context, ref, seconds);
              }
            },
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('已启用'),
                trailing: Switch(
                  value: enabled,
                  onChanged: (v) async {
                    final n = ref.read(restTimerSettingsProvider.notifier);
                    if (v) {
                      await n.setSeconds(seconds);
                      if (cueEnabled) {
                        await RestAlertService.instance.requestPermissions();
                      }
                    } else {
                      await RestAlertService.instance.cancel();
                      await n.disable();
                    }
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('休息时间'),
                trailing: IgnorePointer(
                  ignoring: !enabled,
                  child: Opacity(
                    opacity: enabled ? 1 : 0.4,
                    child: M3EButton(
                      style: M3EButtonStyle.tonal,
                      size: M3EButtonSize.sm,
                      shape: M3EButtonShape.round,
                      onPressed: enabled ? () => _pickDuration(context, ref, seconds) : null,
                      child: Text(
                        formatMmSs(seconds),
                        style: tt.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              '完成一组后开始倒计时；时间到后提醒你开始下一组。',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          M3ESegmentedColumn(
            margin: EdgeInsets.zero,
            onTap: (index) {
              if (index == 0) {
                showM3EModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const AudioCueSettingsSheet(),
                );
              }
            },
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('结束提示'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cueEnabled ? '已启用' : '已关闭',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Text(
              '后台用系统通知，前台用音效与震动。',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
