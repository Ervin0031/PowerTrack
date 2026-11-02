"""Workout session & set schemas"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    """请求体基类：同时接受 camelCase（移动端客户端默认序列化）与 snake_case 字段名。

    仅用于请求 Schema；响应 Schema 不继承它，保持响应字段为 snake_case。
    """

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


# ========== WorkoutSet Schemas ==========


class WorkoutSetBase(BaseModel):
    """训练组基础字段"""

    exercise_id: int
    set_number: int = Field(..., ge=1, description="组序号(从1开始)")
    set_kind: str = Field(
        default="working",
        max_length=20,
        description="warmup / working / drop / cooldown",
    )
    reps: Optional[int] = Field(default=None, description="次数")
    weight_kg: Optional[float] = Field(default=None, description="重量(kg)")
    duration_seconds: Optional[int] = Field(default=None, description="持续时间(秒)")
    distance_meters: Optional[float] = Field(default=None, description="距离(米)")
    notes: Optional[str] = Field(default=None, description="备注")
    completed_at: Optional[datetime] = Field(default=None, description="该组完成时间")
    rpe: Optional[float] = Field(
        default=None, ge=0.5, le=10.0, description="主观用力程度 RPE（0.5–10.0）"
    )


class WorkoutSetCreate(CamelModel, WorkoutSetBase):
    """创建训练组 — 客户端必须提供UUID用于幂等"""

    client_uuid: str = Field(..., max_length=36, description="客户端生成UUID")


class WorkoutSetResponse(WorkoutSetBase):
    """训练组响应"""

    id: int
    client_uuid: str
    session_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ========== WorkoutSession Schemas ==========


class SessionCreate(CamelModel):
    """创建训练会话（轻量）"""

    client_uuid: str = Field(..., max_length=36, description="客户端UUID")
    started_at: datetime = Field(..., description="训练开始时间(客户端时间)")
    template_id: Optional[int] = Field(default=None, description="来源训练模板")


class SessionComplete(CamelModel):
    """结束训练 — 批量上传完整数据"""

    client_uuid: str = Field(
        ..., max_length=36, description="客户端UUID(须与创建时一致)"
    )
    started_at: datetime
    completed_at: datetime
    notes: Optional[str] = None
    template_id: Optional[int] = Field(default=None, description="来源训练模板")
    sets: list[WorkoutSetCreate] = Field(default_factory=list)


class SessionResponse(BaseModel):
    """训练会话响应"""

    id: int
    client_uuid: str
    user_id: int
    status: str
    started_at: datetime
    completed_at: Optional[datetime] = None
    notes: Optional[str] = None
    template_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SessionDetailResponse(SessionResponse):
    """训练会话详情 — 包含所有训练组"""

    sets: list[WorkoutSetResponse] = Field(default_factory=list)


# ========== Performance Query Schemas ==========


class LastPerformanceResponse(BaseModel):
    """上一次训练记录"""

    exercise_id: int
    set_number: int
    reps: Optional[int] = None
    weight_kg: Optional[float] = None
    duration_seconds: Optional[int] = None
    distance_meters: Optional[float] = None
    completed_at: Optional[datetime] = None
    session_date: Optional[datetime] = None
    rpe: Optional[float] = None


class BatchLastPerformanceResponse(BaseModel):
    """批量最后训练记录"""

    performances: dict[int, Optional[LastPerformanceResponse]] = Field(
        default_factory=dict,
        description="key=exercise_id, value=最近一次记录或null",
    )


class LastSessionSetsResponse(BaseModel):
    """某动作最近一次训练的完整组数据（训练中幽灵模式 / 预填用）"""

    exercise_id: int
    session_id: int
    session_date: Optional[datetime] = None
    sets: list[WorkoutSetResponse] = Field(default_factory=list)


# ========== RPE Recommend Schemas ==========


class RpeRecommendRequest(CamelModel):
    """根据本组重量与 RPE 请求下一组建议。"""

    weight_kg: float = Field(..., gt=0, description="本组重量(kg)")
    rpe: float = Field(..., ge=0.5, le=10.0, description="本组 RPE")
    reps: Optional[int] = Field(
        default=None, ge=1, description="本组次数。力竭时用来按 RPE 表折算下一组"
    )
    one_rm_kg: Optional[float] = Field(default=None, gt=0, description="当前估算 1RM")
    exercise_type: str = Field(default="compound", pattern="^(compound|isolation)$")
    prior_rpes: list[float] = Field(default_factory=list)
    goal: Optional[str] = Field(default=None)


class RpeRecommendResponse(BaseModel):
    """RPE 自动调节建议。"""

    suggested_weight_kg: Optional[float] = None
    extra_rest_seconds: int = 0
    fatigue_warning: bool = False
    reduce_remaining_factor: Optional[float] = None
    message: Optional[str] = None
    reason: Optional[str] = None
    capped_by_1rm: bool = False
    zone: Optional[list[float]] = None


class OneRmResponse(BaseModel):
    exercise_id: int
    estimated_kg: float
    needs_recalibrate: bool = False
    samples_count: int = 0


class OneRmHistoryPoint(BaseModel):
    date: datetime
    estimated_kg: float
    rpe: Optional[float] = None
    source_set_id: int


class OneRmHistoryResponse(BaseModel):
    items: list[OneRmHistoryPoint] = Field(default_factory=list)


class MuscleVolume(BaseModel):
    name: str
    volume: float
    hard_sets: int


class WeekVolumeResponse(BaseModel):
    week_start: str
    volume: float
    hard_volume: float
    hard_sets: int
    avg_rpe: Optional[float] = None
    by_muscle: list[MuscleVolume] = Field(default_factory=list)


class WeeklyVolumeResponse(BaseModel):
    weeks: list[WeekVolumeResponse]
    suggest_deload: bool = False
    deload_reason: Optional[str] = None


class MuscleGroupStatusItem(BaseModel):
    muscle_group_id: int
    name: str
    name_en: str
    category: str
    last_trained_at: datetime
    hours_since_last: float
    recovery_progress: float
    recovery_window_hours: float
    baseline_window_hours: float
    recovery_factor: float
    global_factor: float
    muscle_factor: float
    recovery_confidence: str
    observations_count: int


class MuscleGroupStatusResponse(BaseModel):
    items: list[MuscleGroupStatusItem] = Field(default_factory=list)
    global_factor: float = 1.0
    global_observations_count: int = 0
    global_confidence: str = "low"


class StatsPoint(BaseModel):
    t: str
    v: float


class MetricSeries(BaseModel):
    value: Optional[float] = None
    points: list[StatsPoint] = Field(default_factory=list)


class PersonalRecords(BaseModel):
    max_weight_kg: Optional[float] = None
    max_weight_at: Optional[datetime] = None
    max_reps: Optional[int] = None
    max_reps_at: Optional[datetime] = None
    max_set_volume: Optional[float] = None
    max_set_volume_at: Optional[datetime] = None
    estimated_1rm_kg: Optional[float] = None
    session_count: int = 0
    first_at: Optional[datetime] = None
    last_at: Optional[datetime] = None


class HistorySetItem(BaseModel):
    set_number: int
    reps: Optional[int] = None
    weight_kg: Optional[float] = None
    rpe: Optional[float] = None
    notes: Optional[str] = None
    set_kind: str = "working"


class HistorySessionItem(BaseModel):
    session_id: int
    started_at: datetime
    completed_at: Optional[datetime] = None
    sets: list[HistorySetItem] = Field(default_factory=list)


class ExerciseStatsResponse(BaseModel):
    exercise_id: int
    period_days: int
    period_label: str
    axis: list[str] = Field(default_factory=list)
    max_weight: MetricSeries
    total_volume: MetricSeries
    max_reps: MetricSeries
    total_reps: MetricSeries
    records: PersonalRecords
    history: list[HistorySessionItem] = Field(default_factory=list)


class StatsMuscleVolume(BaseModel):
    name: str
    volume: float
    hard_sets: int


class StatsRecentPr(BaseModel):
    exercise_id: int
    name: str
    kind: str
    value: float
    at: datetime


class StatsTopExercise(BaseModel):
    exercise_id: int
    name: str
    sessions: int
    volume: float
    estimated_1rm_kg: Optional[float] = None


class StatsOverviewResponse(BaseModel):
    period_days: int
    period_label: str
    sessions_count: int
    total_volume_kg: float
    total_duration_seconds: int
    avg_rpe: Optional[float] = None
    hard_sets: int
    trained_days: list[str] = Field(default_factory=list)
    by_muscle: list[StatsMuscleVolume] = Field(default_factory=list)
    recent_prs: list[StatsRecentPr] = Field(default_factory=list)
    top_exercises: list[StatsTopExercise] = Field(default_factory=list)


class VolumeLandmarkItem(BaseModel):
    name: str
    hard_sets: int
    zone: str  # below_mev / mev / mav / above_mrv
    mv: int
    mev: int
    mav_low: int
    mav_high: int
    mrv: int
    is_default: bool = False


class VolumeLandmarksResponse(BaseModel):
    week_start: str
    week_volume: float = 0
    hard_sets: int = 0
    items: list[VolumeLandmarkItem] = Field(default_factory=list)


class RelativeStrengthItem(BaseModel):
    exercise_id: int
    name: str
    name_en: Optional[str] = None
    estimated_1rm_kg: float
    ratio: Optional[float] = None  # e1RM / 体重；无体重时为 null
    is_big_three: bool = False
    lift: Optional[str] = None  # squat / bench / deadlift


class BigThreeLift(BaseModel):
    exercise_id: Optional[int] = None
    estimated_1rm_kg: Optional[float] = None
    ratio: Optional[float] = None


class BigThreeBlock(BaseModel):
    squat: BigThreeLift = Field(default_factory=BigThreeLift)
    bench: BigThreeLift = Field(default_factory=BigThreeLift)
    deadlift: BigThreeLift = Field(default_factory=BigThreeLift)
    total_kg: Optional[float] = None  # 三项齐全才有值
    complete: bool = False
    missing: list[str] = Field(default_factory=list)


class PushPullBlock(BaseModel):
    window_days: int = 28
    push_volume_kg: float = 0
    pull_volume_kg: float = 0
    push_hard_sets: int = 0
    pull_hard_sets: int = 0
    ratio: Optional[float] = None  # 推容量 / 拉容量
    verdict: str = "unknown"  # unknown / balanced / push_dominant / pull_dominant


class StrengthStandardsResponse(BaseModel):
    has_profile: bool = False
    gender: Optional[str] = None
    bodyweight_kg: Optional[float] = None
    relative_strength: list[RelativeStrengthItem] = Field(default_factory=list)
    big_three: BigThreeBlock = Field(default_factory=BigThreeBlock)
    dots: Optional[float] = None
    wilks: Optional[float] = None
    push_pull: PushPullBlock = Field(default_factory=PushPullBlock)
