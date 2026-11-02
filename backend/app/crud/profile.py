"""User fitness profile CRUD"""

import json
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.profile import UserFitnessProfile, WeightLog
from app.schemas.profile import ProfileUpsert


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _dump_tags(tags: list[str]) -> Optional[str]:
    cleaned = [t for t in tags if t and t != "none"]
    return json.dumps(cleaned, ensure_ascii=False) if cleaned else None


def parse_tags(raw: Optional[str]) -> list[str]:
    if not raw:
        return []
    try:
        data = json.loads(raw)
        if isinstance(data, list):
            return [str(x) for x in data]
    except json.JSONDecodeError:
        return [x for x in raw.split(",") if x]
    return []


class ProfileCRUD:
    @staticmethod
    async def get_by_user(
        db: AsyncSession, user_id: int
    ) -> Optional[UserFitnessProfile]:
        result = await db.execute(
            select(UserFitnessProfile).where(UserFitnessProfile.user_id == user_id)
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def upsert(
        db: AsyncSession, user_id: int, data: ProfileUpsert
    ) -> UserFitnessProfile:
        existing = await ProfileCRUD.get_by_user(db, user_id)
        now = _now()
        weight_changed = existing is None or existing.weight_kg != data.weight_kg

        if existing is None:
            existing = UserFitnessProfile(
                user_id=user_id,
                gender=data.gender,
                birth_year=data.birth_year,
                height_cm=data.height_cm,
                weight_kg=data.weight_kg,
                goal=data.goal,
                experience=data.experience,
                injury_tags=_dump_tags(data.injury_tags),
                weekly_days=data.weekly_days,
                session_minutes=data.session_minutes,
                equipment=data.equipment,
                preferences=_dump_tags(data.preferences),
                created_at=now,
                updated_at=now,
            )
            db.add(existing)
        else:
            existing.gender = data.gender
            existing.birth_year = data.birth_year
            existing.height_cm = data.height_cm
            existing.weight_kg = data.weight_kg
            existing.goal = data.goal
            existing.experience = data.experience
            existing.injury_tags = _dump_tags(data.injury_tags)
            existing.weekly_days = data.weekly_days
            existing.session_minutes = data.session_minutes
            existing.equipment = data.equipment
            existing.preferences = _dump_tags(data.preferences)
            existing.updated_at = now

        if weight_changed:
            db.add(
                WeightLog(user_id=user_id, weight_kg=data.weight_kg, recorded_at=now)
            )

        await db.commit()
        await db.refresh(existing)
        return existing


class WeightLogCRUD:
    @staticmethod
    async def list_since(
        db: AsyncSession, user_id: int, since: Optional[datetime] = None
    ) -> list[WeightLog]:
        stmt = select(WeightLog).where(WeightLog.user_id == user_id)
        if since is not None:
            stmt = stmt.where(WeightLog.recorded_at >= since)
        result = await db.execute(stmt.order_by(WeightLog.recorded_at, WeightLog.id))
        return list(result.scalars().all())


profile_crud = ProfileCRUD()
weight_log_crud = WeightLogCRUD()
