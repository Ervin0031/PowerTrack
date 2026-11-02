"""每位用户每个肌群一行恢复系数；muscle_group_id=0 表示全局。"""

from datetime import datetime, timezone
from typing import Optional

from pydantic import NaiveDatetime
from sqlmodel import Field, SQLModel


def _now_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


GLOBAL_MUSCLE_GROUP_ID = 0


class UserRecoveryFactor(SQLModel, table=True):
    """个体化恢复系数：观察样本 JSON + 上次有效刺激。"""

    __tablename__ = "user_recovery_factors"

    user_id: int = Field(foreign_key="users.id", primary_key=True)
    # 0 = 全局系数；不加 FK，以便哨兵行与真实肌群共存。
    muscle_group_id: int = Field(primary_key=True)
    factor: float = Field(default=1.0)
    observations: Optional[str] = Field(default=None, description="JSON 数组，高频观察")
    last_effective_at: Optional[NaiveDatetime] = Field(default=None)
    last_effective_1rm: Optional[float] = Field(default=None)
    updated_at: NaiveDatetime = Field(default_factory=_now_naive)
