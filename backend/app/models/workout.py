"""训练会话 & 训练组模型"""

from datetime import datetime, timezone
from typing import Optional
from pydantic import NaiveDatetime
from sqlmodel import Field, SQLModel


def _now_naive() -> datetime:
    """Return timezone-naive UTC now, for PostgreSQL TIMESTAMP WITHOUT TIME ZONE compat."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class WorkoutSession(SQLModel, table=True):
    """训练会话"""

    __tablename__ = "workout_sessions"

    id: Optional[int] = Field(default=None, primary_key=True)
    client_uuid: str = Field(
        max_length=36, unique=True, index=True, description="客户端生成UUID, 用于幂等"
    )
    user_id: int = Field(foreign_key="users.id", index=True, description="所属用户")
    status: str = Field(
        default="in_progress",
        max_length=20,
        description="in_progress / completed",
    )
    started_at: NaiveDatetime = Field(description="训练开始时间(客户端时间)")
    completed_at: Optional[NaiveDatetime] = Field(
        default=None, description="训练结束时间"
    )
    notes: Optional[str] = Field(default=None, description="训练备注")
    template_id: Optional[int] = Field(
        default=None,
        foreign_key="workout_templates.id",
        index=True,
        description="来源训练模板",
    )
    created_at: NaiveDatetime = Field(default_factory=_now_naive)
    updated_at: NaiveDatetime = Field(default_factory=_now_naive)


class WorkoutSet(SQLModel, table=True):
    """单组训练记录"""

    __tablename__ = "workout_sets"

    id: Optional[int] = Field(default=None, primary_key=True)
    client_uuid: str = Field(
        max_length=36, unique=True, index=True, description="客户端生成UUID, 用于幂等"
    )
    session_id: int = Field(
        foreign_key="workout_sessions.id", index=True, description="所属训练会话"
    )
    exercise_id: int = Field(
        foreign_key="exercises.id", index=True, description="训练动作"
    )
    set_number: int = Field(description="组序号(从1开始)")
    set_kind: str = Field(
        default="working",
        max_length=20,
        description="warmup / working / drop / cooldown。旧数据视为 working",
    )
    reps: Optional[int] = Field(default=None, description="次数")
    weight_kg: Optional[float] = Field(default=None, description="重量(kg)")
    duration_seconds: Optional[int] = Field(
        default=None, description="持续时间(秒), 有氧/计时动作用"
    )
    distance_meters: Optional[float] = Field(
        default=None, description="距离(米), 跑步等用"
    )
    notes: Optional[str] = Field(default=None, description="备注")
    completed_at: Optional[NaiveDatetime] = Field(
        default=None, description="该组完成时间(客户端时间)"
    )
    rpe: Optional[float] = Field(
        default=None, description="主观用力程度 RPE（0.5–10.0，0.5 步进）"
    )
    created_at: NaiveDatetime = Field(default_factory=_now_naive)
