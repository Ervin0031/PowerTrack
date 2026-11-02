import 'package:app_flutter/core/network/network.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:app_flutter/features/auth/application/providers/auth_providers.dart';
import 'package:app_flutter/features/auth/data/models/device_model.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 我的设备页。
///
/// 职责：列出当前用户所有登录会话（[devicesProvider]），并提供
/// 「登出所有设备」操作（[AuthController.logoutAll]，撤销全部会话后回登录页）。
///
/// 注意：本页目前仅路由可达，暂不接入导航入口（按需求后续在设置/个人中心挂载）。
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  bool _loggingOutAll = false;

  Future<void> _logoutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('登出所有设备'),
        content: const Text('将撤销本账号在所有设备上的登录状态，确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('确定')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loggingOutAll = true);
    try {
      await ref.read(authControllerProvider.notifier).logoutAll();
      // 登出后路由守卫会把 /devices 重定向回登录页。
    } catch (error) {
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: userFacingErrorMessage(error),
        icon: Symbols.error_outline_rounded,
        duration: const Duration(seconds: 8),
      );
      setState(() => _loggingOutAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('我的设备'),
        actions: [
          _loggingOutAll
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(width: 20, height: 20, child: M3ELoadingIndicator()),
                )
              : M3ETextButton(onPressed: _logoutAll, child: const Text('登出全部')),
        ],
      ),
      body: SafeArea(
        // 顶部让给毛玻璃栏：内容从 appBarInset 之下开始，底部保留手势条留白。
        top: false,
        child: devices.when(
          loading: () => const Center(child: M3ELoadingIndicator()),
          error: (error, _) => AppErrorState(error: error, onRetry: () => ref.invalidate(devicesProvider)),
          data: (list) {
            if (list.isEmpty) {
              return const Center(child: AppEmptyState(icon: Symbols.devices_rounded, title: '暂无登录设备'));
            }
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(16, context.appBarInset + 16, 16, 16),
              itemCount: list.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _DeviceTile(device: list[index]),
            );
          },
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final DeviceSession device;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (device.deviceType != null && device.deviceType!.isNotEmpty) device.deviceType,
      if (device.ipAddress != null && device.ipAddress!.isNotEmpty) device.ipAddress,
    ].where((e) => e != null && e.isNotEmpty).join(' · ');

    return M3ESegmentedColumn(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                device.deviceName?.isNotEmpty == true ? device.deviceName! : '未知设备',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (device.isRevoked)
              const Chip(label: Text('已撤销'), avatar: Icon(Symbols.block_rounded, size: 16))
            else
              const Chip(label: Text('活跃'), avatar: Icon(Symbols.check_circle_rounded, size: 16)),
          ],
        ),
        if (subtitle.isNotEmpty) Text(subtitle),
        Text('登录于 ${_format(device.createdAt)}'),
        if (device.lastUsedAt != null) Text('最近使用 ${_format(device.lastUsedAt!)}'),
      ],
    );
  }

  String _format(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
