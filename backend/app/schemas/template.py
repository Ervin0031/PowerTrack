"""Workout template schemas"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


DIFFICULTIES = ("easy", "moderate", "hard")


class TemplateSetPayload(CamelModel):
    set_number: int = Field(..., ge=1)
    reps: Optional[int] = Field(default=None, ge=0)
    weight_kg: Optional[float] = Field(default=None, ge=0)
    duration_seconds: Optional[int] = Field(default=None, ge=0)
    distance_meters: Optional[float] = Field(default=None, ge=0)
    notes: Optional[str] = None
    set_kind: str = Field(default="working", max_length=20)


class TemplateExercisePayload(CamelModel):
    exercise_id: int
    sort_order: int = 0
    superset_id: Optional[int] = None
    notes: Optional[str] = None
    rest_target_seconds: Optional[int] = Field(default=None, ge=0)
    weight_unit: str = Field(default="kg", max_length=8)
    sets: list[TemplateSetPayload] = Field(default_factory=list)


class TemplateWrite(CamelModel):
    title: str = Field(..., min_length=1, max_length=120)
    description: Optional[str] = None
    difficulty: str = Field(default="moderate")
    is_public: bool = False
    exercises: list[TemplateExercisePayload] = Field(default_factory=list)


class TemplateSetResponse(BaseModel):
    id: int
    set_number: int
    reps: Optional[int] = None
    weight_kg: Optional[float] = None
    duration_seconds: Optional[int] = None
    distance_meters: Optional[float] = None
    notes: Optional[str] = None
    set_kind: str = "working"

    model_config = ConfigDict(from_attributes=True)


class TemplateExerciseResponse(BaseModel):
    id: int
    exercise_id: int
    name: str
    name_en: Optional[str] = None
    image_url: Optional[str] = None
    exercise_type: str = "compound"
    sort_order: int = 0
    superset_id: Optional[int] = None
    notes: Optional[str] = None
    rest_target_seconds: Optional[int] = None
    weight_unit: str = "kg"
    sets: list[TemplateSetResponse] = Field(default_factory=list)


class TemplateMuscleHit(BaseModel):
    name: str
    name_en: str
    is_primary: bool
    set_count: int = 0


class TemplateEquipmentHit(BaseModel):
    id: int
    name: str
    name_en: str


class TemplateListItem(BaseModel):
    id: int
    user_id: int
    owner_username: str
    title: str
    description: Optional[str] = None
    cover_url: Optional[str] = None
    difficulty: str
    is_public: bool
    exercise_count: int = 0
    set_count: int = 0
    completion_count: int = 0
    is_owner: bool = False
    created_at: datetime
    updated_at: datetime
    primary_muscles: list[TemplateMuscleHit] = Field(default_factory=list)
    secondary_muscles: list[TemplateMuscleHit] = Field(default_factory=list)
    equipment: list[TemplateEquipmentHit] = Field(default_factory=list)


class TemplateDetailResponse(TemplateListItem):
    exercises: list[TemplateExerciseResponse] = Field(default_factory=list)


class TemplateCompletionItem(BaseModel):
    session_id: int
    user_id: int
    username: str
    started_at: datetime
    completed_at: Optional[datetime] = None
    duration_seconds: Optional[int] = None
    set_count: int = 0
    is_self: bool = False
