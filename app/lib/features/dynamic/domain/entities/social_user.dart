/// 可关注的其他用户（纯 Dart，对应 `GET /users/search` 与粉丝/关注列表）。
class SocialUser {
  const SocialUser({required this.id, required this.username, this.isFollowing = false});

  factory SocialUser.fromJson(Map<String, dynamic> json) {
    return SocialUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      isFollowing: json['is_following'] == true,
    );
  }

  final int id;
  final String username;

  /// 当前登录用户是否已关注 TA。
  final bool isFollowing;

  SocialUser copyWith({bool? isFollowing}) =>
      SocialUser(id: id, username: username, isFollowing: isFollowing ?? this.isFollowing);
}

/// 关注 / 取关后的最新状态（`POST/DELETE /users/{id}/follow`）。
class FollowState {
  const FollowState({required this.userId, required this.following, this.followersCount = 0});

  factory FollowState.fromJson(Map<String, dynamic> json) {
    return FollowState(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      following: json['following'] == true,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
    );
  }

  final int userId;
  final bool following;
  final int followersCount;
}

/// 用户分页列表（搜索 / 粉丝 / 关注共用）。
class SocialUserPage {
  const SocialUserPage({required this.items, required this.total});

  factory SocialUserPage.fromJson(Map<String, dynamic> json) {
    return SocialUserPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SocialUser.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  final List<SocialUser> items;
  final int total;
}
