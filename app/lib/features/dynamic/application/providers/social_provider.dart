import 'package:app_flutter/features/dynamic/application/providers/feed_provider.dart';
import 'package:app_flutter/features/dynamic/data/repositories/social_repository.dart';
import 'package:app_flutter/features/dynamic/domain/entities/social_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 用户搜索结果，按关键词取（空关键词不发请求）。
final userSearchProvider = FutureProvider.autoDispose.family<SocialUserPage, String>((ref, query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return Future.value(const SocialUserPage(items: [], total: 0));
  return ref.read(socialRepositoryProvider).searchUsers(trimmed);
});

/// 粉丝 / 关注列表的种类。
enum FollowListKind { followers, following }

/// 某用户的粉丝或关注列表。
final followListProvider =
    FutureProvider.autoDispose.family<SocialUserPage, (int userId, FollowListKind kind)>((ref, args) {
  final repo = ref.read(socialRepositoryProvider);
  final (userId, kind) = args;
  return switch (kind) {
    FollowListKind.followers => repo.listFollowers(userId),
    FollowListKind.following => repo.listFollowing(userId),
  };
});

/// 关注关系写操作。列表与流都是读 provider，改完直接 invalidate，不做本地镜像。
///
/// ponytail: 行内关注按钮的乐观更新留在按钮自己的 State 里，不为此建全局控制器。
class FollowController {
  const FollowController(this._ref);

  final Ref _ref;

  Future<FollowState> toggle(int userId, {required bool follow}) async {
    final result = await _ref.read(socialRepositoryProvider).setFollow(userId, follow: follow);
    // 关注关系变了：feed 内容、搜索结果、粉丝/关注列表都可能变。
    _ref.invalidate(feedProvider);
    _ref.invalidate(userSearchProvider);
    _ref.invalidate(followListProvider);
    return result;
  }
}

final followControllerProvider = Provider<FollowController>(FollowController.new);
