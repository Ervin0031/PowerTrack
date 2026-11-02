"""用户恢复系数读写，在完成会话的同一事务里更新。"""

from __future__ import annotations

import json
from collections import defaultdict
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup
from app.models.recovery import GLOBAL_MUSCLE_GROUP_ID, UserRecoveryFactor
from app.models.workout import WorkoutSession, WorkoutSet
from app.schemas.workout import WorkoutSetCreate
from app.services.strength import (
    MIN_GLOBAL_OBSERVATIONS,
    MIN_MUSCLE_OBSERVATIONS,
    OBSERVATION_STORE_MAX,
    RecoveryObservation,
    RecoverySet,
    baseline_window_hours,
    compute_muscle_group_status,
    compute_recovery_factor,
    counts_as_load,
    is_effective_session,
    performance_change,
    recovery_confidence,
    recovery_delta,
    session_estimated_1rm,
)


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _naive(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def _parse_observations(raw: Optional[str]) -> list[RecoveryObservation]:
    if not raw:
        return []
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, TypeError, ValueError):
        return []
    if not isinstance(data, list):
        return []
    out: list[RecoveryObservation] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        at_raw = item.get("at")
        if not isinstance(at_raw, str):
            continue
        try:
            at = datetime.fromisoformat(at_raw)
        except ValueError:
            continue
        try:
            interval = float(item.get("interval_hours"))
            baseline = float(item.get("baseline_hours"))
            change = float(item.get("performance_change"))
            delta = float(item.get("delta"))
        except (TypeError, ValueError):
            continue
        out.append(
            RecoveryObservation(
                at=_naive(at) or at,
                interval_hours=interval,
                baseline_hours=baseline,
                performance_change=change,
                delta=delta,
            )
        )
    return out


def _dump_observations(observations: list[RecoveryObservation]) -> str:
    payload = []
    for obs in observations[-OBSERVATION_STORE_MAX:]:
        payload.append(
            {
                "at": _naive(obs.at).isoformat() if obs.at else None,
                "interval_hours": round(obs.interval_hours, 2),
                "baseline_hours": round(obs.baseline_hours, 2),
                "performance_change": round(obs.performance_change, 4),
                "delta": round(obs.delta, 4),
            }
        )
    return json.dumps(payload)


def _as_recovery_sets(rows: list) -> list[RecoverySet]:
    out: list[RecoverySet] = []
    for row in rows:
        rpe = getattr(row, "rpe", None)
        weight = getattr(row, "weight_kg", None)
        reps = getattr(row, "reps", None)
        if isinstance(row, dict):
            rpe = row.get("rpe")
            weight = row.get("weight_kg")
            reps = row.get("reps")
        out.append(RecoverySet(rpe=rpe, weight_kg=weight, reps=reps))
    return out


