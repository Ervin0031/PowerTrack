"""社交动态 CRUD：关注、动态、评论、点赞"""

from typing import Optional

from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise
from app.models.feed import FeedComment, FeedLike, FeedPost, Follow
from app.models.user import User
from app.models.workout import WorkoutSet


class FollowCRUD:
    """关注关系"""

    @staticmethod
    async def is_following(
        db: AsyncSession, follower_id: int, followee_id: int
    ) -> bool:
        result = await db.execute(
            select(Follow.follower_id).where(
                Follow.follower_id == follower_id,
                Follow.followee_id == followee_id,
            )
        )
        return result.first() is not None

    @staticmethod
    async def follow(db: AsyncSession, follower_id: int, followee_id: int) -> bool:
        """幂等关注；返回是否新建。"""
        if await FollowCRUD.is_following(db, follower_id, followee_id):
            return False
        db.add(Follow(follower_id=follower_id, followee_id=followee_id))
        try:
            await db.commit()
        except IntegrityError:
            # 并发下另一端已插入，视为已关注
            await db.rollback()
            return False
        return True

    @staticmethod
    async def unfollow(db: AsyncSession, follower_id: int, followee_id: int) -> bool:
        """幂等取关；返回是否真的删除了一行。"""
        result = await db.execute(
            delete(Follow).where(
                Follow.follower_id == follower_id,
                Follow.followee_id == followee_id,
            )
        )
        await db.commit()
        return (result.rowcount or 0) > 0

    @staticmethod
    async def list_following_ids(db: AsyncSession, user_id: int) -> set[int]:
        result = await db.execute(
            select(Follow.followee_id).where(Follow.follower_id == user_id)
        )
        return set(result.scalars().all())

    @staticmethod
    async def count_followers(db: AsyncSession, user_id: int) -> int:
        result = await db.execute(
            select(func.count())
            .select_from(Follow)
            .where(Follow.followee_id == user_id)
        )
        return result.scalar() or 0

    @staticmethod
    async def _list_related_users(
        db: AsyncSession, join_cond, filter_cond, skip: int, limit: int
    ) -> tuple[list[User], int]:
        base = select(User).join(Follow, join_cond).where(filter_cond)
        count_stmt = select(func.count()).select_from(base.order_by(None).subquery())
        total = (await db.execute(count_stmt)).scalar() or 0
        result = await db.execute(
            base.order_by(User.username).offset(skip).limit(limit)
        )
        return list(result.scalars().all()), total

    @staticmethod
    async def list_followers(
        db: AsyncSession, user_id: int, skip: int = 0, limit: int = 20
    ) -> tuple[list[User], int]:
        return await FollowCRUD._list_related_users(
            db,
            Follow.follower_id == User.id,
            Follow.followee_id == user_id,
            skip,
            limit,
        )

    @staticmethod
    async def list_following(
        db: AsyncSession, user_id: int, skip: int = 0, limit: int = 20
    ) -> tuple[list[User], int]:
        return await FollowCRUD._list_related_users(
            db,
            Follow.followee_id == User.id,
            Follow.follower_id == user_id,
            skip,
            limit,
        )

    @staticmethod
    async def search_users(
        db: AsyncSession, query: str, viewer_id: int, skip: int = 0, limit: int = 20
    ) -> tuple[list[User], int]:
        """按用户名模糊搜索，排除自己与停用账号。"""
        base = select(User).where(
            User.username.ilike(f"%{query}%"),
            User.is_active.is_(True),
            User.id != viewer_id,
        )
        count_stmt = select(func.count()).select_from(base.order_by(None).subquery())
        total = (await db.execute(count_stmt)).scalar() or 0
        result = await db.execute(
            base.order_by(User.username).offset(skip).limit(limit)
        )
        return list(result.scalars().all()), total


