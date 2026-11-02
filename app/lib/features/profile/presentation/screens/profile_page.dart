import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/tab_scroll_registry.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:app_flutter/features/auth/data/models/user_model.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// 菜单项：`(图标, 标题, 路由)`；路由为 null 表示该入口尚未接后端。
const _infoCenterMenu = <(PhosphorDuotoneIconData, String, String?)>[
  (PhosphorIconsDuotone.calendar, '日历', AppRoutes.trainingCalendar),
  (PhosphorIconsDuotone.listChecks, '训练模板', AppRoutes.templates),
  (PhosphorIconsDuotone.personSimpleRun, '训练动作', AppRoutes.exercises),
];

const _moreMenu = <(PhosphorDuotoneIconData, String, String?)>[
  (PhosphorIconsDuotone.heartbeat, '健身档案', AppRoutes.fitnessProfile),
  (PhosphorIconsDuotone.scales, '体重趋势', AppRoutes.weightHistory),
  (PhosphorIconsDuotone.userGear, '管理账号', AppRoutes.accountSettings),
  (PhosphorIconsDuotone.gear, '设置', AppRoutes.settings),
];

/// 「你」页（个人中心）。
///
/// 职责：
/// - 通过 `authControllerProvider` 展示当前登录用户信息。
/// - 提供退出登录入口（服务端撤销 + 本地清理后回到登录页）。
///
/// 数据流：`ref.watch(authControllerProvider)` → `AuthController.build`
/// （已登录时自动拉取 `GET /users/me`）→ `AsyncValue` 三种状态渲染。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 注册到 Tab 滚动注册表，供底部导航「再次点击当前 Tab」滚回顶部。
    TabScrollRegistry.register(3, _scrollController);
  }

  @override
  void dispose() {
    TabScrollRegistry.unregister(3, _scrollController);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await ref.read(authControllerProvider.notifier).logout();
    // 清掉本地令牌后主动跳登录；router 的 redirect 守卫也会保持一致。
    if (context.mounted) context.go(AppRoutes.login);
  }

  /// 菜单列：`onTap` 按索引回查同一份列表取路由，增删行不必再同步魔法数字。
  Widget _menuColumn(BuildContext context, List<(PhosphorDuotoneIconData, String, String?)> items) {
    return M3ESegmentedColumn(
      onTap: (index) {
        final route = items[index].$3;
        if (route != null) context.push(route);
      },
      children: [
        for (final (icon, label, _) in items)
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 8),
            leading: CircleAvatar(child: PhosphorIcon(icon, duotoneSecondaryOpacity: 0.45)),
            title: Text(label),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch 驱动状态刷新：登录后自动进入有值状态，登出后回到 null。
    final userAsync = ref.watch(authControllerProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('你'),
        actions: [
          IconButton(tooltip: '退出登录', onPressed: () => _logout(context), icon: const Icon(Symbols.logout_rounded)),
          IconButton(
            tooltip: '设置',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Symbols.settings_rounded),
          ),
        ],
      ),
      body: PrimaryScrollController(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.all(16).add(EdgeInsetsGeometry.only(top: context.appBarInset)),
          children: [
            Center(child: _buildBody(context, userAsync)),
            SizedBox(height: 32),
            Column(
              spacing: 12,
              crossAxisAlignment: .start,
              children: [
                const AppSectionHeader(title: '信息中心'),
                _menuColumn(context, _infoCenterMenu),
              ],
            ),
            SizedBox(height: 32),
            Column(
              spacing: 12,
              crossAxisAlignment: .start,
              children: [
                const AppSectionHeader(title: '更多设置'),
                _menuColumn(context, _moreMenu),
              ],
            ),

            Padding(padding: EdgeInsets.only(bottom: context.safeBottom)),
          ],
        ),
      ),
    );
  }

  /// 按 AsyncValue 三种状态渲染用户信息区域。
  Widget _buildBody(BuildContext context, AsyncValue<UserProfile?> userAsync) {
    return userAsync.when(
      loading: () => const M3ELoadingIndicator(),
      // 重新触发 build()：重新拉取用户资料。
      error: (error, _) => AppErrorState(error: error, onRetry: () => ref.invalidate(authControllerProvider)),
      data: (user) => user == null
          ? const Text('未登录')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppShapeIcon(icon: Symbols.person_rounded, shape: Shapes.puffy, size: 78, height: 72, iconSize: 36),
                const SizedBox(height: 12),
                Text(user.username, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
    );
  }
}
