"""一个用户一份当前训练块：按周重复的训练日，外加一个减量周。"""

from datetime import date, datetime, timezone
from typing import Optional

from pydantic import NaiveDatetime
from sqlmodel import Field, SQLModel


def _now_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class TrainingBlock(SQLModel, table=True):
    __tablename__ = "training_blocks"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", unique=True, index=True)
    title: str = Field(max_length=80)
    week_count: int = Field(default=4)
    deload_week: int = Field(default=4, description="1-based，等于该周时处方改为减量")
    started_on: date
    created_at: NaiveDatetime = Field(default_factory=_now_naive)
    updated_at: NaiveDatetime = Field(default_factory=_now_naive)


class TrainingBlockDay(SQLModel, table=True):
    __tablename__ = "training_block_days"

    id: Optional[int] = Field(default=None, primary_key=True)
    block_id: int = Field(foreign_key="training_blocks.id", index=True)
    weekday: int = Field(description="0 周一 … 6 周日")
    template_id: int = Field(foreign_key="workout_templates.id", index=True)
    sort_order: int = Field(default=0)