class FeedCRUD:
    """动态、评论、点赞"""

    @staticmethod
    async def get_post(db: AsyncSession, post_id: int) -> Optional[FeedPost]:
        return await db.get(FeedPost, post_id)

    @staticmethod
    async def get_post_by_session(
        db: AsyncSession, session_id: int
    ) -> Optional[FeedPost]:
        result = await db.execute(
            select(FeedPost).where(FeedPost.session_id == session_id)
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def create_or_update_post(
        db: AsyncSession,
        *,
        user_id: int,
        session_id: int,
        caption: Optional[str],
        highlights: str,
    ) -> FeedPost:
        """同一会话重复分享 → 复用同一条动态并刷新快照与文案。"""
        post = await FeedCRUD.get_post_by_session(db, session_id)
        if post:
            post.caption = caption
            post.highlights = highlights
        else:
            post = FeedPost(
                user_id=user_id,
                session_id=session_id,
                caption=caption,
                highlights=highlights,
            )
        db.add(post)
        await db.commit()
        await db.refresh(post)
        return post

    @staticmethod
    async def delete_post(db: AsyncSession, post_id: int) -> bool:
        post = await FeedCRUD.get_post(db, post_id)
        if not post:
            return False
        # 手动级联，对齐 session_crud.delete 风格
        await db.execute(delete(FeedLike).where(FeedLike.post_id == post_id))
        await db.execute(delete(FeedComment).where(FeedComment.post_id == post_id))
        await db.delete(post)
        await db.commit()
        return True

    @staticmethod
    async def can_view(db: AsyncSession, post: FeedPost, viewer_id: int) -> bool:
        """作者本人，或 viewer 关注了作者。"""
        if post.user_id == viewer_id:
            return True
        return await FollowCRUD.is_following(db, viewer_id, post.user_id)

    @staticmethod
    async def list_feed(
        db: AsyncSession, author_ids: list[int], skip: int = 0, limit: int = 20
    ) -> tuple[list[tuple], int]:
        """关注流：(FeedPost, author_username)，created_at 倒序。"""
        base = (
            select(FeedPost, User.username)
            .join(User, FeedPost.user_id == User.id)
            .where(FeedPost.user_id.in_(author_ids))
        )
        count_stmt = select(func.count()).select_from(base.order_by(None).subquery())
        total = (await db.execute(count_stmt)).scalar() or 0
        result = await db.execute(
            base.order_by(FeedPost.created_at.desc(), FeedPost.id.desc())
            .offset(skip)
            .limit(limit)
        )
        return list(result.all()), total

    @staticmethod
    async def like_stats(
        db: AsyncSession, post_ids: list[int], viewer_id: int
    ) -> dict[int, tuple[int, bool]]:
        """{post_id: (count, liked_by_me)}，两条查询避免 N+1。"""
        if not post_ids:
            return {}
        counts = dict(
            (
                await db.execute(
                    select(FeedLike.post_id, func.count())
                    .where(FeedLike.post_id.in_(post_ids))
                    .group_by(FeedLike.post_id)
                )
            ).all()
        )
        mine = set(
            (
                await db.execute(
                    select(FeedLike.post_id).where(
                        FeedLike.post_id.in_(post_ids),
                        FeedLike.user_id == viewer_id,
                    )
                )
            )
            .scalars()
            .all()
        )
        return {pid: (counts.get(pid, 0), pid in mine) for pid in post_ids}

    @staticmethod
    async def comment_counts(db: AsyncSession, post_ids: list[int]) -> dict[int, int]:
        if not post_ids:
            return {}
        rows = await db.execute(
            select(FeedComment.post_id, func.count())
            .where(FeedComment.post_id.in_(post_ids))
            .group_by(FeedComment.post_id)
        )
        return dict(rows.all())

    @staticmethod
    async def count_likes(db: AsyncSession, post_id: int) -> int:
        result = await db.execute(
            select(func.count())
            .select_from(FeedLike)
            .where(FeedLike.post_id == post_id)
        )
        return result.scalar() or 0

    @staticmethod
    async def set_like(
        db: AsyncSession, post_id: int, user_id: int, liked: bool
    ) -> int:
        """幂等点赞/取消；返回最新点赞总数。"""
        if liked:
            if await db.get(FeedLike, (post_id, user_id)) is None:
                db.add(FeedLike(post_id=post_id, user_id=user_id))
                try:
                    await db.commit()
                except IntegrityError:
                    await db.rollback()
        else:
            await db.execute(
                delete(FeedLike).where(
                    FeedLike.post_id == post_id, FeedLike.user_id == user_id
                )
            )
            await db.commit()
        return await FeedCRUD.count_likes(db, post_id)

    @staticmethod
    async def list_comments(
        db: AsyncSession, post_id: int, skip: int = 0, limit: int = 50
    ) -> tuple[list[tuple], int]:
        """行形状 (FeedComment, username, set_number, 动作名, weight_kg, reps)，按时间升序。"""
        base = (
            select(
                FeedComment,
                User.username,
                WorkoutSet.set_number,
                Exercise.name,
                WorkoutSet.weight_kg,
                WorkoutSet.reps,
            )
            .join(User, FeedComment.user_id == User.id)
            .outerjoin(WorkoutSet, FeedComment.set_id == WorkoutSet.id)
            .outerjoin(Exercise, WorkoutSet.exercise_id == Exercise.id)
            .where(FeedComment.post_id == post_id)
        )
        count_stmt = select(func.count()).select_from(base.order_by(None).subquery())
        total = (await db.execute(count_stmt)).scalar() or 0
        result = await db.execute(
            base.order_by(FeedComment.created_at, FeedComment.id)
            .offset(skip)
            .limit(limit)
        )
        return list(result.all()), total

    @staticmethod
    async def create_comment(
        db: AsyncSession,
        *,
        post_id: int,
        user_id: int,
        body: str,
        set_id: Optional[int],
    ) -> FeedComment:
        comment = FeedComment(
            post_id=post_id, user_id=user_id, body=body, set_id=set_id
        )
        db.add(comment)
        await db.commit()
        await db.refresh(comment)
        return comment

    @staticmethod
    async def get_comment(db: AsyncSession, comment_id: int) -> Optional[FeedComment]:
        return await db.get(FeedComment, comment_id)

    @staticmethod
    async def get_comment_row(db: AsyncSession, comment_id: int) -> Optional[tuple]:
        """单条评论行（含作者名与组引用），形状同 list_comments。"""
        result = await db.execute(
            select(
                FeedComment,
                User.username,
                WorkoutSet.set_number,
                Exercise.name,
                WorkoutSet.weight_kg,
                WorkoutSet.reps,
            )
            .join(User, FeedComment.user_id == User.id)
            .outerjoin(WorkoutSet, FeedComment.set_id == WorkoutSet.id)
            .outerjoin(Exercise, WorkoutSet.exercise_id == Exercise.id)
            .where(FeedComment.id == comment_id)
        )
        return result.first()

    @staticmethod
    async def delete_comment(db: AsyncSession, comment_id: int) -> bool:
        comment = await FeedCRUD.get_comment(db, comment_id)
        if not comment:
            return False
        await db.delete(comment)
        await db.commit()
        return True

    @staticmethod
    async def get_set_owner_session(db: AsyncSession, set_id: int) -> Optional[int]:
        """该组所属会话 id；组不存在返回 None。"""
        result = await db.execute(
            select(WorkoutSet.session_id).where(WorkoutSet.id == set_id)
        )
        return result.scalar_one_or_none()


follow_crud = FollowCRUD()
feed_crud = FeedCRUD()
