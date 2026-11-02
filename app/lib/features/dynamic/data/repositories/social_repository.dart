import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/features/dynamic/domain/entities/feed_comment.dart';
import 'package:app_flutter/features/dynamic/domain/entities/feed_post.dart';
import 'package:app_flutter/features/dynamic/domain/entities/social_user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(ref.watch(dioProvider)),
);

/// 社交数据仓库：关注流、分享、点赞、评论、关注关系。
///
/// 只做「网络请求 + 响应解析」，可见性（他人动态需已关注）由后端把关：
/// 无权访问时后端一律返回 404，这里照常抛出由上层提示。
class SocialRepository {
  SocialRepository(this._dio);

  final Dio _dio;

  /// `GET /api/v1/feed`：自己 + 已关注用户的动态，时间倒序。
  Future<FeedPage> listFeed({int skip = 0, int limit = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/feed',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final data = response.data;
    if (data == null) throw const FormatException('动态流响应缺少数据');
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    return FeedPage(
      items: rawItems.whereType<Map<String, dynamic>>().map(FeedPost.fromJson).toList(),
      total: (data['total'] as num?)?.toInt() ?? rawItems.length,
    );
  }

  /// `POST /api/v1/sessions/{id}/share`：把自己的已完成训练发成动态。
  ///
  /// 幂等：同一会话重复分享复用同一条（返回同 id，刷新快照与配文）。
  Future<FeedPost> shareSession(int sessionId, {String? caption}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sessions/$sessionId/share',
      data: {if (caption != null && caption.isNotEmpty) 'caption': caption},
    );
    final data = response.data;
    if (data == null) throw const FormatException('分享响应缺少数据');
    return FeedPost.fromJson(data);
  }

  /// `DELETE /api/v1/feed/posts/{id}`：删自己的动态（级联评论与点赞）。
  Future<void> deletePost(int postId) async {
    await _dio.delete<void>('/api/v1/feed/posts/$postId');
  }

  /// `GET /api/v1/feed/posts/{id}/comments`：评论列表，时间正序。
  Future<List<FeedComment>> listComments(int postId, {int skip = 0, int limit = 50}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/feed/posts/$postId/comments',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final data = response.data;
    if (data == null) return const [];
    return (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FeedComment.fromJson)
        .toList();
  }

  /// `POST /api/v1/feed/posts/{id}/comments`：发表评论（可针对某一组）。
  Future<FeedComment> createComment(int postId, {required String body, int? setId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/feed/posts/$postId/comments',
      data: {'body': body, 'setId': ?setId},
    );
    final data = response.data;
    if (data == null) throw const FormatException('评论响应缺少数据');
    return FeedComment.fromJson(data);
  }

  /// `DELETE /api/v1/feed/comments/{id}`：删自己的评论。
  Future<void> deleteComment(int commentId) async {
    await _dio.delete<void>('/api/v1/feed/comments/$commentId');
  }

  /// `POST|DELETE /api/v1/feed/posts/{id}/like`：点赞 / 取消（均幂等）。
  Future<LikeState> setLike(int postId, {required bool liked}) async {
    final path = '/api/v1/feed/posts/$postId/like';
    final response = liked
        ? await _dio.post<Map<String, dynamic>>(path)
        : await _dio.delete<Map<String, dynamic>>(path);
    final data = response.data;
    if (data == null) throw const FormatException('点赞响应缺少数据');
    return LikeState.fromJson(data);
  }

  /// `GET /api/v1/users/search?q=`：按用户名模糊搜索（排除自己）。
  Future<SocialUserPage> searchUsers(String query, {int skip = 0, int limit = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/users/search',
      queryParameters: {'q': query, 'skip': skip, 'limit': limit},
    );
    final data = response.data;
    if (data == null) throw const FormatException('用户搜索响应缺少数据');
    return SocialUserPage.fromJson(data);
  }

  /// `POST|DELETE /api/v1/users/{id}/follow`：关注 / 取关（均幂等）。
  Future<FollowState> setFollow(int userId, {required bool follow}) async {
    final path = '/api/v1/users/$userId/follow';
    final response = follow
        ? await _dio.post<Map<String, dynamic>>(path)
        : await _dio.delete<Map<String, dynamic>>(path);
    final data = response.data;
    if (data == null) throw const FormatException('关注响应缺少数据');
    return FollowState.fromJson(data);
  }

  /// `GET /api/v1/users/{id}/followers`：粉丝列表（谁关注了 TA）。
  Future<SocialUserPage> listFollowers(int userId, {int skip = 0, int limit = 50}) =>
      _listUsers('/api/v1/users/$userId/followers', skip: skip, limit: limit);

  /// `GET /api/v1/users/{id}/following`：关注列表（TA 关注了谁）。
  Future<SocialUserPage> listFollowing(int userId, {int skip = 0, int limit = 50}) =>
      _listUsers('/api/v1/users/$userId/following', skip: skip, limit: limit);

  Future<SocialUserPage> _listUsers(String path, {required int skip, required int limit}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final data = response.data;
    if (data == null) throw const FormatException('用户列表响应缺少数据');
    return SocialUserPage.fromJson(data);
  }
}

/// 关注流分页结果。
class FeedPage {
  const FeedPage({required this.items, required this.total});

  final List<FeedPost> items;
  final int total;
}
