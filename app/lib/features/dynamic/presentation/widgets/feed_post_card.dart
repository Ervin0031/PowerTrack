import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:app_flutter/features/dynamic/application/providers/feed_provider.dart';
import 'package:app_flutter/features/dynamic/domain/entities/feed_post.dart';
import 'package:app_flutter/features/dynamic/domain/workout_feed.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_feed_card.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 关注流里的一条动态：训练卡片 + 点赞/评论/更多操作行。
///
/// 快照缺失时降级为纯文字卡片（配文 + 提示），不显示训练指标。
class FeedPostCard extends ConsumerWidget {
  const FeedPostCard({
    super.key,
    required this.post,
    required this.female,
    this.bodyWeightKg,
    this.onOpen,
    this.onOpenWorkout,
  });

  final FeedPost post;
  final bool female;
  final double? bodyWeightKg;

  /// 点卡片进动态详情。
  final VoidCallback? onOpen;

  /// 「查看完整训练」——仅自己的动态且源会话仍在时由调用方提供。
  final VoidCallback? onOpenWorkout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).value;
    final item = feedItemFromPost(post, myUserId: me?.id ?? -1, bodyWeightKg: bodyWeightKg);
    final footer = _ActionRow(
      post: post,
      isMine: me != null && post.userId == me.id,
      onOpen: onOpen,
      onOpenWorkout: onOpenWorkout,
    );

    if (item == null) {
      return _FallbackCard(post: post, footer: footer, onOpen: onOpen);
    }
    return WorkoutFeedCard(
      item: item,
      username: post.authorUsername,
      female: female,
      onTap: onOpen,
      footer: footer,
    );
  }
}

/// 点赞 / 评论 / 更多。
class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.post, required this.isMine, this.onOpen, this.onOpenWorkout});

  final FeedPost post;
  final bool isMine;
  final VoidCallback? onOpen;
  final VoidCallback? onOpenWorkout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        _ActionButton(
          icon: post.likedByMe ? Symbols.favorite_rounded : Symbols.favorite_border_rounded,
          label: '${post.likeCount}',
          color: post.likedByMe ? cs.error : cs.onSurfaceVariant,
          onTap: () async {
            try {
              await ref.read(feedProvider.notifier).toggleLike(post.id);
            } catch (_) {
              if (context.mounted) showExpressiveSnack(context: context, message: '操作失败，请重试');
            }
          },
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Symbols.chat_bubble_outline_rounded,
          label: '${post.commentCount}',
          color: cs.onSurfaceVariant,
          onTap: onOpen,
        ),
        const Spacer(),
        // 训练详情接口只允许本人查看。
        if (isMine && post.sessionId != null && post.sessionId != 0 && onOpenWorkout != null)
          TextButton(onPressed: onOpenWorkout, child: const Text('查看完整训练')),
        PopupMenuButton<String>(
          icon: Icon(Symbols.more_horiz_rounded, color: cs.onSurfaceVariant),
          onSelected: (value) async {
            if (value == 'detail') {
              onOpen?.call();
            } else if (value == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('删除动态'),
                  content: const Text('动态与其下的评论、点赞都会被删除，训练记录不受影响。'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
                    FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除')),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              try {
                await ref.read(feedProvider.notifier).removePost(post.id);
              } catch (_) {
                if (context.mounted) showExpressiveSnack(context: context, message: '删除失败，请重试');
              }
            }
          },
          itemBuilder: (context) => [
            if (onOpen != null)
              const PopupMenuItem(value: 'detail', child: Text('查看动态')),
            if (isMine)
              PopupMenuItem(
                value: 'delete',
                child: Text('删除动态', style: tt.bodyMedium?.copyWith(color: cs.error)),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.color, this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 10)),
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}

/// 无快照时的降级卡片：只展示作者、配文与操作行。
class _FallbackCard extends StatelessWidget {
  const _FallbackCard({required this.post, required this.footer, this.onOpen});

  final FeedPost post;
  final Widget footer;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final caption = post.caption?.trim() ?? '';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.authorUsername, style: tt.titleMedium),
              const SizedBox(height: 8),
              Text(
                caption.isEmpty ? '分享了训练动态' : caption,
                style: tt.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text('训练快照缺失，无法展示详情', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}
