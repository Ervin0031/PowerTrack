"""Workout template models"""

from datetime import datetime, timezone
from typing import Optional

from pydantic import NaiveDatetime
from sqlmodel import Field, SQLModel


def _now_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class WorkoutTemplate(SQLModel, table=True):
    """Reusable workout template."""

    __tablename__ = "workout_templates"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True, description="创建者")
    title: str = Field(max_length=120, description="标题")
    description: Optional[str] = Field(default=None, description="说明")
    cover_image_key: Optional[str] = Field(
        default=None, max_length=500, description="封面图 object key"
    )
    difficulty: str = Field(
        default="moderate",
        max_length=20,
        description="easy / moderate / hard",
    )
    is_public: bool = Field(default=False, description="公开或私密")
    created_at: NaiveDatetime = Field(default_factory=_now_naive)
    updated_at: NaiveDatetime = Field(default_factory=_now_naive)


class WorkoutTemplateExercise(SQLModel, table=True):
    """An exercise slot inside a template."""

    __tablename__ = "workout_template_exercises"

    id: Optional[int] = Field(default=None, primary_key=True)
    template_id: int = Field(
        foreign_key="workout_templates.id", index=True, description="所属模板"
    )
    exercise_id: int = Field(foreign_key="exercises.id", index=True, description="动作")
    sort_order: int = Field(default=0, description="排序")
    superset_id: Optional[int] = Field(
        default=None, index=True, description="同一值视为一组超级组"
    )
    notes: Optional[str] = Field(default=None, description="动作备注")
    rest_target_seconds: Optional[int] = Field(default=None, description="目标休息秒数")
    weight_unit: str = Field(default="kg", max_length=8, description="重量单位")


class WorkoutTemplateSet(SQLModel, table=True):
    """Planned set inside a template exercise."""

    __tablename__ = "workout_template_sets"

    id: Optional[int] = Field(default=None, primary_key=True)
    template_exercise_id: int = Field(
        foreign_key="workout_template_exercises.id",
        index=True,
        description="所属模板动作",
    )
    set_number: int = Field(description="组序号(从1开始)")
    reps: Optional[int] = Field(default=None, description="次数")
    weight_kg: Optional[float] = Field(default=None, description="重量(kg)")
    duration_seconds: Optional[int] = Field(default=None, description="持续时间(秒)")
    distance_meters: Optional[float] = Field(default=None, description="距离(米)")
    notes: Optional[str] = Field(default=None, description="备注")
    set_kind: str = Field(
        default="working",
        max_length=20,
        description="warmup / working / cooldown / drop",
    )
