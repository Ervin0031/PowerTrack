"""Coach request and session proposal. Proposal is not persisted as a workout."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

SET_KINDS = ("warmup", "working", "drop", "cooldown")


class CoachMessageCreate(BaseModel):
    content: Optional[str] = Field(default=None, max_length=500)


class CurrentExercise(BaseModel):
    exercise_id: int
    name: str = ""
    sets_done: int = Field(default=0, ge=0, le=20)
    sets_planned: int = Field(default=0, ge=0, le=20)
    last_weight_kg: Optional[float] = None
    last_reps: Optional[int] = None
    last_rpe: Optional[float] = None


class NextExerciseRequest(BaseModel):
    exercises: list[CurrentExercise] = Field(default_factory=list, max_length=12)


class ThreadCreated(BaseModel):
    id: int


class ThreadSummary(BaseModel):
    id: int
    title: str
    updated_at: datetime


class StoredCoachMessage(BaseModel):
    role: str
    content: str
    proposal: Optional[dict] = None
    trace: Optional[list] = None


class ThreadDetail(BaseModel):
    id: int
    title: str
    messages: list[StoredCoachMessage]


class ProposedSet(BaseModel):
    set_number: int = Field(..., ge=1, le=12)
    set_kind: str = "working"
    reps: Optional[int] = Field(default=None, ge=1, le=30)
    weight_kg: Optional[float] = Field(default=None, ge=0, le=500)


class ProposedExercise(BaseModel):
    exercise_id: int
    name: str = ""
    exercise_type: str = "compound"
    image_url: Optional[str] = Field(default=None, max_length=500)
    notes: Optional[str] = None
    rest_target_seconds: Optional[int] = Field(default=None, ge=0, le=600)
    sets: list[ProposedSet] = Field(min_length=1, max_length=8)


class SessionProposal(BaseModel):
    title: str = Field(..., min_length=1, max_length=40)
    summary: str = Field(..., min_length=1, max_length=280)
    estimated_minutes: int = Field(..., ge=15, le=180)
    exercises: list[ProposedExercise] = Field(min_length=1, max_length=8)


class CoachTraceStep(BaseModel):
    kind: str = Field(default="tool", max_length=16)
    title: str = Field(default="", max_length=120)
    detail: str = Field(default="", max_length=500)
    state: str = Field(default="done", pattern="^(running|done)$")


class CoachTurnImport(BaseModel):
    """客户端 Agent 已生成的一轮对话，仅用于落库，不触发推理。"""

    user_content: str = Field(..., min_length=1, max_length=500)
    assistant_content: str = Field(..., min_length=1, max_length=20_000)
    proposal: Optional[SessionProposal] = None
    trace: list[CoachTraceStep] = Field(default_factory=list, max_length=64)
