"""当前训练块的读写，以及按块里今天的动作算下次课处方。"""

from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise
from app.models.program import TrainingBlock, TrainingBlockDay
from app.models.template import WorkoutTemplate, WorkoutTemplateExercise
from app.models.workout import WorkoutSession, WorkoutSet
from app.schemas.program import ProgramWrite
from app.services.prescription import Exposure, Prescription, block_week, prescribe
from app.services.strength import RecoverySet, counts_as_load, session_estimated_1rm

_SESSION_LIMIT = 6


def _today() -> date:
    # 和每周容量同一套 UTC 日期。
    return datetime.now(timezone.utc).date()


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def prescription_dict(exercise_id: int, name: str, item: Prescription) -> dict:
    return {
        "exercise_id": exercise_id,
        "exercise_name": name,
        "action": item.action,
        "stalled": item.stalled,
        "weight_kg": item.weight_kg,
        "sets": item.sets,
        "reason": item.reason,
        "summary": item.summary,
    }


async def program_view(
    db: AsyncSession, user_id: int, today: Optional[date] = None
) -> dict:
    today = today or _today()
    block = await _block(db, user_id)
    if block is None:
        return {
            "active": False,
            "id": None,
            "title": "",
            "week_count": 4,
            "deload_week": 4,
            "current_week": 1,
            "is_deload": False,
            "started_on": None,
            "today_weekday": today.weekday(),
            "days": [],
        }
    current = block_week(block.started_on, today, block.week_count)
    is_deload = current == block.deload_week
    rows = (
        await db.execute(
            select(TrainingBlockDay, WorkoutTemplate.title)
            .join(WorkoutTemplate, WorkoutTemplate.id == TrainingBlockDay.template_id)
            .where(TrainingBlockDay.block_id == block.id)
            .order_by(TrainingBlockDay.weekday, TrainingBlockDay.sort_order)
        )
    ).all()
    days = []
    for day, title in rows:
        is_today = day.weekday == today.weekday()
        prescriptions = []
        if is_today:
            prescriptions = await prescriptions_for_template(
                db, user_id, day.template_id, deload=is_deload
            )
        days.append(
            {
                "weekday": day.weekday,
                "template_id": day.template_id,
                "template_title": title,
                "is_today": is_today,
                "prescriptions": prescriptions,
            }
        )
    return {
        "active": True,
        "id": block.id,
        "title": block.title,
        "week_count": block.week_count,
        "deload_week": block.deload_week,
        "current_week": current,
        "is_deload": is_deload,
        "started_on": block.started_on.isoformat(),
        "today_weekday": today.weekday(),
        "days": days,
    }


async def exercise_prescription(
    db: AsyncSession, user_id: int, exercise_id: int
) -> dict:
    exercise = await db.get(Exercise, exercise_id)
    if exercise is None:
        raise HTTPException(404, "动作不存在")
    view = await program_view(db, user_id)
    exposures = await recent_exposures(db, user_id, exercise_id)
    item = prescribe(exposures, deload=bool(view.get("is_deload")))
    return prescription_dict(exercise.id, exercise.name, item)


async def save_block(db: AsyncSession, user_id: int, payload: ProgramWrite) -> dict:
    await _ensure_templates(db, user_id, [day.template_id for day in payload.days])
    block = await _block(db, user_id)
    if block is None:
        block = TrainingBlock(
            user_id=user_id,
            title=payload.title.strip(),
            week_count=payload.week_count,
            deload_week=payload.deload_week,
            started_on=payload.started_on,
        )
        db.add(block)
        await db.flush()
    else:
        block.title = payload.title.strip()
        block.week_count = payload.week_count
        block.deload_week = payload.deload_week
        block.started_on = payload.started_on
        block.updated_at = _now()
        await db.execute(
            delete(TrainingBlockDay).where(TrainingBlockDay.block_id == block.id)
        )
    for index, day in enumerate(payload.days):
        db.add(
            TrainingBlockDay(
                block_id=block.id,
                weekday=day.weekday,
                template_id=day.template_id,
                sort_order=index,
            )
        )
    await db.commit()
    return await program_view(db, user_id)


