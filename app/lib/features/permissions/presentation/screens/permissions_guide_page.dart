import 'dart:io';

import 'package:app_flutter/core/native/apple_health_service.dart';
import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/training/application/rest_alert_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 新用户首次登录后的系统权限引导。
///
/// 先说明用途，再由用户主动点「开启」触发系统弹窗（符合平台规范）。
/// 可跳过；跳过或继续后都会标记已看过，不再拦截。
class PermissionsGuidePage extends ConsumerStatefulWidget {
  const PermissionsGuidePage({super.key});

  @override
  ConsumerState<PermissionsGuidePage> createState() => _PermissionsGuidePageState();
}

class _PermissionsGuidePageState extends ConsumerState<PermissionsGuidePage> {
  bool _loading = true;
  bool _notifGranted = false;
  bool _healthAvailable = false;
  bool _healthRequested = false;
  bool _busyNotif = false;
  bool _busyHealth = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final notif = await RestAlertService.instance.areNotificationsEnabled();
    final healthOk = Platform.isIOS && await AppleHealthService.instance.isAvailable();
    if (!mounted) return;
    setState(() {
      _notifGranted = notif;
      _healthAvailable = healthOk;
      _loading = false;
    });
  }

  Future<void> _enableNotifications() async {
    setState(() => _busyNotif = true);
    final ok = await RestAlertService.instance.requestPermissions();
    if (!mounted) return;
    setState(() {
      _notifGranted = ok;
      _busyNotif = false;
    });
  }

  Future<void> _enableHealth() async {
    setState(() => _busyHealth = true);
    final ok = await AppleHealthService.instance.requestAuthorization();
    if (!mounted) return;
    setState(() {
      _healthRequested = true;
      _busyHealth = false;
      // HealthKit 即便用户部分拒绝也可能返回 success；以「已请求」为准展示。
      if (ok) _healthRequested = true;
    });
  }

  Future<void> _finish() async {
    await ref.read(appLaunchStorageProvider).markPermissionsGuideSeen();
    if (!mounted) return;
    final profileComplete = ref.read(fitnessProfileStorageProvider).isComplete;
    context.go(profileComplete ? AppRoutes.home : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('开启权限', style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('这些权限用于训练提醒与健康数据同步。你可以稍后在系统设置里修改。', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 28),
              if (_loading)
                const Expanded(child: Center(child: M3ELoadingIndicator()))
              else
                Expanded(
                  child: ListView(
                    children: [
                      _PermissionCard(
                        icon: Symbols.notifications_active_rounded,
                        title: '通知',
                        subtitle: '休息倒计时结束时提醒你开始下一组（锁屏/后台也可收到）。',
                        granted: _notifGranted,
                        busy: _busyNotif,
                        actionLabel: _notifGranted ? '已开启' : '开启通知',
                        onAction: _notifGranted ? null : _enableNotifications,
                      ),
                      if (_healthAvailable) ...[
                        const SizedBox(height: 12),
                        _PermissionCard(
                          icon: Symbols.favorite_rounded,
                          title: '苹果健康',
                          subtitle: '读取步数、活动能量等摘要，并把完成的力量训练写入健康 App。',
                          granted: _healthRequested,
                          busy: _busyHealth,
                          actionLabel: _healthRequested ? '已请求' : '连接健康',
                          onAction: _healthRequested ? null : _enableHealth,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _PermissionCard(
                        icon: Symbols.photo_camera_rounded,
                        title: '相机与相册',
                        subtitle: '上传训练模板封面时再请求，无需现在开启。',
                        granted: false,
                        busy: false,
                        actionLabel: '稍后使用时开启',
                        onAction: null,
                        muted: true,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              M3EButton(size: .md, style: M3EButtonStyle.filled, onPressed: _finish, child: const Text('继续')),
              const SizedBox(height: 8),
              M3EButton(size: .md, style: M3EButtonStyle.text, onPressed: _finish, child: const Text('稍后再说')),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.busy,
    required this.actionLabel,
    required this.onAction,
    this.muted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final bool busy;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = granted ? cs.primary : cs.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (granted ? cs.primaryContainer : cs.surfaceContainerHighest),
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                  child: Icon(icon, color: granted ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (granted) Icon(Symbols.check_circle_rounded, color: accent, size: 22),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: busy
                  ? const SizedBox(width: 28, height: 28, child: M3ELoadingIndicator())
                  : M3EButton(
                      style: muted || granted ? M3EButtonStyle.tonal : M3EButtonStyle.filled,
                      size: M3EButtonSize.sm,
                      shape: M3EButtonShape.round,
                      onPressed: onAction,
                      child: Text(actionLabel),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
