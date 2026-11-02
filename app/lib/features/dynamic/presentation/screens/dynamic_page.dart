import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/glass_pull_to_refresh.dart';
import 'package:app_flutter/core/ui/tab_scroll_registry.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/dynamic/application/providers/feed_provider.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/feed_post_card.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_anatomy.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 动态页：关注流（自己 + 已关注用户的分享），上下滚动分页。
class DynamicPage extends ConsumerStatefulWidget {
  const DynamicPage({super.key});

  @override
  ConsumerState<DynamicPage> createState() => _DynamicPageState();
}

class _DynamicPageState extends ConsumerState<DynamicPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    TabScrollRegistry.register(1, _scrollController);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    TabScrollRegistry.unregister(1, _scrollController);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 240) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    final female = isFemaleAnatomy(ref.watch(fitnessProfileProvider).value?.gender);
    final bodyWeightKg = ref.watch(fitnessProfileProvider).value?.weightKg;
    final bottomPad = context.safeBottom + 96;
    final topInset = context.appBarInset;

    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('动态'),
        actions: [
          IconButton(
            tooltip: '找人',
            onPressed: () => context.push(AppRoutes.userSearch),
            icon: const Icon(Symbols.person_search_rounded),
          ),
        ],
      ),
      body: GlassPullToRefresh(
        edgeOffset: topInset,
        onRefresh: () => ref.read(feedProvider.notifier).refresh(),
        child: feed.when(
          loading: () => ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: topInset),
            children: const [SizedBox(height: 280, child: Center(child: M3ELoadingIndicator()))],
          ),
          error: (error, _) => ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
            children: [AppErrorState(error: error, onRetry: () => ref.read(feedProvider.notifier).refresh())],
          ),
          data: (state) {
            if (state.items.isEmpty) {
              return ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
                children: [
                  const AppEmptyState(
                    icon: Symbols.dynamic_feed_rounded,
                    title: '还没有动态',
                    message: '结束训练后在训练详情里分享，或关注其他训练者',
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.userSearch),
                      icon: const Icon(Symbols.person_search_rounded),
                      label: const Text('找人关注'),
                    ),
                  ),
                ],
              );
            }

            final extra = state.hasMore || state.isLoadingMore ? 1 : 0;
            return ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad),
              itemCount: state.items.length + extra,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: M3ELoadingIndicator()),
                  );
                }
                final post = state.items[index];
                return FeedPostCard(
                  post: post,
                  female: female,
                  bodyWeightKg: bodyWeightKg,
                  onOpen: () => context.push(AppRoutes.postDetailOf(post.id)),
                  onOpenWorkout: post.sessionId == null || post.sessionId == 0
                      ? null
                      : () => context.push(AppRoutes.workoutDetailOf(post.sessionId!)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