class RecoveryCRUD:
    @staticmethod
    async def get(
        db: AsyncSession, user_id: int, muscle_group_id: int
    ) -> Optional[UserRecoveryFactor]:
        result = await db.execute(
            select(UserRecoveryFactor).where(
                UserRecoveryFactor.user_id == user_id,
                UserRecoveryFactor.muscle_group_id == muscle_group_id,
            )
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def get_or_create(
        db: AsyncSession, user_id: int, muscle_group_id: int
    ) -> UserRecoveryFactor:
        row = await RecoveryCRUD.get(db, user_id, muscle_group_id)
        if row is not None:
            return row
        row = UserRecoveryFactor(
            user_id=user_id,
            muscle_group_id=muscle_group_id,
            factor=1.0,
        )
        db.add(row)
        await db.flush()
        return row

    @staticmethod
    async def list_for_user(db: AsyncSession, user_id: int) -> list[UserRecoveryFactor]:
        result = await db.execute(
            select(UserRecoveryFactor).where(UserRecoveryFactor.user_id == user_id)
        )
        return list(result.scalars().all())

    @staticmethod
    async def apply_completed_session(
        db: AsyncSession,
        user_id: int,
        completed_at: datetime,
        sets: list[WorkoutSetCreate],
    ) -> None:
        """对本次涉及的每个肌群判断有效刺激，并在高频时写入观察。不 commit。"""
        sets = [item for item in sets if counts_as_load(item.set_kind)]
        if not sets:
            return
        clock = _naive(completed_at) or _now()
        exercise_ids = {item.exercise_id for item in sets}
        result = await db.execute(
            select(Exercise, MuscleGroup)
            .join(MuscleGroup, Exercise.primary_muscle_group_id == MuscleGroup.id)
            .where(Exercise.id.in_(exercise_ids))
        )
        meta: dict[int, tuple[int, str, str]] = {}
        for exercise, muscle in result.all():
            meta[exercise.id] = (muscle.id, muscle.name, muscle.name_en)

        by_muscle: dict[int, list[WorkoutSetCreate]] = defaultdict(list)
        names: dict[int, tuple[str, str]] = {}
        for item in sets:
            info = meta.get(item.exercise_id)
            if info is None:
                continue
            mg_id, name, name_en = info
            by_muscle[mg_id].append(item)
            names[mg_id] = (name, name_en)
        if not by_muscle:
            return

        global_row = await RecoveryCRUD.get_or_create(
            db, user_id, GLOBAL_MUSCLE_GROUP_ID
        )
        global_obs = _parse_observations(global_row.observations)
        now = _now()
        global_changed = False

        for mg_id, mg_sets in by_muscle.items():
            recovery_sets = _as_recovery_sets(mg_sets)
            if not is_effective_session(recovery_sets):
                continue
            est = session_estimated_1rm(recovery_sets)
            row = await RecoveryCRUD.get_or_create(db, user_id, mg_id)
            name, name_en = names[mg_id]
            baseline = baseline_window_hours(name, name_en)
            last_at = _naive(row.last_effective_at)
            if (
                last_at is not None
                and est is not None
                and row.last_effective_1rm is not None
            ):
                interval_h = (clock - last_at).total_seconds() / 3600.0
                change = performance_change(est, row.last_effective_1rm)
                if change is not None and interval_h < baseline:
                    delta = recovery_delta(interval_h, baseline, change)
                    obs = RecoveryObservation(
                        at=clock,
                        interval_hours=interval_h,
                        baseline_hours=baseline,
                        performance_change=change,
                        delta=delta,
                    )
                    muscle_obs = _parse_observations(row.observations)
                    muscle_obs.append(obs)
                    muscle_obs = muscle_obs[-OBSERVATION_STORE_MAX:]
                    factor, _count = compute_recovery_factor(
                        muscle_obs, now, MIN_MUSCLE_OBSERVATIONS
                    )
                    row.observations = _dump_observations(muscle_obs)
                    row.factor = factor
                    global_obs.append(obs)
                    global_changed = True

            row.last_effective_at = clock
            if est is not None:
                row.last_effective_1rm = round(est, 1)
            row.updated_at = now
            db.add(row)

        if global_changed:
            global_obs = global_obs[-OBSERVATION_STORE_MAX:]
            g_factor, _g_count = compute_recovery_factor(
                global_obs, now, MIN_GLOBAL_OBSERVATIONS
            )
            global_row.observations = _dump_observations(global_obs)
            global_row.factor = g_factor
            global_row.updated_at = now
            db.add(global_row)

    @staticmethod
    async def list_last_trained(db: AsyncSession, user_id: int) -> list[tuple]:
        """每位用户练过的肌群及其最近一次完成时间。"""
        stmt = (
            select(
                MuscleGroup.id,
                MuscleGroup.name,
                MuscleGroup.name_en,
                MuscleGroup.category,
                func.max(WorkoutSession.completed_at),
            )
            .join(Exercise, Exercise.primary_muscle_group_id == MuscleGroup.id)
            .join(WorkoutSet, WorkoutSet.exercise_id == Exercise.id)
            .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == "completed",
                WorkoutSession.completed_at.isnot(None),
            )
            .group_by(
                MuscleGroup.id,
                MuscleGroup.name,
                MuscleGroup.name_en,
                MuscleGroup.category,
            )
        )
        result = await db.execute(stmt)
        return list(result.all())

    @staticmethod
    async def list_status(
        db: AsyncSession, user_id: int, now: Optional[datetime] = None
    ):
        clock = _naive(now) or _now()
        trained = await RecoveryCRUD.list_last_trained(db, user_id)
        rows = await RecoveryCRUD.list_for_user(db, user_id)
        by_id = {row.muscle_group_id: row for row in rows}
        global_row = by_id.get(GLOBAL_MUSCLE_GROUP_ID)
        global_obs = _parse_observations(
            global_row.observations if global_row else None
        )
        global_factor, global_count = compute_recovery_factor(
            global_obs, clock, MIN_GLOBAL_OBSERVATIONS
        )
        items = []
        for mg_id, name, name_en, category, last_at in trained:
            if last_at is None:
                continue
            muscle_row = by_id.get(mg_id)
            muscle_obs = _parse_observations(
                muscle_row.observations if muscle_row else None
            )
            items.append(
                compute_muscle_group_status(
                    muscle_group_id=mg_id,
                    name=name,
                    name_en=name_en,
                    category=category,
                    last_trained_at=last_at,
                    now=clock,
                    muscle_observations=muscle_obs,
                    global_observations=global_obs,
                )
            )
        items.sort(key=lambda s: (s.recovery_progress, s.name))
        return {
            "items": items,
            "global_factor": round(global_factor, 4),
            "global_observations_count": global_count,
            "global_confidence": recovery_confidence(global_count),
        }


recovery_crud = RecoveryCRUD()
