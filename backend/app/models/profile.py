"""用户健身档案与体重记录"""

from datetime import datetime, timezone
from typing import Optional

from pydantic import NaiveDatetime
from sqlmodel import Field, SQLModel


def _now_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class UserFitnessProfile(SQLModel, table=True):
    """每位用户一条档案；引导页一次性写入，之后可补全。"""

    __tablename__ = "user_profiles"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", unique=True, index=True)

    gender: str = Field(max_length=20, description="male / female / undisclosed")
    birth_year: int = Field(description="出生年份，用于推算年龄")
    height_cm: float = Field(description="身高(cm)")
    weight_kg: float = Field(description="体重(kg)")
    goal: str = Field(
        max_length=32,
        description="fat_loss / muscle_gain / reshape / health / performance",
    )
    experience: str = Field(
        max_length=32, description="beginner / intermediate / advanced"
    )

    injury_tags: Optional[str] = Field(
        default=None, description='JSON 数组，如 ["knee","back"]'
    )
    weekly_days: Optional[int] = Field(default=None, description="每周可练天数 2–5")
    session_minutes: Optional[int] = Field(
        default=None, description="单次时长 15/30/45/60"
    )
    equipment: Optional[str] = Field(default=None, description="none / dumbbells / gym")
    preferences: Optional[str] = Field(default=None, description="JSON 数组，运动偏好")

    created_at: NaiveDatetime = Field(default_factory=_now_naive)
    updated_at: NaiveDatetime = Field(default_factory=_now_naive)


class WeightLog(SQLModel, table=True):
    """体重流水，用于进度追踪。"""

    __tablename__ = "weight_logs"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)
    weight_kg: float
    recorded_at: NaiveDatetime = Field(default_factory=_now_naive)
