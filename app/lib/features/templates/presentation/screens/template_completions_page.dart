import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/dynamic/domain/workout_feed.dart';
import 'package:app_flutter/features/templates/application/providers/templates_provider.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

class TemplateCompletionsPage extends ConsumerStatefulWidget {
  const TemplateCompletionsPage({super.key, required this.templateId});

  final int templateId;

  @override
  ConsumerState<TemplateCompletionsPage> createState() =>
      _TemplateCompletionsPageState();
}

class _TemplateCompletionsPageState
    extends ConsumerState<TemplateCompletionsPage> {
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
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(templateCompletionsProvider(widget.templateId).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(templateCompletionsProvider(widget.templateId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('完成列表')),
      body: async.when(
        loading: () => const Center(child: M3ELoadingIndicator()),
        error: (error, _) => AppErrorState(
          error: error,
          onRetry: () =>
              ref.invalidate(templateCompletionsProvider(widget.templateId)),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                24,
                context.appBarInset + 40,
                24,
                24,
              ),
              children: [
                Center(
                  child: AppEmptyState(
                    icon: Symbols.flag_rounded,
                    title: '还没有人用这个模板完成训练',
                  ),
                ),
              ],
            );
          }
          final extra = state.hasMore || state.isLoadingMore ? 1 : 0;
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          return ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(0, 8, 0, context.safeBottom + 24),
            itemCount: state.items.length + extra,
            separatorBuilder: (context, index) {
              if (index >= state.items.length - 1) {
                return const SizedBox.shrink();
              }
              return Divider(
                height: 1,
                thickness: 0.5,
                indent: 76,
                endIndent: 20,
                color: cs.outlineVariant,
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
              final initial = item.username.isEmpty
                  ? '?'
                  : item.username.substring(0, 1);
              return InkWell(
                onTap: item.isSelf
                    ? () => context.push(
                        AppRoutes.workoutDetailOf(item.sessionId),
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                  child: Row(
                    children: [
                      CircleAvatar(child: Text(initial)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.username, style: tt.titleMedium),
                            Text(
                              [
                                formatFeedTimestamp(item.startedAt),
                                if (item.duration != null)
                                  formatSessionDuration(item.duration!),
                                '${item.setCount} 组',
                              ].join(' · '),
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.isSelf)
                        Icon(
                          Symbols.chevron_right_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
