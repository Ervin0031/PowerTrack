import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:app_flutter/features/dynamic/application/providers/social_provider.dart';
import 'package:app_flutter/features/dynamic/domain/entities/social_user.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/user_tile.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 找人：按用户名搜索并直接关注 / 取关。
class UserSearchPage extends ConsumerStatefulWidget {
  const UserSearchPage({super.key});

  @override
  ConsumerState<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends ConsumerState<UserSearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 行内切换关注；乐观改本行，失败回滚。
  Future<void> _toggle(SocialUser user) async {
    try {
      final result = await ref.read(followControllerProvider).toggle(user.id, follow: !user.isFollowing);
      if (result.following == user.isFollowing) return;
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
    final results = ref.watch(userSearchProvider(_query));
    final topInset = context.appBarInset;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索用户名',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: results.when(
        loading: () => const Padding(padding: EdgeInsets.all(64), child: Center(child: M3ELoadingIndicator())),
        error: (error, _) => Padding(
          padding: EdgeInsets.fromLTRB(24, topInset + 24, 24, 24),
          child: AppErrorState(error: error, onRetry: () => ref.invalidate(userSearchProvider(_query))),
        ),
        data: (page) {
          if (_query.trim().isEmpty) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, topInset + 60, 24, 24),
              child: Center(
                child: Text(
                  '输入用户名找人',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            );
          }
          if (page.items.isEmpty) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, topInset + 40, 24, 24),
              child: const AppEmptyState(
                icon: Symbols.person_search_rounded,
                title: '没有找到这个人',
                message: '换个用户名关键词试试',
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 24),
            itemCount: page.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = page.items[index];
              return UserTile(
                user: user,
                onToggleFollow: () => _toggle(user),
                onOpenFollows: () => context.push(AppRoutes.followsOf(user.id), extra: user.username),
              );
            },
          );
        },
      ),
    );
  }
}
