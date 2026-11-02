import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/dynamic/domain/entities/social_user.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 用户行：头像 + 用户名 + 关注按钮（搜索结果与粉丝/关注列表共用）。
///
/// 关注状态不在这里做本地镜像：按钮只负责把点击抛给调用方，
/// 状态由上游 provider 刷新后回灌。
class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.user, this.onToggleFollow, this.onOpenFollows});

  final SocialUser user;
  final VoidCallback? onToggleFollow;

  /// 点行查看 TA 的粉丝 / 关注（传 null 则整行不可点）。
  final VoidCallback? onOpenFollows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return M3ESegmentedColumn(
      outerRadius: AppRadius.card,
      padding: EdgeInsets.zero,
      children: [
        InkWell(
          onTap: onOpenFollows,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Row(
              children: [
            CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Text(
                user.username.isEmpty ? '?' : user.username.substring(0, 1),
                style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(user.username, style: tt.titleMedium)),
            if (onToggleFollow != null)
              user.isFollowing
                  ? OutlinedButton(
                      onPressed: onToggleFollow,
                      child: const Text('已关注'),
                    )
                  : FilledButton(
                      onPressed: onToggleFollow,
                      child: const Text('关注'),
                    ),
                if (onOpenFollows != null)
                  Icon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
