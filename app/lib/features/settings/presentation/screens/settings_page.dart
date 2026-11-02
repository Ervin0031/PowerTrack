import 'package:app_flutter/core/native/apple_health_service.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/safe_area_ext.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 设置主页。
///
/// 作为「更多设置」的统一入口，承载主题、健康授权与本地存储管理。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16,
        ).add(EdgeInsets.only(top: context.appBarInset)),
        children: [
          _Section(
            title: '外观',
            onTap: (p0) {
              switch (p0) {
                case 0:
                  context.push(AppRoutes.themeSettings);
                  break;
                default:
              }
            },
            children: [
              ListTile(
                leading: const Icon(Symbols.palette_rounded),
                title: const Text('主题设置'),
                subtitle: const Text('应用颜色、明暗与调色风格'),
                trailing: const Icon(Symbols.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '健康',
            onTap: (p0) async {
              if (p0 != 0) return;
              final ok = await AppleHealthService.instance
                  .requestAuthorization();
              if (!context.mounted) return;
              showExpressiveSnack(
                context: context,
                message: ok ? '已请求苹果健康授权，可在「健康 › 数据访问」中管理' : '授权失败或已取消',
              );
            },
            children: [
              ListTile(
                leading: const Icon(Symbols.ecg_heart_rounded),
                title: const Text('苹果健康'),
                subtitle: const Text('读取步数等数据；训练结束写入力量训练'),
                trailing: const Icon(Symbols.chevron_right_rounded),
              ),
            ],
          ),
          _Section(
            title: 'AI 教练',
            onTap: (p0) {
              if (p0 == 0) context.push(AppRoutes.aiSettings);
            },
            children: [
              ListTile(
                leading: const Icon(Symbols.key_rounded),
                title: const Text('API Key'),
                subtitle: const Text('自带 Key，直连 DeepSeek / OpenAI 兼容服务'),
                trailing: const Icon(Symbols.chevron_right_rounded),
              ),
            ],
          ),
          _Section(
            title: '存储',
            onTap: (p0) {
              if (p0 == 0) context.push(AppRoutes.cacheSettings);
            },
            children: [
              ListTile(
                leading: const Icon(Symbols.database_rounded),
                title: const Text('存储与缓存'),
                subtitle: const Text('查看占用空间，清除本地缓存'),
                trailing: const Icon(Symbols.chevron_right_rounded),
              ),
            ],
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return Padding(
                padding: const EdgeInsets.only(top: 8, left: 12),
                child: Text(
                  info != null
                      ? '版本 ${info.version} (${info.buildNumber})'
                      : '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 设置分组卡片（标题 + 列表项）。
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    required this.onTap,
  });

  final String title;
  final List<Widget> children;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        M3ESegmentedColumn(onTap: onTap, children: [...children]),
        const SizedBox(height: 24),
      ],
    );
  }
}
