"""社交动态：关注、动态、评论、点赞。

feed_posts.highlights 是分享时的快照 JSON 字符串（沿用 samples / injury_tags 的字符串约定），
因为 DELETE /sessions/{id} 会物理删除会话，动态不能随之破碎；相关外键均 ondelete="SET NULL"。
"""

from datetime import datetime, timezone
from typing import Optional

from pydantic import NaiveDatetime
from sqlalchemy import CheckConstraint
from sqlmodel import Field, SQLModel


def _now_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class Follow(SQLModel, table=True):
    """关注关系；复合主键天然幂等。"""

    __tablename__ = "follows"
    __table_args__ = (
        CheckConstraint("follower_id <> followee_id", name="ck_follows_not_self"),
    )

    follower_id: int = Field(foreign_key="users.id", primary_key=True)
    followee_id: int = Field(foreign_key="users.id", primary_key=True, index=True)
    created_at: NaiveDatetime = Field(default_factory=_now_naive)


class FeedPost(SQLModel, table=True):
    """分享卡片：一个会话最多一条动态（session_id 唯一）。"""

    __tablename__ = "feed_posts"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)
    session_id: Optional[int] = Field(
        default=None,
        foreign_key="workout_sessions.id",
        ondelete="SET NULL",
        unique=True,
        index=True,
        description="来源会话；会话被删后置 NULL，快照仍在",
    )
    caption: Optional[str] = Field(default=None, max_length=500)
    highlights: Optional[str] = Field(
        default=None, description="分享时的快照 JSON 字符串"
    )
    created_at: NaiveDatetime = Field(default_factory=_now_naive)


class FeedComment(SQLModel, table=True):
    """动态评论；set_id 支持针对具体某一组评论。"""

    __tablename__ = "feed_comments"

    id: Optional[int] = Field(default=None, primary_key=True)
    post_id: int = Field(foreign_key="feed_posts.id", index=True)
    user_id: int = Field(foreign_key="users.id", index=True)
    set_id: Optional[int] = Field(
        default=None,
        foreign_key="workout_sets.id",
        ondelete="SET NULL",
        index=True,
        description="针对某一组评论；该组被删后置 NULL",
    )
    body: str = Field(max_length=500)
    created_at: NaiveDatetime = Field(default_factory=_now_naive)


class FeedLike(SQLModel, table=True):
    """点赞；复合主键天然幂等。"""

    __tablename__ = "feed_likes"

    post_id: int = Field(foreign_key="feed_posts.id", primary_key=True)
    user_id: int = Field(foreign_key="users.id", primary_key=True, index=True)
    created_at: NaiveDatetime = Field(default_factory=_now_naive)
