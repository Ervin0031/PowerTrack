import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/settings/application/providers/app_cache_provider.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// App 存储与缓存页。
///
/// 展示本地数据库、图片缓存等占用，并提供手动清除入口。
/// 退出登录时也会走同一套清除逻辑。
class CacheSettingsPage extends ConsumerStatefulWidget {
  const CacheSettingsPage({super.key});

  @override
  ConsumerState<CacheSettingsPage> createState() => _CacheSettingsPageState();
}

class _CacheSettingsPageState extends ConsumerState<CacheSettingsPage> {
  bool _clearing = false;

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('将删除已下载的动作数据和图片缓存。下次打开动作列表会重新按页加载。训练记录不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await ref.read(appCacheControllerProvider).clear();
      if (!mounted) return;
      showExpressiveSnack(context: context, message: '缓存已清除');
    } catch (error) {
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: userFacingErrorMessage(error),
        icon: Symbols.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(appStorageInfoProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('存储与缓存')),
      body: ListView(
        padding: const EdgeInsets.all(
          16,
        ).add(EdgeInsets.only(top: context.appBarInset)),
        children: [
          info.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(80),
              child: Center(child: M3ELoadingIndicator()),
            ),
            error: (error, _) => AppErrorState(error: error, onRetry: () => ref.invalidate(appStorageInfoProvider)),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App 占用',
                          style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(formatBytes(data.totalBytes), style: textTheme.headlineMedium),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('占用明细', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                M3ESegmentedColumn(
                  children: [
                    ListTile(
                      leading: const Icon(Symbols.database_rounded),
                      title: const Text('本地数据库'),
                      subtitle: Text(
                        '已缓存 ${data.exerciseCount} 个动作、${data.exerciseDetailCount} 条详情',
                      ),
                      trailing: Text(
                        formatBytes(data.databaseBytes),
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Symbols.image_rounded),
                      title: const Text('图片缓存'),
                      subtitle: const Text('动作封面等网络图片'),
                      trailing: Text(
                        formatBytes(data.imageCacheBytes),
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Symbols.folder_rounded),
                      title: const Text('其它缓存'),
                      subtitle: const Text('临时文件与系统缓存目录'),
                      trailing: Text(
                        formatBytes(data.otherCacheBytes),
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: M3EButton(
                    style: M3EButtonStyle.tonal,
                    onPressed: _clearing ? null : _clear,
                    child: _clearing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: M3ELoadingIndicator(),
                          )
                        : const Text('清除缓存'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '退出登录也会自动清除上述缓存。主题、账号偏好和训练记录不会被删除。',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
