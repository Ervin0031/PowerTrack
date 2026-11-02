import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/glass_pull_to_refresh.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/templates/application/providers/templates_provider.dart';
import 'package:app_flutter/features/templates/presentation/widgets/template_feed_card.dart';
import 'package:app_flutter/features/templates/presentation/widgets/template_filter_bar.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 训练模板列表：卡片流对齐动态页，支持筛选与新增。
class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({super.key});

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      ref.read(templatesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(templatesProvider);
    final bottomPad = context.safeBottom + 24;
    // 与下方 GlassAppBar 结构保持同步（toolbarHeight / bottom 高度）。
    const appBarToolbarHeight = 100.0;
    const appBarBottomHeight = 156.0;
    // 顶部留白 = 状态栏 + 工具栏 + 筛选栏（appBarInset 只覆盖默认高度的工具栏）。
    final topInset = context.safeTop + appBarToolbarHeight + appBarBottomHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('训练模板'),
        toolbarHeight: appBarToolbarHeight,
        actions: [
          M3EButton.icon(
            tooltip: '新建模板',
            onPressed: () => context.push(AppRoutes.templateCreate),
            icon: const Icon(Symbols.add_rounded),
            label: Text("新增模板"),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(appBarBottomHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              spacing: 12,
              children: [
                AppSearchBar(
                  controller: _searchController,
                  hintText: '搜索模板',
                  onChanged: (value) => ref
                      .read(templatesFilterProvider.notifier)
                      .update((f) => f.copyWith(search: value)),
                ),
                const TemplateFilterBar(),
              ],
            ),
          ),
        ),
      ),
      body: GlassPullToRefresh(
        edgeOffset: topInset,
        onRefresh: () => ref.read(templatesProvider.notifier).refresh(),
        child: feed.when(
          loading: () => ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: topInset),
            children: const [
              SizedBox(
                height: 280,
                child: Center(child: M3ELoadingIndicator()),
              ),
            ],
          ),
          error: (error, _) => ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, topInset + 24, 24, 24),
            children: [
              AppErrorState(
                error: error,
                onRetry: () => ref.read(templatesProvider.notifier).refresh(),
              ),
            ],
          ),
          data: (state) {
            if (state.items.isEmpty) {
              return ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, topInset + 80, 24, bottomPad),
                children: [
                  const Center(
                    child: AppEmptyState(
                      icon: Symbols.playlist_add_check_rounded,
                      title: '还没有训练模板',
                      message: '把常用动作组保存成模板，下次一键开练',
                    ),
                  ),
                ],
              );
            }
            final extra = state.hasMore || state.isLoadingMore ? 1 : 0;
            return ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(0, topInset + 4, 0, bottomPad),
              itemCount: state.items.length + extra,
              separatorBuilder: (context, index) {
                if (index >= state.items.length - 1) {
                  return const SizedBox.shrink();
                }
                return Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 98,
                  endIndent: 20,
                  color: Theme.of(context).colorScheme.outlineVariant,
                );
              },
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: M3ELoadingIndicator()),
                  );
                }
                final item = state.items[index];
                return TemplateFeedCard(
                  item: item,
                  onTap: () =>
                      context.push(AppRoutes.templateDetailOf(item.id)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
