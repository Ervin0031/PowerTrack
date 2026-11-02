"""社交动态接口：分享卡片、关注流、评论、点赞"""

import json
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.crud.feed import feed_crud, follow_crud
from app.crud.workout import session_crud, set_crud
from app.models.user import User
from app.schemas.feed import (
    CommentCreate,
    CommentListResponse,
    CommentResponse,
    CommentSetRef,
    FeedListResponse,
    FeedPostResponse,
    LikeResponse,
    ShareCreate,
)
from app.services.feed import build_session_snapshot, post_to_dict

# session 资源（分享）无前缀；其余走 /feed
share_router = APIRouter(tags=["Feed"])
feed_router = APIRouter(prefix="/feed", tags=["Feed"])


def _comment_response(row: tuple) -> CommentResponse:
    comment, username, set_number, exercise_name, weight_kg, reps = row
    set_ref = None
    if comment.set_id is not None:
        set_ref = CommentSetRef(
            set_id=comment.set_id,
            set_number=set_number or 0,
            exercise_name=exercise_name,
            weight_kg=weight_kg,
            reps=reps,
        )
    return CommentResponse(
        id=comment.id,
        post_id=comment.post_id,
        user_id=comment.user_id,
        author_username=username,
        body=comment.body,
        set=set_ref,
        created_at=comment.created_at,
    )


async def _visible_post(db: AsyncSession, post_id: int, viewer_id: int):
    """取动态并校验可见性；看不见的一律 404，不泄露存在性。"""
    post = await feed_crud.get_post(db, post_id)
    if not post or not await feed_crud.can_view(db, post, viewer_id):
        raise HTTPException(404, "Post not found")
    return post


