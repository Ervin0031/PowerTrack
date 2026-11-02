"""Exercise library models — muscle groups, equipment, exercises"""

from datetime import datetime, timezone
from typing import Optional

from pydantic import NaiveDatetime
from sqlmodel import Field, SQLModel


def _now_naive() -> datetime:
    """Timezone-naive UTC now, for PostgreSQL TIMESTAMP WITHOUT TIME ZONE compat."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class MuscleGroup(SQLModel, table=True):
    """Muscle group / body part"""

    __tablename__ = "muscle_groups"

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(max_length=50, description="中文名，如'胸部'")
    name_en: str = Field(max_length=50, description="英文名，如'Chest'")
    category: str = Field(max_length=20, description="upper / lower / core")


class Equipment(SQLModel, table=True):
    """Equipment type"""

    __tablename__ = "equipment"

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(max_length=50, description="中文名，如'杠铃'")
    name_en: str = Field(max_length=50, description="英文名，如'Barbell'")


class Exercise(SQLModel, table=True):
    """Exercise library — core table"""

    __tablename__ = "exercises"

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(
        max_length=100, index=True, description="动作中文名，如'杠铃卧推'"
    )
    name_en: Optional[str] = Field(
        default=None, max_length=100, description="动作英文名"
    )
    exercise_type: str = Field(
        max_length=20, description="compound（复合动作）/ isolation（孤立动作）"
    )
    primary_muscle_group_id: int = Field(
        foreign_key="muscle_groups.id", index=True, description="主要刺激肌群"
    )
    equipment_id: Optional[int] = Field(
        default=None,
        foreign_key="equipment.id",
        index=True,
        description="主要器械，自重动作可留空",
    )
    instructions: Optional[str] = Field(default=None, description="动作说明/要领")
    is_custom: bool = Field(default=False, description="是否用户自建动作")
    created_by_user_id: Optional[int] = Field(
        default=None, foreign_key="users.id", index=True, description="自建动作归属用户"
    )
    image_key: Optional[str] = Field(
        default=None, max_length=500, description="S3 object key for exercise image"
    )
    thumb_key: Optional[str] = Field(
        default=None, max_length=500, description="S3 object key for list thumbnail"
    )
    created_at: NaiveDatetime = Field(default_factory=_now_naive)


class ExerciseSecondaryMuscle(SQLModel, table=True):
    """Secondary muscles worked by an exercise (many-to-many)"""

    __tablename__ = "exercise_secondary_muscles"

    exercise_id: int = Field(foreign_key="exercises.id", primary_key=True)
    muscle_group_id: int = Field(foreign_key="muscle_groups.id", primary_key=True)
