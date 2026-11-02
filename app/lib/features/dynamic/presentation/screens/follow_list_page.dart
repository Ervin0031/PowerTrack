import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/dynamic/application/providers/social_provider.dart';
import 'package:app_flutter/features/dynamic/domain/entities/social_user.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/user_tile.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 某用户的粉丝 / 关注列表，两 Tab 共用一页。
class FollowListPage extends ConsumerStatefulWidget {
  const FollowListPage({super.key, required this.userId, this.username});

  final int userId;

  /// 对方的用户名，用于标题；未知时退回「TA」。
  final String? username;

  @override
  ConsumerState<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends ConsumerState<FollowListPage> {
  FollowListKind _kind = FollowListKind.followers;

  Future<void> _toggle(SocialUser user) async {
    try {
      await ref.read(followControllerProvider).toggle(user.id, follow: !user.isFollowing);
    } catch (error) {
      if (mounted) {
        showExpressiveSnack(
          context: context,
          message: userFacingErrorMessage(error),
          icon: Symbols.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(followListProvider((widget.userId, _kind)));
    final title = widget.username?.trim();
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SegmentedButton<FollowListKind>(
        segments: const [
          ButtonSegment(value: FollowListKind.followers, label: Text('粉丝')),
          ButtonSegment(value: FollowListKind.following, label: Text('关注')),
        ],
        selected: {_kind},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => setState(() => _kind = selection.first),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(title == null || title.isEmpty ? '关注关系' : title)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, context.appBarInset + 12, 16, 24),
        children: [
          header,
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(64), child: Center(child: M3ELoadingIndicator())),
            error: (error, _) => AppErrorState(
              error: error,
              onRetry: () => ref.invalidate(followListProvider((widget.userId, _kind))),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: AppEmptyState(
                    icon: Symbols.group_rounded,
                    title: _kind == FollowListKind.followers ? '还没有粉丝' : '还没有关注任何人',
                    message: '去动态页右上角「找人」关注其他训练者',
                  ),
                );
              }
              return Column(
                spacing: 8,
                children: [
                  for (final user in page.items)
                    UserTile(user: user, onToggleFollow: () => _toggle(user)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