@share_router.post(
    "/sessions/{session_id}/share",
    response_model=FeedPostResponse,
    summary="分享训练为动态",
    description=(
        "需认证。把一次**已完成**的训练发布为动态卡片，仅可分享自己的训练。"
        "卡片内嵌分享时刻的快照（总容量、硬组数、肌群高亮、PR 高亮），"
        "之后即使原训练被删除，动态内容依然完整（session_id 变为 null）。\n\n"
        "请求格式：Path `session_id` int 必填；Body 可省略，或 `caption`（≤500 字符配文）。\n\n"
        '```json\n{"caption": "今天卧推涨了 5kg"}\n```\n\n'
        "返回格式（200）：FeedPostResponse，`highlights` 为解析后的快照对象，"
        "结构见 `snapshot.schema_version=1`：`total_volume_kg / hard_sets / total_sets / "
        "muscles[] / prs[]`（每动作取本次 e1RM 最高组，超过历史最好才算 PR，最多各 5 条）。\n\n"
        "幂等：同一会话重复分享复用同一条动态（同 `id`），刷新快照与配文。\n\n"
        "错误码：404 会话不存在或不属于当前用户；409 会话尚未结束。"
    ),
    response_description="动态已发布（或幂等刷新），返回卡片内容。",
)
async def share_session(
    session_id: int,
    data: Optional[ShareCreate] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """分享已完成训练为动态（同会话幂等复用）"""
    session = await session_crud.get_by_id(db, session_id)
    if not session or session.user_id != current_user.id:
        raise HTTPException(404, "Session not found")
    if session.status != "completed":
        raise HTTPException(409, "Only completed sessions can be shared")

    caption = data.caption.strip() if data and data.caption else None
    rows = await set_crud.list_session_detail_rows(db, session.id)
    exercise_ids = sorted({row[2] for row in rows})
    prior_rows = await set_crud.list_set_loads_by_exercises(
        db, current_user.id, exercise_ids, session.started_at
    )
    snapshot = build_session_snapshot(
        rows,
        prior_rows,
        session_id=session.id,
        started_at=session.started_at,
        completed_at=session.completed_at,
        notes=session.notes,
    )
    post = await feed_crud.create_or_update_post(
        db,
        user_id=current_user.id,
        session_id=session.id,
        caption=caption,
        highlights=json.dumps(snapshot, ensure_ascii=False),
    )
    like_count, liked = (await feed_crud.like_stats(db, [post.id], current_user.id))[
        post.id
    ]
    counts = await feed_crud.comment_counts(db, [post.id])
    return FeedPostResponse(
        **post_to_dict(
            post,
            author_username=current_user.username,
            like_count=like_count,
            comment_count=counts.get(post.id, 0),
            liked_by_me=liked,
        )
    )


@feed_router.get(
    "",
    response_model=FeedListResponse,
    summary="关注流",
    description=(
        "需认证。返回自己 + 已关注用户的动态，按时间倒序（同时间按 id 倒序）。\n\n"
        "请求格式（Query）：`skip` ≥0 默认 0；`limit` 1–100 默认 20。\n\n"
        "返回格式（200）：`{items: [FeedPostResponse], total}`，"
        "每条含 `like_count / comment_count / liked_by_me`（无 N+1 查询）。"
    ),
    response_description="关注流分页列表。",
)
async def get_feed(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """自己 + 关注者的动态流"""
    author_ids = sorted(
        await follow_crud.list_following_ids(db, current_user.id) | {current_user.id}
    )
    rows, total = await feed_crud.list_feed(db, author_ids, skip, limit)
    post_ids = [post.id for post, _ in rows]
    stats = await feed_crud.like_stats(db, post_ids, current_user.id)
    counts = await feed_crud.comment_counts(db, post_ids)
    items = []
    for post, username in rows:
        like_count, liked = stats.get(post.id, (0, False))
        items.append(
            FeedPostResponse(
                **post_to_dict(
                    post,
                    author_username=username,
                    like_count=like_count,
                    comment_count=counts.get(post.id, 0),
                    liked_by_me=liked,
                )
            )
        )
    return FeedListResponse(items=items, total=total)


@feed_router.delete(
    "/posts/{post_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="删除动态",
    description=(
        "需认证。仅作者本人可删；级联清理该动态的评论与点赞（不影响原训练记录）。\n\n"
        "请求格式（Path）：`post_id` int 必填。\n\n"
        "返回格式：204 无响应体。\n\n"
        "错误码：404 动态不存在或不是自己发布的。"
    ),
    response_description="删除成功，无响应体。",
)
async def delete_post(
    post_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除自己的动态（级联评论/点赞）"""
    post = await feed_crud.get_post(db, post_id)
    if not post or post.user_id != current_user.id:
        raise HTTPException(404, "Post not found")
    await feed_crud.delete_post(db, post_id)


@feed_router.get(
    "/posts/{post_id}/comments",
    response_model=CommentListResponse,
    summary="评论列表",
    description=(
        "需认证。可见性同动态本身（作者本人或已关注作者），否则 404。"
        "按时间正序；针对某一组的评论带 `set` 引用（`set_id / set_number / "
        "exercise_name / weight_kg / reps`）。\n\n"
        "请求格式（Path + Query）：`post_id` int 必填；`skip` ≥0；`limit` 1–100 默认 50。\n\n"
        "返回格式（200）：`{items: [CommentResponse], total}`。"
    ),
    response_description="评论分页列表（时间正序）。",
)
async def list_comments(
    post_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """查看某条动态的评论"""
    await _visible_post(db, post_id, current_user.id)
    rows, total = await feed_crud.list_comments(db, post_id, skip, limit)
    return CommentListResponse(
        items=[_comment_response(row) for row in rows], total=total
    )


@feed_router.post(
    "/posts/{post_id}/comments",
    response_model=CommentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="发表评论",
    description=(
        "需认证。可见性同动态本身（作者本人或已关注作者），否则 404。\n\n"
        "请求格式（JSON Body，兼容 camelCase/snake_case）：\n"
        "- `body`: string 必填，1–500 字符（首尾空白会被去除，全空白判 422）\n"
        "- `set_id`: int 可选，针对具体某一组评论；该组必须属于动态的来源会话，否则 400\n\n"
        '```json\n{"body": "这组动作很稳", "setId": 12}\n```\n\n'
        "返回格式（201）：CommentResponse，含 `set` 组引用（组已被删时为 null）。"
    ),
    response_description="评论已发表。",
)
async def create_comment(
    post_id: int,
    data: CommentCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """发表评论（可针对某一组）"""
    post = await _visible_post(db, post_id, current_user.id)
    body = data.body.strip()
    if not body:
        raise HTTPException(422, "Comment body cannot be empty")
    if data.set_id is not None:
        owner_session_id = await feed_crud.get_set_owner_session(db, data.set_id)
        if owner_session_id is None or owner_session_id != post.session_id:
            raise HTTPException(400, "set_id does not belong to this post's session")
    comment = await feed_crud.create_comment(
        db, post_id=post.id, user_id=current_user.id, body=body, set_id=data.set_id
    )
    return _comment_response(await feed_crud.get_comment_row(db, comment.id))


@feed_router.delete(
    "/comments/{comment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="删除评论",
    description=(
        "需认证。仅评论作者本人可删。\n\n"
        "请求格式（Path）：`comment_id` int 必填。\n\n"
        "返回格式：204 无响应体。\n\n"
        "错误码：404 评论不存在；403 不是自己的评论。"
    ),
    response_description="删除成功，无响应体。",
)
async def delete_comment(
    comment_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除自己的评论"""
    comment = await feed_crud.get_comment(db, comment_id)
    if not comment:
        raise HTTPException(404, "Comment not found")
    if comment.user_id != current_user.id:
        raise HTTPException(403, "Not allowed to delete this comment")
    await feed_crud.delete_comment(db, comment_id)


@feed_router.post(
    "/posts/{post_id}/like",
    response_model=LikeResponse,
    summary="点赞",
    description=(
        "需认证。可见性同动态本身（作者本人或已关注作者），否则 404。幂等：重复点赞不重复计数。\n\n"
        "请求格式（Path）：`post_id` int 必填。\n\n"
        "返回格式（200）：`{post_id, like_count, liked_by_me}`。"
    ),
    response_description="点赞成功（幂等），返回最新计数。",
)
async def like_post(
    post_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """点赞（幂等）"""
    await _visible_post(db, post_id, current_user.id)
    count = await feed_crud.set_like(db, post_id, current_user.id, True)
    return LikeResponse(post_id=post_id, like_count=count, liked_by_me=True)


@feed_router.delete(
    "/posts/{post_id}/like",
    response_model=LikeResponse,
    summary="取消点赞",
    description=(
        "需认证。可见性同动态本身（作者本人或已关注作者），否则 404。幂等：未点赞时取消也不报错。\n\n"
        "请求格式（Path）：`post_id` int 必填。\n\n"
        "返回格式（200）：`{post_id, like_count, liked_by_me(false)}`。"
    ),
    response_description="已取消点赞（幂等），返回最新计数。",
)
async def unlike_post(
    post_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """取消点赞（幂等）"""
    await _visible_post(db, post_id, current_user.id)
    count = await feed_crud.set_like(db, post_id, current_user.id, False)
    return LikeResponse(post_id=post_id, like_count=count, liked_by_me=False)
