"""Workout template CRUD"""

from collections import defaultdict
from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import delete, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import (
    Equipment,
    Exercise,
    ExerciseSecondaryMuscle,
    MuscleGroup,
)
from app.models.template import (
    WorkoutTemplate,
    WorkoutTemplateExercise,
    WorkoutTemplateSet,
)
from app.models.user import User
from app.models.workout import WorkoutSession, WorkoutSet
from app.schemas.template import (
    DIFFICULTIES,
    TemplateDetailResponse,
    TemplateEquipmentHit,
    TemplateExercisePayload,
    TemplateExerciseResponse,
    TemplateListItem,
    TemplateMuscleHit,
    TemplateSetResponse,
    TemplateWrite,
)
from app.services.storage import storage_service


def _now_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _validate_difficulty(value: str) -> str:
    if value not in DIFFICULTIES:
        raise HTTPException(400, "difficulty must be easy, moderate, or hard")
    return value


class TemplateCRUD:
    @staticmethod
    async def get_by_id(
        db: AsyncSession, template_id: int
    ) -> Optional[WorkoutTemplate]:
        return await db.get(WorkoutTemplate, template_id)

    @staticmethod
    async def get_all(
        db: AsyncSession,
        user_id: int,
        skip: int = 0,
        limit: int = 20,
        search: Optional[str] = None,
        difficulty: Optional[str] = None,
        muscle_group_id: Optional[int] = None,
        equipment_id: Optional[int] = None,
        is_public: Optional[bool] = None,
        scope: str = "all",
    ) -> tuple[list[WorkoutTemplate], int]:
        visible = or_(
            WorkoutTemplate.user_id == user_id,
            WorkoutTemplate.is_public.is_(True),
        )
        base = select(WorkoutTemplate).where(visible)
        count_base = select(WorkoutTemplate).where(visible)

        if scope == "mine":
            base = base.where(WorkoutTemplate.user_id == user_id)
            count_base = count_base.where(WorkoutTemplate.user_id == user_id)
        elif scope == "public":
            base = base.where(WorkoutTemplate.is_public.is_(True))
            count_base = count_base.where(WorkoutTemplate.is_public.is_(True))

        if search:
            like = f"%{search}%"
            base = base.where(
                or_(
                    WorkoutTemplate.title.ilike(like),
                    WorkoutTemplate.description.ilike(like),
                )
            )
            count_base = count_base.where(
                or_(
                    WorkoutTemplate.title.ilike(like),
                    WorkoutTemplate.description.ilike(like),
                )
            )
        if difficulty:
            _validate_difficulty(difficulty)
            base = base.where(WorkoutTemplate.difficulty == difficulty)
            count_base = count_base.where(WorkoutTemplate.difficulty == difficulty)
        if is_public is not None:
            base = base.where(WorkoutTemplate.is_public == is_public)
            count_base = count_base.where(WorkoutTemplate.is_public == is_public)

        if muscle_group_id or equipment_id:
            ex_ids = select(WorkoutTemplateExercise.template_id).join(
                Exercise, Exercise.id == WorkoutTemplateExercise.exercise_id
            )
            if muscle_group_id:
                secondary = select(ExerciseSecondaryMuscle.exercise_id).where(
                    ExerciseSecondaryMuscle.muscle_group_id == muscle_group_id
                )
                ex_ids = ex_ids.where(
                    or_(
                        Exercise.primary_muscle_group_id == muscle_group_id,
                        WorkoutTemplateExercise.exercise_id.in_(secondary),
                    )
                )
            if equipment_id:
                ex_ids = ex_ids.where(Exercise.equipment_id == equipment_id)
            matching = ex_ids.distinct()
            base = base.where(WorkoutTemplate.id.in_(matching))
            count_base = count_base.where(WorkoutTemplate.id.in_(matching))

        total = (
            await db.execute(select(func.count()).select_from(count_base.subquery()))
        ).scalar() or 0
        stmt = (
            base.order_by(WorkoutTemplate.updated_at.desc()).offset(skip).limit(limit)
        )
        result = await db.execute(stmt)
        return list(result.scalars().all()), total

    @staticmethod
    async def create(
        db: AsyncSession, user_id: int, data: TemplateWrite
    ) -> WorkoutTemplate:
        obj = WorkoutTemplate(
            user_id=user_id,
            title=data.title.strip(),
            description=data.description,
            difficulty=_validate_difficulty(data.difficulty),
            is_public=data.is_public,
        )
        db.add(obj)
        await db.flush()
        await TemplateCRUD._replace_exercises(db, obj.id, data.exercises)
        await db.commit()
        await db.refresh(obj)
        return obj

    @staticmethod
    async def update(
        db: AsyncSession, template: WorkoutTemplate, data: TemplateWrite
    ) -> WorkoutTemplate:
        template.title = data.title.strip()
        template.description = data.description
        template.difficulty = _validate_difficulty(data.difficulty)
        template.is_public = data.is_public
        template.updated_at = _now_naive()
        db.add(template)
        await TemplateCRUD._replace_exercises(db, template.id, data.exercises)
        await db.commit()
        await db.refresh(template)
        return template

    @staticmethod
    async def set_cover_key(
        db: AsyncSession, template: WorkoutTemplate, image_key: Optional[str]
    ) -> WorkoutTemplate:
        template.cover_image_key = image_key
        template.updated_at = _now_naive()
        db.add(template)
        await db.commit()
        await db.refresh(template)
        return template

    @staticmethod
    async def delete(db: AsyncSession, template: WorkoutTemplate) -> None:
        await db.execute(
            update(WorkoutSession)
            .where(WorkoutSession.template_id == template.id)
            .values(template_id=None)
        )
        slot_ids = (
            (
                await db.execute(
                    select(WorkoutTemplateExercise.id).where(
                        WorkoutTemplateExercise.template_id == template.id
                    )
                )
            )
            .scalars()
            .all()
        )
        if slot_ids:
            await db.execute(
                delete(WorkoutTemplateSet).where(
                    WorkoutTemplateSet.template_exercise_id.in_(slot_ids)
                )
            )
        await db.execute(
            delete(WorkoutTemplateExercise).where(
                WorkoutTemplateExercise.template_id == template.id
            )
        )
        await db.delete(template)
        await db.commit()

    @staticmethod
    async def _replace_exercises(
        db: AsyncSession, template_id: int, exercises: list[TemplateExercisePayload]
    ) -> None:
        existing_ids = (
            (
                await db.execute(
                    select(WorkoutTemplateExercise.id).where(
                        WorkoutTemplateExercise.template_id == template_id
                    )
                )
            )
            .scalars()
            .all()
        )
        if existing_ids:
            await db.execute(
                delete(WorkoutTemplateSet).where(
                    WorkoutTemplateSet.template_exercise_id.in_(existing_ids)
                )
            )
            await db.execute(
                delete(WorkoutTemplateExercise).where(
                    WorkoutTemplateExercise.template_id == template_id
                )
            )

        seen: set[int] = set()
        for index, item in enumerate(exercises):
            if item.exercise_id in seen:
                continue
            exercise = await db.get(Exercise, item.exercise_id)
            if exercise is None:
                raise HTTPException(400, f"exercise {item.exercise_id} not found")
            seen.add(item.exercise_id)
            slot = WorkoutTemplateExercise(
                template_id=template_id,
                exercise_id=item.exercise_id,
                sort_order=item.sort_order if item.sort_order else index,
                superset_id=item.superset_id,
                notes=item.notes,
                rest_target_seconds=item.rest_target_seconds,
                weight_unit=item.weight_unit or "kg",
            )
            db.add(slot)
            await db.flush()
            if not item.sets:
                db.add(
                    WorkoutTemplateSet(
                        template_exercise_id=slot.id,
                        set_number=1,
                        set_kind="working",
                    )
                )
                continue
            for set_index, planned in enumerate(item.sets):
                db.add(
                    WorkoutTemplateSet(
                        template_exercise_id=slot.id,
                        set_number=planned.set_number or set_index + 1,
                        reps=planned.reps,
                        weight_kg=planned.weight_kg,
                        duration_seconds=planned.duration_seconds,
                        distance_meters=planned.distance_meters,
                        notes=planned.notes,
                        set_kind=planned.set_kind or "working",
                    )
                )

    @staticmethod
    async def _completion_counts(
        db: AsyncSession, template_ids: list[int]
    ) -> dict[int, int]:
        if not template_ids:
            return {}
        stmt = (
            select(WorkoutSession.template_id, func.count())
            .where(WorkoutSession.template_id.in_(template_ids))
            .where(WorkoutSession.status == "completed")
            .group_by(WorkoutSession.template_id)
        )
        rows = (await db.execute(stmt)).all()
        return {tid: count for tid, count in rows if tid is not None}

    @staticmethod
    async def _slots_by_template(
        db: AsyncSession, template_ids: list[int]
    ) -> dict[int, list[WorkoutTemplateExercise]]:
        if not template_ids:
            return {}
        rows = (
            (
                await db.execute(
                    select(WorkoutTemplateExercise)
                    .where(WorkoutTemplateExercise.template_id.in_(template_ids))
                    .order_by(
                        WorkoutTemplateExercise.sort_order, WorkoutTemplateExercise.id
                    )
                )
            )
            .scalars()
            .all()
        )
        grouped: dict[int, list[WorkoutTemplateExercise]] = defaultdict(list)
        for slot in rows:
            grouped[slot.template_id].append(slot)
        return grouped

    @staticmethod
    async def _sets_by_slot(
        db: AsyncSession, slot_ids: list[int]
    ) -> dict[int, list[WorkoutTemplateSet]]:
        if not slot_ids:
            return {}
        rows = (
            (
                await db.execute(
                    select(WorkoutTemplateSet)
                    .where(WorkoutTemplateSet.template_exercise_id.in_(slot_ids))
                    .order_by(WorkoutTemplateSet.set_number, WorkoutTemplateSet.id)
                )
            )
            .scalars()
            .all()
        )
        grouped: dict[int, list[WorkoutTemplateSet]] = defaultdict(list)
        for item in rows:
            grouped[item.template_exercise_id].append(item)
        return grouped

    @staticmethod
    async def _usernames(db: AsyncSession, user_ids: list[int]) -> dict[int, str]:
        if not user_ids:
            return {}
        rows = (
            await db.execute(
                select(User.id, User.username).where(User.id.in_(user_ids))
            )
        ).all()
        return {uid: name for uid, name in rows}

    @staticmethod
    async def _hydrate_muscles_equipment(
        db: AsyncSession, slots: list[WorkoutTemplateExercise]
    ) -> tuple[
        list[TemplateMuscleHit], list[TemplateMuscleHit], list[TemplateEquipmentHit]
    ]:
        exercise_ids = [s.exercise_id for s in slots]
        if not exercise_ids:
            return [], [], []
        exercises = (
            (await db.execute(select(Exercise).where(Exercise.id.in_(exercise_ids))))
            .scalars()
            .all()
        )
        set_counts: dict[int, int] = defaultdict(int)
        slot_ids = [s.id for s in slots if s.id is not None]
        if slot_ids:
            rows = (
                await db.execute(
                    select(WorkoutTemplateSet.template_exercise_id, func.count())
                    .where(WorkoutTemplateSet.template_exercise_id.in_(slot_ids))
                    .group_by(WorkoutTemplateSet.template_exercise_id)
                )
            ).all()
            counts = {slot_id: count for slot_id, count in rows}
            for slot in slots:
                set_counts[slot.exercise_id] += counts.get(slot.id, 0) or 1

        primary: dict[int, TemplateMuscleHit] = {}
        secondary: dict[int, TemplateMuscleHit] = {}
        equipment: dict[int, TemplateEquipmentHit] = {}

        muscle_ids = {e.primary_muscle_group_id for e in exercises}
        secondary_rows = (
            (
                await db.execute(
                    select(ExerciseSecondaryMuscle).where(
                        ExerciseSecondaryMuscle.exercise_id.in_(exercise_ids)
                    )
                )
            )
            .scalars()
            .all()
        )
        muscle_ids.update(r.muscle_group_id for r in secondary_rows)
        muscles = {}
        if muscle_ids:
            muscles = {
                m.id: m
                for m in (
                    await db.execute(
                        select(MuscleGroup).where(MuscleGroup.id.in_(muscle_ids))
                    )
                )
                .scalars()
                .all()
            }

        eq_ids = {e.equipment_id for e in exercises if e.equipment_id}
        equipment_rows = {}
        if eq_ids:
            equipment_rows = {
                e.id: e
                for e in (
                    await db.execute(select(Equipment).where(Equipment.id.in_(eq_ids)))
                )
                .scalars()
                .all()
            }

        secondary_by_ex: dict[int, list[int]] = defaultdict(list)
        for row in secondary_rows:
            secondary_by_ex[row.exercise_id].append(row.muscle_group_id)

        for exercise in exercises:
            volume = set_counts.get(exercise.id, 1)
            muscle = muscles.get(exercise.primary_muscle_group_id)
            if muscle:
                prev = primary.get(muscle.id)
                primary[muscle.id] = TemplateMuscleHit(
                    name=muscle.name,
                    name_en=muscle.name_en,
                    is_primary=True,
                    set_count=(prev.set_count if prev else 0) + volume,
                )
            eq = (
                equipment_rows.get(exercise.equipment_id)
                if exercise.equipment_id
                else None
            )
            if eq and eq.id not in equipment:
                equipment[eq.id] = TemplateEquipmentHit(
                    id=eq.id, name=eq.name, name_en=eq.name_en
                )
            for mg_id in secondary_by_ex.get(exercise.id, []):
                if mg_id in primary:
                    continue
                muscle = muscles.get(mg_id)
                if not muscle:
                    continue
                prev = secondary.get(muscle.id)
                secondary[muscle.id] = TemplateMuscleHit(
                    name=muscle.name,
                    name_en=muscle.name_en,
                    is_primary=False,
                    set_count=(prev.set_count if prev else 0) + volume,
                )

        primary_list = sorted(primary.values(), key=lambda m: m.set_count, reverse=True)
        secondary_list = sorted(
            secondary.values(), key=lambda m: m.set_count, reverse=True
        )
        return primary_list, secondary_list, list(equipment.values())

    @staticmethod
    async def to_list_item(
        db: AsyncSession,
        template: WorkoutTemplate,
        current_user_id: int,
        slots: list[WorkoutTemplateExercise],
        set_count: int,
        completion_count: int,
        owner_username: str,
    ) -> TemplateListItem:
        primary, secondary, equipment = await TemplateCRUD._hydrate_muscles_equipment(
            db, slots
        )
        return TemplateListItem(
            id=template.id,
            user_id=template.user_id,
            owner_username=owner_username,
            title=template.title,
            description=template.description,
            cover_url=storage_service.presigned_url(template.cover_image_key),
            difficulty=template.difficulty,
            is_public=template.is_public,
            exercise_count=len(slots),
            set_count=set_count,
            completion_count=completion_count,
            is_owner=template.user_id == current_user_id,
            created_at=template.created_at,
            updated_at=template.updated_at,
            primary_muscles=primary,
            secondary_muscles=secondary,
            equipment=equipment,
        )

    @staticmethod
    async def to_detail(
        db: AsyncSession, template: WorkoutTemplate, current_user_id: int
    ) -> TemplateDetailResponse:
        slots_map = await TemplateCRUD._slots_by_template(db, [template.id])
        slots = slots_map.get(template.id, [])
        sets_map = await TemplateCRUD._sets_by_slot(db, [s.id for s in slots if s.id])
        counts = await TemplateCRUD._completion_counts(db, [template.id])
        names = await TemplateCRUD._usernames(db, [template.user_id])
        set_count = sum(len(sets_map.get(s.id, [])) for s in slots)
        item = await TemplateCRUD.to_list_item(
            db,
            template,
            current_user_id,
            slots,
            set_count,
            counts.get(template.id, 0),
            names.get(template.user_id, ""),
        )

        exercise_ids = [s.exercise_id for s in slots]
        exercises = {}
        if exercise_ids:
            exercises = {
                e.id: e
                for e in (
                    await db.execute(
                        select(Exercise).where(Exercise.id.in_(exercise_ids))
                    )
                )
                .scalars()
                .all()
            }

        exercise_responses: list[TemplateExerciseResponse] = []
        for slot in slots:
            exercise = exercises.get(slot.exercise_id)
            planned = sets_map.get(slot.id, [])
            exercise_responses.append(
                TemplateExerciseResponse(
                    id=slot.id,
                    exercise_id=slot.exercise_id,
                    name=exercise.name if exercise else f"动作 {slot.exercise_id}",
                    name_en=exercise.name_en if exercise else None,
                    image_url=(
                        storage_service.presigned_url(exercise.image_key)
                        if exercise
                        else None
                    ),
                    exercise_type=exercise.exercise_type if exercise else "compound",
                    sort_order=slot.sort_order,
                    superset_id=slot.superset_id,
                    notes=slot.notes,
                    rest_target_seconds=slot.rest_target_seconds,
                    weight_unit=slot.weight_unit,
                    sets=[TemplateSetResponse.model_validate(s) for s in planned],
                )
            )
        return TemplateDetailResponse(**item.model_dump(), exercises=exercise_responses)

    @staticmethod
    async def list_items(
        db: AsyncSession, templates: list[WorkoutTemplate], current_user_id: int
    ) -> list[TemplateListItem]:
        ids = [t.id for t in templates if t.id is not None]
        slots_map = await TemplateCRUD._slots_by_template(db, ids)
        all_slots = [s for slots in slots_map.values() for s in slots]
        sets_map = await TemplateCRUD._sets_by_slot(
            db, [s.id for s in all_slots if s.id]
        )
        completions = await TemplateCRUD._completion_counts(db, ids)
        names = await TemplateCRUD._usernames(db, [t.user_id for t in templates])
        items: list[TemplateListItem] = []
        for template in templates:
            slots = slots_map.get(template.id, [])
            set_count = sum(len(sets_map.get(s.id, [])) for s in slots)
            items.append(
                await TemplateCRUD.to_list_item(
                    db,
                    template,
                    current_user_id,
                    slots,
                    set_count,
                    completions.get(template.id, 0),
                    names.get(template.user_id, ""),
                )
            )
        return items

    @staticmethod
    async def list_completions(
        db: AsyncSession,
        template_id: int,
        current_user_id: int,
        skip: int = 0,
        limit: int = 20,
    ) -> tuple[list[dict], int]:
        base = (
            select(WorkoutSession)
            .where(WorkoutSession.template_id == template_id)
            .where(WorkoutSession.status == "completed")
        )
        total = (
            await db.execute(
                select(func.count()).select_from(base.order_by(None).subquery())
            )
        ).scalar() or 0
        sessions = (
            (
                await db.execute(
                    base.order_by(
                        WorkoutSession.completed_at.desc(), WorkoutSession.id.desc()
                    )
                    .offset(skip)
                    .limit(limit)
                )
            )
            .scalars()
            .all()
        )
        names = await TemplateCRUD._usernames(db, [s.user_id for s in sessions])
        session_ids = [s.id for s in sessions if s.id is not None]
        set_counts: dict[int, int] = {}
        if session_ids:
            rows = (
                await db.execute(
                    select(WorkoutSet.session_id, func.count())
                    .where(WorkoutSet.session_id.in_(session_ids))
                    .group_by(WorkoutSet.session_id)
                )
            ).all()
            set_counts = {sid: count for sid, count in rows}

        items: list[dict] = []
        for session in sessions:
            duration = None
            if session.completed_at and session.started_at:
                duration = int(
                    (session.completed_at - session.started_at).total_seconds()
                )
                if duration < 0:
                    duration = 0
            items.append(
                {
                    "session_id": session.id,
                    "user_id": session.user_id,
                    "username": names.get(session.user_id, ""),
                    "started_at": session.started_at,
                    "completed_at": session.completed_at,
                    "duration_seconds": duration,
                    "set_count": set_counts.get(session.id, 0),
                    "is_self": session.user_id == current_user_id,
                }
            )
        return items, total


template_crud = TemplateCRUD()
