import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/changelog_service.dart';
import 'package:app_flutter/core/ui/tab_scroll_registry.dart';
import 'package:app_flutter/features/dynamic/presentation/screens/dynamic_page.dart';
import 'package:app_flutter/features/profile/presentation/screens/profile_page.dart';
import 'package:app_flutter/features/stats/presentation/screens/stats_page.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/presentation/screens/training_page.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../training/presentation/widgets/training_top_widget.dart';

/// 应用根页面（登录后落地页）。
///
/// 职责：
/// - 顶部用 [IndexedStack] 按底部导航栏选中项切换四个功能模块页面，
///   保留各页面状态（切回不重建）。
/// - 底部使用 [AppBottomNavigationBar] 做 [训练/动态/数据/你] 四个 Tab 的切换。
///
/// 各 Tab 页（[TrainingPage]/[DynamicPage]/[StatsPage]/[ProfilePage]）各自带
/// 自己的 Scaffold + AppBar，根页面只负责内容切换与底部导航。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;

  // 与底部导航栏 items 顺序一致：训练 / 动态 / 数据 / 你。
  final List<Widget> _pages = const [TrainingPage(), DynamicPage(), StatsPage(), ProfilePage()];

  @override
  void initState() {
    super.initState();
    _checkWhatsNew();
    // Tab 页在首帧挂载后才写入 [TabScrollRegistry]，补一次 rebuild 以挂上滚动联动。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// 版本升级后首次打开，展示更新内容。
  Future<void> _checkWhatsNew() async {
    final info = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    final items = await ChangelogService.check(info, prefs);
    if (items == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('更新至 v${info.version}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final item in items) Text('• $item')],
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('知道了'))],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 进行中会话存在时，底部导航顶部展示「训练中」胶囊（点击缩放展开进入会话）。
    // 只判空，用 select 避免会话内字段变化重建整个 HomePage。
    final hasActiveTraining = ref.watch(trainingSessionProvider.select((a) => a.value != null));
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: IndexedStack(index: _selectedIndex, children: _pages),

      bottomNavigationBar: AppBottomNavigationBar(
        initialIndex: _selectedIndex,
        // iOS 26 onScrollDown：当前 Tab 主列表向下滚动时收成选中胶囊。
        scrollController: TabScrollRegistry.of(_selectedIndex),
        minimizeBehavior: TabBarMinimizeBehavior.onScrollDown,
        topWidget: hasActiveTraining ? const TrainingTopWidget() : null,
        secondaryButton: BottomNavActionButton(
          icon: PhosphorIconsDuotone.sparkle,
          onPressed: () => context.push(AppRoutes.coach),
        ),
        items: const [
          BottomNavItem(icon: PhosphorIconsDuotone.barbell, label: '训练'),
          BottomNavItem(icon: PhosphorIconsDuotone.cards, label: '动态'),
          BottomNavItem(icon: PhosphorIconsDuotone.chartBar, label: '数据'),
          BottomNavItem(icon: PhosphorIconsDuotone.userCircle, label: '你'),
        ],
        onTabChanged: (index) {
          // 再次点击当前 Tab：滚回该页顶部（原生交互习惯）。
          if (index == _selectedIndex) {
            TabScrollRegistry.of(
              index,
            )?.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          } else {
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }
}