async def patch_block(db: AsyncSession, user_id: int, patch: dict) -> dict:
    """教练改周期。没给的字段保持原样；还没有块时必须带上 days。"""
    current = await program_view(db, user_id)
    days = patch.get("days")
    if not current["active"]:
        if not isinstance(days, list) or not days:
            raise HTTPException(400, "还没有周期。先给出每天用哪个模板")
        started = patch.get("started_on") or _today().isoformat()
        payload = ProgramWrite.model_validate(
            {
                "title": patch.get("title") or "当前周期",
                "week_count": patch.get("week_count") or 4,
                "deload_week": patch.get("deload_week") or patch.get("week_count") or 4,
                "started_on": started,
                "days": days,
            }
        )
        return await save_block(db, user_id, payload)

    merged_days = (
        days
        if isinstance(days, list) and days
        else [
            {"weekday": day["weekday"], "template_id": day["template_id"]}
            for day in current["days"]
        ]
    )
    payload = ProgramWrite.model_validate(
        {
            "title": patch.get("title") or current["title"],
            "week_count": patch.get("week_count") or current["week_count"],
            "deload_week": patch.get("deload_week") or current["deload_week"],
            "started_on": patch.get("started_on") or current["started_on"],
            "days": merged_days,
        }
    )
    return await save_block(db, user_id, payload)


async def delete_block(db: AsyncSession, user_id: int) -> None:
    block = await _block(db, user_id)
    if block is None:
        return
    await db.execute(
        delete(TrainingBlockDay).where(TrainingBlockDay.block_id == block.id)
    )
    await db.delete(block)
    await db.commit()


async def prescriptions_for_template(
    db: AsyncSession,
    user_id: int,
    template_id: int,
    *,
    deload: bool,
) -> list[dict]:
    rows = (
        await db.execute(
            select(WorkoutTemplateExercise.exercise_id, Exercise.name)
            .join(Exercise, Exercise.id == WorkoutTemplateExercise.exercise_id)
            .where(WorkoutTemplateExercise.template_id == template_id)
            .order_by(WorkoutTemplateExercise.sort_order, WorkoutTemplateExercise.id)
        )
    ).all()
    items = []
    seen: set[int] = set()
    for exercise_id, name in rows:
        if exercise_id in seen:
            continue
        seen.add(exercise_id)
        exposures = await recent_exposures(db, user_id, exercise_id)
        item = prescribe(exposures, deload=deload)
        items.append(prescription_dict(exercise_id, name, item))
    return items


async def recent_exposures(
    db: AsyncSession, user_id: int, exercise_id: int
) -> list[Exposure]:
    rows = (
        await db.execute(
            select(WorkoutSet, WorkoutSession.id)
            .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == "completed",
                WorkoutSet.exercise_id == exercise_id,
            )
            .order_by(WorkoutSession.completed_at.desc(), WorkoutSet.set_number)
        )
    ).all()
    grouped: dict[int, list[WorkoutSet]] = defaultdict(list)
    order: list[int] = []
    for workout_set, session_id in rows:
        if session_id not in grouped:
            order.append(session_id)
        grouped[session_id].append(workout_set)
    order = order[:_SESSION_LIMIT]
    exposures: list[Exposure] = []
    for session_id in reversed(order):
        load = [
            item
            for item in grouped[session_id]
            if counts_as_load(item.set_kind)
            and item.weight_kg is not None
            and item.weight_kg > 0
        ]
        if not load:
            continue
        top = max(load, key=lambda item: (item.weight_kg or 0, item.reps or 0))
        e1rm = session_estimated_1rm(
            [
                RecoverySet(rpe=item.rpe, weight_kg=item.weight_kg, reps=item.reps)
                for item in load
            ]
        )
        exposures.append(
            Exposure(
                top_weight_kg=float(top.weight_kg or 0),
                top_reps=int(top.reps or 0),
                top_rpe=top.rpe,
                e1rm_kg=e1rm,
                working_sets=len(load),
            )
        )
    return exposures


async def _block(db: AsyncSession, user_id: int) -> Optional[TrainingBlock]:
    return await db.scalar(
        select(TrainingBlock).where(TrainingBlock.user_id == user_id)
    )


async def _ensure_templates(
    db: AsyncSession, user_id: int, template_ids: list[int]
) -> None:
    if not template_ids:
        raise HTTPException(400, "至少排一天")
    rows = (
        (
            await db.execute(
                select(WorkoutTemplate).where(WorkoutTemplate.id.in_(template_ids))
            )
        )
        .scalars()
        .all()
    )
    found = {item.id: item for item in rows}
    for template_id in template_ids:
        template = found.get(template_id)
        if template is None or not (template.user_id == user_id or template.is_public):
            raise HTTPException(400, "模板不存在或不可用")
