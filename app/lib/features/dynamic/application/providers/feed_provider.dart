import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:app_flutter/features/dynamic/data/repositories/social_repository.dart';
import 'package:app_flutter/features/dynamic/domain/entities/feed_comment.dart';
import 'package:app_flutter/features/dynamic/domain/entities/feed_post.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _pageSize = 20;

class FeedState {
  const FeedState({
    this.items = const [],
    this.skip = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<FeedPost> items;
  final int skip;
  final bool hasMore;
  final bool isLoadingMore;

  FeedState copyWith({List<FeedPost>? items, int? skip, bool? hasMore, bool? isLoadingMore}) {
    return FeedState(
      items: items ?? this.items,
      skip: skip ?? this.skip,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  /// 就地替换一条动态，用于点赞/评论数的乐观更新。
  FeedState replace(FeedPost post) {
    return copyWith(items: [for (final item in items) item.id == post.id ? post : item]);
  }
}

/// 关注流（自己 + 已关注用户）。结束训练后自动刷新。
class FeedController extends AsyncNotifier<FeedState> {
  /// 点赞请求在途的动态 id，防连点。
  final _pendingLikes = <int>{};

  @override
  Future<FeedState> build() async {
    ref.watch(trainingSessionProvider.select((async) => async.value?.sessionId));
    return _loadPage(skip: 0, previous: const []);
  }

  Future<void> refresh() async {
    try {
      state = AsyncData(await _loadPage(skip: 0, previous: const []));
    } catch (error, stackTrace) {
      if (state.value == null) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      state = AsyncData(await _loadPage(skip: current.skip, previous: current.items));
    } catch (_) {
      final latest = state.value;
      if (latest != null) state = AsyncData(latest.copyWith(isLoadingMore: false));
    }
  }

  /// 乐观点赞/取消：先改本地 → 发请求 → 用服务端计数覆盖；失败回滚。
  Future<void> toggleLike(int postId) async {
    final current = state.value;
    if (current == null || !_pendingLikes.add(postId)) return;
    final index = current.items.indexWhere((p) => p.id == postId);
    if (index < 0) {
      _pendingLikes.remove(postId);
      return;
    }
    final target = current.items[index];
    final liked = !target.likedByMe;
    state = AsyncData(
      current.replace(target.copyWith(likedByMe: liked, likeCount: target.likeCount + (liked ? 1 : -1))),
    );
    try {
      final result = await ref.read(socialRepositoryProvider).setLike(postId, liked: liked);
      _apply((post) => post.copyWith(likedByMe: result.likedByMe, likeCount: result.likeCount));
    } catch (_) {
      // 失败回滚到点击前的状态。
      _applyTo(postId, (_) => target);
      rethrow;
    } finally {
      _pendingLikes.remove(postId);
    }
  }

  /// 乐观删除自己的动态；失败回滚（把原条目按原位置插回）。
  Future<void> removePost(int postId) async {
    final current = state.value;
    if (current == null) return;
    final index = current.items.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    final removed = current.items[index];
    state = AsyncData(current.copyWith(items: [...current.items]..removeAt(index)));
    try {
      await ref.read(socialRepositoryProvider).deletePost(postId);
    } catch (_) {
      final latest = state.value;
      if (latest != null) {
        final restored = [...latest.items]..insert(index.clamp(0, latest.items.length), removed);
        state = AsyncData(latest.copyWith(items: restored));
      }
      rethrow;
    }
  }

  /// 评论数变化后同步卡片计数（详情页发/删评论时调用）。
  void bumpCommentCount(int postId, int delta) {
    _applyTo(postId, (post) => post.copyWith(commentCount: (post.commentCount + delta).clamp(0, 1 << 30)));
  }

  void _apply(FeedPost Function(FeedPost) update) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(items: [for (final post in current.items) update(post)]));
  }

  void _applyTo(int postId, FeedPost Function(FeedPost) update) {
    final current = state.value;
    if (current == null) return;
    final index = current.items.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    state = AsyncData(current.replace(update(current.items[index])));
  }

  Future<FeedState> _loadPage({required int skip, required List<FeedPost> previous}) async {
    final page = await ref.read(socialRepositoryProvider).listFeed(skip: skip, limit: _pageSize);
    return FeedState(
      items: [...previous, ...page.items],
      skip: skip + page.items.length,
      hasMore: skip + page.items.length < page.total,
    );
  }
}

final feedProvider = AsyncNotifierProvider<FeedController, FeedState>(FeedController.new);

/// 某条动态的评论列表（时间正序），支持乐观插入与删除。
class FeedCommentsController extends AutoDisposeFamilyAsyncNotifier<List<FeedComment>, int> {
  @override
  Future<List<FeedComment>> build(int postId) {
    return ref.read(socialRepositoryProvider).listComments(postId);
  }

  /// 乐观插入临时条目（负 id），成功后换成服务端返回的真实条目。
  Future<void> add(String body, {int? setId}) async {
    final current = state.value ?? const <FeedComment>[];
    final me = ref.read(authControllerProvider).value;
    final temp = FeedComment(
      id: -DateTime.now().microsecondsSinceEpoch,
      postId: arg,
      userId: me?.id ?? 0,
      authorUsername: me?.username ?? '我',
      body: body,
      createdAt: DateTime.now().toUtc(),
    );
    state = AsyncData([...current, temp]);
    try {
      final saved = await ref.read(socialRepositoryProvider).createComment(arg, body: body, setId: setId);
      state = AsyncData([
        for (final comment in state.value ?? const <FeedComment>[]) comment.id == temp.id ? saved : comment,
      ]);
    } catch (_) {
      state = AsyncData([
        for (final comment in state.value ?? const <FeedComment>[]) if (comment.id != temp.id) comment,
      ]);
      rethrow;
    }
  }

  Future<void> remove(int commentId) async {
    final current = state.value ?? const <FeedComment>[];
    final index = current.indexWhere((c) => c.id == commentId);
    if (index < 0) return;
    final removed = current[index];
    state = AsyncData([...current]..removeAt(index));
    try {
      await ref.read(socialRepositoryProvider).deleteComment(commentId);
    } catch (_) {
      final latest = state.value ?? const <FeedComment>[];
      state = AsyncData([...latest]..insert(index.clamp(0, latest.length), removed));
      rethrow;
    }
  }
}

final feedCommentsProvider =
    AsyncNotifierProvider.autoDispose.family<FeedCommentsController, List<FeedComment>, int>(
  FeedCommentsController.new,
);
