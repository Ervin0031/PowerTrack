import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:app_flutter/features/dynamic/application/providers/feed_provider.dart';
import 'package:app_flutter/features/dynamic/domain/entities/feed_comment.dart';
import 'package:app_flutter/features/dynamic/domain/entities/feed_post.dart';
import 'package:app_flutter/features/dynamic/domain/workout_feed.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/feed_post_card.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_anatomy.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 动态详情：卡片 + 评论列表 + 底部输入。
///
/// 后端没有「单条动态」接口，动态从 [feedProvider] 的当前列表里取；
/// 列表未加载（冷启动深链）时提示返回动态页。
class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(feedCommentsProvider(widget.postId).notifier).add(body);
      ref.read(feedProvider.notifier).bumpCommentCount(widget.postId, 1);
      _input.clear();
    } catch (error) {
      if (mounted) {
        showExpressiveSnack(
          context: context,
          message: userFacingErrorMessage(error),
          icon: Symbols.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).value;
    final post = ref.watch(
      feedProvider.select((async) {
        final items = async.value?.items ?? const <FeedPost>[];
        for (final item in items) {
          if (item.id == widget.postId) return item;
        }
        return null;
      }),
    );
    final female = isFemaleAnatomy(ref.watch(fitnessProfileProvider).value?.gender);
    final bodyWeightKg = ref.watch(fitnessProfileProvider).value?.weightKg;

    return Scaffold(
      appBar: const GlassAppBar(title: Text('动态')),
      body: post == null
          ? const Center(
              child: AppEmptyState(icon: Symbols.dynamic_feed_rounded, title: '动态已不在列表中', message: '返回动态页刷新后再试'),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 16),
                    children: [
                      FeedPostCard(
                        post: post,
                        female: female,
                        bodyWeightKg: bodyWeightKg,
                        // 训练详情接口只允许本人查看，别人的动态不给入口。
                        onOpenWorkout:
                            me == null || post.userId != me.id || post.sessionId == null || post.sessionId == 0
                            ? null
                            : () => context.push(AppRoutes.workoutDetailOf(post.sessionId!)),
                      ),
                      const SizedBox(height: 20),
                      const AppSectionHeader(title: '评论'),
                      const SizedBox(height: 8),
                      _CommentList(postId: widget.postId, myUserId: me?.id),
                    ],
                  ),
                ),
                _CommentInput(controller: _input, sending: _sending, onSend: _send),
              ],
            ),
    );
  }
}

class _CommentList extends ConsumerWidget {
  const _CommentList({required this.postId, this.myUserId});

  final int postId;
  final int? myUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feedCommentsProvider(postId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: M3ELoadingIndicator()),
      ),
      error: (error, _) => AppErrorState(error: error, onRetry: () => ref.invalidate(feedCommentsProvider(postId))),
      data: (comments) {
        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '还没有评论，来说一句',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final comment in comments)
              _CommentTile(
                comment: comment,
                isMine: comment.userId == myUserId,
                onDelete: () async {
                  try {
                    await ref.read(feedCommentsProvider(postId).notifier).remove(comment.id);
                    ref.read(feedProvider.notifier).bumpCommentCount(postId, -1);
                  } catch (_) {
                    if (context.mounted) showExpressiveSnack(context: context, message: '删除失败，请重试');
                  }
                },
              ),
          ],
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.isMine, required this.onDelete});

  final FeedComment comment;
  final bool isMine;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final setLabel = comment.set?.label ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.secondaryContainer,
            child: Text(
              comment.authorUsername.isEmpty ? '?' : comment.authorUsername.substring(0, 1),
              style: tt.labelMedium?.copyWith(color: cs.onSecondaryContainer),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.authorUsername, style: tt.labelLarge),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formatFeedTimestamp(comment.createdAt),
                        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    if (isMine)
                      InkWell(
                        onTap: onDelete,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Symbols.delete_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.body, style: tt.bodyMedium),
                if (setLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(setLabel, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLength: 500,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: '写评论…',
                  counterText: '',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: sending ? null : onSend, icon: const Icon(Symbols.send_rounded)),
          ],
        ),
      ),
    );
  }
}
