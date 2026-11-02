"""Exercise library schemas — muscle groups, equipment, exercises"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict

# ========== MuscleGroup Schemas ==========


class MuscleGroupBase(BaseModel):
    """Muscle group base schema"""

    name: str = Field(..., min_length=1, max_length=50)
    name_en: str = Field(..., min_length=1, max_length=50)
    category: str = Field(
        ..., min_length=1, max_length=20, description="upper / lower / core"
    )


class MuscleGroupCreate(MuscleGroupBase):
    """Muscle group create schema"""

    model_config = ConfigDict(
        json_schema_extra={
            "example": {"name": "胸部", "name_en": "Chest", "category": "upper"}
        }
    )


class MuscleGroupUpdate(BaseModel):
    """Muscle group update schema"""

    name: Optional[str] = Field(None, min_length=1, max_length=50)
    name_en: Optional[str] = Field(None, min_length=1, max_length=50)
    category: Optional[str] = Field(None, min_length=1, max_length=20)


class MuscleGroupResponse(MuscleGroupBase):
    """Muscle group response schema"""

    id: int

    model_config = ConfigDict(from_attributes=True)


# ========== Equipment Schemas ==========


class EquipmentBase(BaseModel):
    """Equipment base schema"""

    name: str = Field(..., min_length=1, max_length=50)
    name_en: str = Field(..., min_length=1, max_length=50)


class EquipmentCreate(EquipmentBase):
    """Equipment create schema"""

    model_config = ConfigDict(
        json_schema_extra={"example": {"name": "杠铃", "name_en": "Barbell"}}
    )


class EquipmentUpdate(BaseModel):
    """Equipment update schema"""

    name: Optional[str] = Field(None, min_length=1, max_length=50)
    name_en: Optional[str] = Field(None, min_length=1, max_length=50)


class EquipmentResponse(EquipmentBase):
    """Equipment response schema"""

    id: int

    model_config = ConfigDict(from_attributes=True)


# ========== Exercise Schemas ==========


class ExerciseBase(BaseModel):
    """Exercise base schema"""

    name: str = Field(..., min_length=1, max_length=100)
    name_en: Optional[str] = Field(None, max_length=100)
    exercise_type: str = Field(..., max_length=20, description="compound / isolation")
    primary_muscle_group_id: int
    equipment_id: Optional[int] = None
    instructions: Optional[str] = None
    is_custom: bool = False


class ExerciseCreate(ExerciseBase):
    """Exercise create schema — secondary_muscle_ids are written into the join table"""

    secondary_muscle_ids: list[int] = Field(default_factory=list)

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "杠铃卧推",
                "name_en": "Barbell Bench Press",
                "exercise_type": "compound",
                "primary_muscle_group_id": 1,
                "equipment_id": 1,
                "is_custom": False,
                "secondary_muscle_ids": [2, 3],
            }
        }
    )


class ExerciseUpdate(BaseModel):
    """Exercise update schema"""

    name: Optional[str] = Field(None, min_length=1, max_length=100)
    name_en: Optional[str] = Field(None, max_length=100)
    exercise_type: Optional[str] = Field(None, max_length=20)
    primary_muscle_group_id: Optional[int] = None
    equipment_id: Optional[int] = None
    instructions: Optional[str] = None
    is_custom: Optional[bool] = None
    secondary_muscle_ids: Optional[list[int]] = None


class ExerciseResponse(ExerciseBase):
    """Exercise response schema"""

    id: int
    image_key: Optional[str] = None
    image_url: Optional[str] = None
    thumb_key: Optional[str] = None
    thumb_url: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ExerciseDetailResponse(ExerciseResponse):
    """Exercise detail response — with joined names for display"""

    primary_muscle_name: Optional[str] = None
    primary_muscle_name_en: Optional[str] = None
    equipment_name: Optional[str] = None
    equipment_name_en: Optional[str] = None
    secondary_muscles: list["MuscleGroupResponse"] = Field(default_factory=list)
    image_url: Optional[str] = None


# ========== ExerciseSecondaryMuscle Schemas ==========


class ExerciseSecondaryMuscleResponse(BaseModel):
    """Exercise-secondary muscle relation response"""

    exercise_id: int
    muscle_group_id: int

    model_config = ConfigDict(from_attributes=True)
