"""每位用户每个动作一条估算 1RM。"""

from datetime import datetime, timezone
from typing import Optional

from pydantic import NaiveDatetime
from sqlmodel import Field, SQLModel


def _now_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class UserExercise1RM(SQLModel, table=True):
    """估算 1RM：最近若干次有效组的中位数。"""

    __tablename__ = "user_exercise_1rm"

    user_id: int = Field(foreign_key="users.id", primary_key=True)
    exercise_id: int = Field(foreign_key="exercises.id", primary_key=True)
    estimated_kg: float
    samples: Optional[str] = Field(default=None, description="JSON 数组，最近 8 次估算")
    updated_at: NaiveDatetime = Field(default_factory=_now_naive)
