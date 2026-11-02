"""社交动态 Schemas：分享卡片、动态流、评论、点赞"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from .workout import CamelModel


class ShareCreate(CamelModel):
    """分享请求体（可空）"""

    caption: Optional[str] = Field(default=None, max_length=500, description="配文")


class CommentCreate(CamelModel):
    """评论请求体"""

    body: str = Field(..., min_length=1, max_length=500, description="评论内容")
    set_id: Optional[int] = Field(
        default=None, description="针对某一组评论；须属于该动态的来源会话"
    )


class FeedPostResponse(BaseModel):
    """动态卡片"""

    id: int
    user_id: int
    author_username: str
    session_id: Optional[int] = None  # 来源会话被删后为 null，快照仍完整
    caption: Optional[str] = None
    highlights: Optional[dict] = None  # 分享时的快照（已解析为对象）
    created_at: datetime
    like_count: int = 0
    comment_count: int = 0
    liked_by_me: bool = False


class FeedListResponse(BaseModel):
    items: list[FeedPostResponse] = Field(default_factory=list)
    total: int = 0


class CommentSetRef(BaseModel):
    """评论关联的组引用"""

    set_id: int
    set_number: int
    exercise_name: Optional[str] = None
    weight_kg: Optional[float] = None
    reps: Optional[int] = None


class CommentResponse(BaseModel):
    id: int
    post_id: int
    user_id: int
    author_username: str
    body: str
    set: Optional[CommentSetRef] = None
    created_at: datetime


class CommentListResponse(BaseModel):
    items: list[CommentResponse] = Field(default_factory=list)
    total: int = 0


class LikeResponse(BaseModel):
    post_id: int
    like_count: int
    liked_by_me: bool
