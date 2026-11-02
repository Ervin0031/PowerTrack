"""Coach conversation. The model never writes workouts; messages store the proposal."""

from datetime import datetime, timezone
from typing import Optional

from pydantic import NaiveDatetime
from sqlalchemy import Column, Text
from sqlmodel import Field, SQLModel


def _now_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class CoachThread(SQLModel, table=True):
    """One task-style chat. P0 is today's session."""

    __tablename__ = "coach_threads"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)
    created_at: NaiveDatetime = Field(default_factory=_now_naive)
    updated_at: NaiveDatetime = Field(default_factory=_now_naive)


class CoachMessage(SQLModel, table=True):
    """User or assistant turn. Tool calls stay in memory for that request."""

    __tablename__ = "coach_messages"

    id: Optional[int] = Field(default=None, primary_key=True)
    thread_id: int = Field(foreign_key="coach_threads.id", index=True)
    role: str = Field(max_length=16, description="user / assistant")
    content: str = Field(sa_column=Column(Text, nullable=False))
    proposal_json: Optional[str] = Field(default=None, sa_column=Column(Text))
    trace_json: Optional[str] = Field(default=None, sa_column=Column(Text))
    created_at: NaiveDatetime = Field(default_factory=_now_naive)
