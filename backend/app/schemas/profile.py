"""健身档案 Schema"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class ProfileUpsert(CamelModel):
    """引导页一次性提交；第二批字段可空。"""

    gender: str = Field(..., pattern="^(male|female|undisclosed)$")
    birth_year: int = Field(..., ge=1926, le=2018)
    height_cm: float = Field(..., ge=100, le=250)
    weight_kg: float = Field(..., ge=30, le=300)
    goal: str = Field(
        ..., pattern="^(fat_loss|muscle_gain|reshape|health|performance)$"
    )
    experience: str = Field(..., pattern="^(beginner|intermediate|advanced)$")
    injury_tags: list[str] = Field(default_factory=list)
    weekly_days: Optional[int] = Field(default=None, ge=2, le=7)
    session_minutes: Optional[int] = Field(default=None, ge=15, le=180)
    equipment: Optional[str] = Field(default=None, pattern="^(none|dumbbells|gym)$")
    preferences: list[str] = Field(default_factory=list)


class ProfileMetricsResponse(BaseModel):
    age: int
    bmr: float
    tdee: float
    calorie_target: float
    max_hr: float
    activity_factor: float
    split_name: str


class ProfileResponse(BaseModel):
    user_id: int
    gender: str
    birth_year: int
    height_cm: float
    weight_kg: float
    goal: str
    experience: str
    injury_tags: list[str] = Field(default_factory=list)
    weekly_days: Optional[int] = None
    session_minutes: Optional[int] = None
    equipment: Optional[str] = None
    preferences: list[str] = Field(default_factory=list)
    updated_at: datetime
    metrics: ProfileMetricsResponse

    model_config = ConfigDict(from_attributes=True)


class ProfileEnvelope(BaseModel):
    """GET 始终 200：未引导 complete=false。"""

    complete: bool
    profile: Optional[ProfileResponse] = None


class WeightHistoryPoint(BaseModel):
    date: str  # date-only ISO 字符串（"2026-07-01"），不会被 UtcZJsonMiddleware 补 Z
    weight_kg: float
    ma7_kg: Optional[float] = None


class WeightHistoryResponse(BaseModel):
    period_days: int
    points: list[WeightHistoryPoint] = Field(default_factory=list)
    change_kg: Optional[float] = None
    records: int = 0
