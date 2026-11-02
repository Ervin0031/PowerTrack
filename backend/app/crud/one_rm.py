"""估算 1RM 的读写。"""

import json
from collections import defaultdict
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup
from app.models.one_rm import UserExercise1RM
from app.models.workout import WorkoutSession, WorkoutSet
from app.schemas.workout import WorkoutSetCreate
from app.services.strength import (
    SAMPLE_STORE_MAX,
    BlendResult,
    EstimateSample,
    blend_estimates,
    counts_as_load,
    estimate_1rm,
)


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _parse_samples(raw: Optional[str]) -> list[EstimateSample]:
    if not raw:
        return []
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, TypeError, ValueError):
        return []
    if not isinstance(data, list):
        return []
    out: list[EstimateSample] = []
    for item in data:
        if isinstance(item, (int, float)):
            out.append(EstimateSample(kg=float(item), calculated_at=None))
            continue
        if not isinstance(item, dict):
            continue
        kg = item.get("kg")
        if not isinstance(kg, (int, float)):
            continue
        at = item.get("at")
        parsed_at: Optional[datetime] = None
        if isinstance(at, str):
            try:
                parsed_at = datetime.fromisoformat(at)
                if parsed_at.tzinfo is not None:
                    parsed_at = parsed_at.replace(tzinfo=None)
            except ValueError:
                parsed_at = None
        out.append(EstimateSample(kg=float(kg), calculated_at=parsed_at))
    return out


def _dump_samples(samples: list[EstimateSample]) -> str:
    payload = []
    for item in samples[-SAMPLE_STORE_MAX:]:
        row: dict = {"kg": round(item.kg, 1)}
        if item.calculated_at is not None:
            row["at"] = item.calculated_at.isoformat()
        payload.append(row)
    return json.dumps(payload)


def blend_stored_samples(
    raw: Optional[str], now: Optional[datetime] = None
) -> BlendResult:
    return blend_estimates(_parse_samples(raw), now=now or _now())


class OneRmCRUD:
    @staticmethod
    async def get(
        db: AsyncSession, user_id: int, exercise_id: int
    ) -> Optional[UserExercise1RM]:
        result = await db.execute(
            select(UserExercise1RM).where(
                UserExercise1RM.user_id == user_id,
                UserExercise1RM.exercise_id == exercise_id,
            )
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def list_estimated_map(db: AsyncSession, user_id: int) -> dict[int, float]:
        result = await db.execute(
            select(UserExercise1RM.exercise_id, UserExercise1RM.estimated_kg).where(
                UserExercise1RM.user_id == user_id
            )
        )
        return {
            int(exercise_id): float(kg)
            for exercise_id, kg in result.all()
            if kg is not None
        }

    @staticmethod
    async def list_entries_with_names(db: AsyncSession, user_id: int) -> list[tuple]:
        """(exercise_id, name, name_en, estimated_kg)；动作被删则整行消失。"""
        result = await db.execute(
            select(
                UserExercise1RM.exercise_id,
                Exercise.name,
                Exercise.name_en,
                UserExercise1RM.estimated_kg,
            )
            .join(Exercise, UserExercise1RM.exercise_id == Exercise.id)
            .where(UserExercise1RM.user_id == user_id)
        )
        return list(result.all())

    @staticmethod
    async def apply_session_sets(
        db: AsyncSession, user_id: int, sets: list[WorkoutSetCreate]
    ) -> None:
        by_ex: dict[int, list[float]] = defaultdict(list)
        for item in sets:
            if not counts_as_load(item.set_kind):
                continue
            est = estimate_1rm(item.weight_kg, item.reps, item.rpe)
            if est is not None:
                by_ex[item.exercise_id].append(round(est, 1))
        if not by_ex:
            return

        now = _now()
        for exercise_id, fresh in by_ex.items():
            row = await OneRmCRUD.get(db, user_id, exercise_id)
            samples = _parse_samples(row.samples if row else None)
            samples.extend(EstimateSample(kg=kg, calculated_at=now) for kg in fresh)
            samples = samples[-SAMPLE_STORE_MAX:]
            blended = blend_estimates(samples, now=now)
            if blended.estimated_kg is None:
                continue
            dumped = _dump_samples(samples)
            if row is None:
                db.add(
                    UserExercise1RM(
                        user_id=user_id,
                        exercise_id=exercise_id,
                        estimated_kg=round(blended.estimated_kg, 1),
                        samples=dumped,
                        updated_at=now,
                    )
                )
            else:
                row.estimated_kg = round(blended.estimated_kg, 1)
                row.samples = dumped
                row.updated_at = now
                db.add(row)

    @staticmethod
    async def list_completed_set_loads(
        db: AsyncSession, user_id: int, since
    ) -> list[tuple]:
        result = await db.execute(
            select(
                WorkoutSession.started_at,
                WorkoutSet.reps,
                WorkoutSet.weight_kg,
                WorkoutSet.rpe,
                MuscleGroup.name,
            )
            .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
            .join(Exercise, WorkoutSet.exercise_id == Exercise.id)
            .join(MuscleGroup, Exercise.primary_muscle_group_id == MuscleGroup.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == "completed",
                WorkoutSession.started_at >= since,
                or_(
                    WorkoutSet.set_kind.in_(("working", "drop")),
                    WorkoutSet.set_kind.is_(None),
                ),
            )
        )
        return list(result.all())


one_rm_crud = OneRmCRUD()
