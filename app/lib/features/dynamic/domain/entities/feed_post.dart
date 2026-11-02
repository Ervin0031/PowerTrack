import 'package:app_flutter/core/network/api_datetime.dart';
import 'package:app_flutter/features/dynamic/domain/entities/feed_highlight.dart';

/// 关注流里的一条动态（纯 Dart，对应 `GET /feed` 的 FeedPostResponse）。
///
/// [sessionId] 在源训练被删除后为 null —— 卡片内容来自 [snapshot]，不依赖会话。
class FeedPost {
  const FeedPost({
    required this.id,
    required this.userId,
    required this.authorUsername,
    this.sessionId,
    this.caption,
    this.rawHighlights,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      authorUsername: json['author_username'] as String? ?? '',
      sessionId: (json['session_id'] as num?)?.toInt(),
      caption: json['caption'] as String?,
      rawHighlights: json['highlights'] is Map<String, dynamic> ? json['highlights'] as Map<String, dynamic> : null,
      createdAt: parseApiDateTimeOrNull(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] == true,
    );
  }

  final int id;
  final int userId;
  final String authorUsername;
  final int? sessionId;
  final String? caption;
  final Map<String, dynamic>? rawHighlights;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  /// 分享时刻的训练快照；缺失或结构不对时为 null（卡片降级为纯文字）。
  FeedSnapshot? get snapshot {
    final raw = rawHighlights;
    return raw == null ? null : FeedSnapshot.fromJson(raw);
  }

  FeedPost copyWith({int? likeCount, int? commentCount, bool? likedByMe}) {
    return FeedPost(
      id: id,
      userId: userId,
      authorUsername: authorUsername,
      sessionId: sessionId,
      caption: caption,
      rawHighlights: rawHighlights,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

/// 点赞接口返回的最新状态（`POST/DELETE /feed/posts/{id}/like`）。
class LikeState {
  const LikeState({required this.postId, required this.likeCount, required this.likedByMe});

  factory LikeState.fromJson(Map<String, dynamic> json) {
    return LikeState(
      postId: (json['post_id'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] == true,
    );
  }

  final int postId;
  final int likeCount;
  final bool likedByMe;
}
