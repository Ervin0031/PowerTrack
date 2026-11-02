"""Workout session & set CRUD operations"""

from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import delete, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.one_rm import one_rm_crud
from app.crud.recovery import recovery_crud
from app.models.exercise import Exercise, MuscleGroup
from app.models.workout import WorkoutSession, WorkoutSet
from app.schemas.workout import SessionComplete, SessionCreate
from app.services.strength import LOAD_SET_KINDS


def _load_sets():
    """工作组、递减组，以及还没有 set_kind 的旧行。"""
    return or_(
        WorkoutSet.set_kind.in_(tuple(LOAD_SET_KINDS)),
        WorkoutSet.set_kind.is_(None),
    )


def _naive_utc(dt: Optional[datetime]) -> Optional[datetime]:
    """Convert timezone-aware datetime to naive UTC for PostgreSQL TIMESTAMP WITHOUT TIME ZONE."""
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


class WorkoutSessionCRUD:
    """Training session CRUD"""

    @staticmethod
    async def get_by_id(db: AsyncSession, session_id: int) -> Optional[WorkoutSession]:
        return await db.get(WorkoutSession, session_id)

    @staticmethod
    async def get_by_client_uuid(
        db: AsyncSession, client_uuid: str
    ) -> Optional[WorkoutSession]:
        result = await db.execute(
            select(WorkoutSession).where(WorkoutSession.client_uuid == client_uuid)
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def get_all_by_user(
        db: AsyncSession,
        user_id: int,
        status: Optional[str] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        skip: int = 0,
        limit: int = 20,
    ) -> tuple[list[WorkoutSession], int]:
        base = select(WorkoutSession).where(WorkoutSession.user_id == user_id)
        count_base = select(WorkoutSession).where(WorkoutSession.user_id == user_id)

        if status:
            base = base.where(WorkoutSession.status == status)
            count_base = count_base.where(WorkoutSession.status == status)
        # DB 列为 TIMESTAMP WITHOUT TIME ZONE；查询参数常带 tz（如 ...Z），
        # 需转成 naive UTC，否则 asyncpg 会 DataError → 500。
        start_date = _naive_utc(start_date)
        end_date = _naive_utc(end_date)
        if start_date:
            base = base.where(WorkoutSession.started_at >= start_date)
            count_base = count_base.where(WorkoutSession.started_at >= start_date)
        if end_date:
            base = base.where(WorkoutSession.started_at <= end_date)
            count_base = count_base.where(WorkoutSession.started_at <= end_date)

        count_stmt = select(func.count()).select_from(
            count_base.order_by(None).subquery()
        )
        total = (await db.execute(count_stmt)).scalar() or 0

        stmt = base.order_by(WorkoutSession.started_at.desc()).offset(skip).limit(limit)
        result = await db.execute(stmt)
        return list(result.scalars().all()), total

    @staticmethod
    async def get_in_progress(
        db: AsyncSession, user_id: int
    ) -> Optional[WorkoutSession]:
        result = await db.execute(
            select(WorkoutSession)
            .where(WorkoutSession.user_id == user_id)
            .where(WorkoutSession.status == "in_progress")
            .order_by(WorkoutSession.started_at.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def create(
        db: AsyncSession, data: SessionCreate, user_id: int
    ) -> WorkoutSession:
        """创建会话：全局同一用户只允许一个进行中会话。
        同 client_uuid 重复请求幂等返回已有记录；不同 uuid 且已有进行中会话时返回 409。"""
        existing = await WorkoutSessionCRUD.get_in_progress(db, user_id)
        if existing:
            if existing.client_uuid == data.client_uuid:
                return existing
            raise HTTPException(409, "An in-progress workout session already exists")
        obj = WorkoutSession(
            client_uuid=data.client_uuid,
            user_id=user_id,
            status="in_progress",
            started_at=_naive_utc(data.started_at),
            template_id=data.template_id,
        )
        db.add(obj)
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            existing = await WorkoutSessionCRUD.get_by_client_uuid(db, data.client_uuid)
            if existing and existing.user_id == user_id:
                return existing
            raise HTTPException(
                409, "Session with this client_uuid exists for another user"
            )
        except Exception:
            await db.rollback()
            raise
        await db.refresh(obj)
        return obj

    @staticmethod
    async def complete_session(
        db: AsyncSession,
        session_id: int,
        user_id: int,
        data: SessionComplete,
    ) -> WorkoutSession:
        """结束训练 — 事务性批量写入 session + 所有 sets"""
        session = await WorkoutSessionCRUD.get_by_id(db, session_id)
        if not session:
            raise HTTPException(404, "Session not found")
        if session.user_id != user_id:
            raise HTTPException(403, "Access denied")
        if session.client_uuid != data.client_uuid:
            raise HTTPException(400, "client_uuid mismatch")

        already_completed = session.status == "completed"

        # Update session
        session.status = "completed"
        session.started_at = _naive_utc(data.started_at)
        session.completed_at = _naive_utc(data.completed_at)
        session.notes = data.notes
        if data.template_id is not None:
            session.template_id = data.template_id
        session.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
        db.add(session)

        # Insert sets — idempotent per client_uuid
        ingested: list = []
        seen_uuids: set[str] = set()
        for set_data in data.sets:
            # ponytail: dedupe within the same payload
            if set_data.client_uuid in seen_uuids:
                continue
            seen_uuids.add(set_data.client_uuid)

            # Check if this UUID already exists (idempotent replay)
            existing = await db.execute(
                select(WorkoutSet).where(WorkoutSet.client_uuid == set_data.client_uuid)
            )
            if existing.scalar_one_or_none():
                continue

            workout_set = WorkoutSet(
                client_uuid=set_data.client_uuid,
                session_id=session_id,
                exercise_id=set_data.exercise_id,
                set_number=set_data.set_number,
                reps=set_data.reps,
                weight_kg=set_data.weight_kg,
                duration_seconds=set_data.duration_seconds,
                distance_meters=set_data.distance_meters,
                notes=set_data.notes,
                completed_at=_naive_utc(set_data.completed_at),
                rpe=set_data.rpe,
                set_kind=set_data.set_kind or "working",
            )
            db.add(workout_set)
            ingested.append(set_data)

        try:
            await one_rm_crud.apply_session_sets(db, user_id, ingested)
            if not already_completed:
                await recovery_crud.apply_completed_session(
                    db, user_id, session.completed_at or session.updated_at, ingested
                )
            await db.commit()
        except IntegrityError:
            await db.rollback()
            raise HTTPException(
                422,
                "Invalid data: exercise or session reference does not exist",
            )
        await db.refresh(session)
        return session

    @staticmethod
    async def delete(db: AsyncSession, session_id: int) -> bool:
        session = await WorkoutSessionCRUD.get_by_id(db, session_id)
        if not session:
            return False
        # Manual cascade: delete sets first
        await db.execute(delete(WorkoutSet).where(WorkoutSet.session_id == session_id))
        await db.delete(session)
        await db.commit()
        return True


session_crud = WorkoutSessionCRUD()


class WorkoutSetCRUD:
    """Workout set CRUD"""

    @staticmethod
    async def get_by_client_uuid(
        db: AsyncSession, client_uuid: str
    ) -> Optional[WorkoutSet]:
        result = await db.execute(
            select(WorkoutSet).where(WorkoutSet.client_uuid == client_uuid)
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def get_by_session(db: AsyncSession, session_id: int) -> list[WorkoutSet]:
        result = await db.execute(
            select(WorkoutSet)
            .where(WorkoutSet.session_id == session_id)
            .order_by(WorkoutSet.set_number)
        )
        return list(result.scalars().all())

    @staticmethod
    async def get_last_performance(
        db: AsyncSession, exercise_id: int, user_id: int
    ) -> Optional[dict]:
        """获取某动作上一次训练记录"""
        result = await db.execute(
            select(WorkoutSet, WorkoutSession.started_at)
            .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSet.exercise_id == exercise_id,
                WorkoutSession.status == "completed",
            )
            .order_by(WorkoutSession.completed_at.desc(), WorkoutSet.set_number.desc())
            .limit(1)
        )
        row = result.first()
        if not row:
            return None
        workout_set, session_date = row
        return {
            "exercise_id": workout_set.exercise_id,
            "set_number": workout_set.set_number,
            "reps": workout_set.reps,
            "weight_kg": workout_set.weight_kg,
            "duration_seconds": workout_set.duration_seconds,
            "distance_meters": workout_set.distance_meters,
            "completed_at": workout_set.completed_at,
            "session_date": session_date,
            "rpe": workout_set.rpe,
        }

    @staticmethod
    async def get_last_session_sets(
        db: AsyncSession, exercise_id: int, user_id: int
    ) -> Optional[dict]:
        """获取某动作最近一次训练的完整组数据（所有组），用于添加动作到训练时自动填充。"""
        # 找到最近一次包含该动作的已完成训练会话
        session_row = await db.execute(
            select(WorkoutSession.id, WorkoutSession.started_at)
            .join(WorkoutSet, WorkoutSet.session_id == WorkoutSession.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSet.exercise_id == exercise_id,
                WorkoutSession.status == "completed",
            )
            .order_by(WorkoutSession.completed_at.desc())
            .limit(1)
        )
        row = session_row.first()
        if not row:
            return None
        session_id, session_date = row

        sets = await WorkoutSetCRUD.get_by_session(db, session_id)
        sets = [s for s in sets if s.exercise_id == exercise_id]
        return {
            "exercise_id": exercise_id,
            "session_id": session_id,
            "session_date": session_date,
            "sets": sets,
        }

    @staticmethod
    async def get_exercise_history(
        db: AsyncSession,
        exercise_id: int,
        user_id: int,
        skip: int = 0,
        limit: int = 20,
    ) -> tuple[list[dict], int]:
        """某动作历史训练记录"""
        base = (
            select(WorkoutSet)
            .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSet.exercise_id == exercise_id,
                WorkoutSession.status == "completed",
            )
        )

        count_stmt = select(func.count()).select_from(base.order_by(None).subquery())
        total = (await db.execute(count_stmt)).scalar() or 0

        stmt = (
            base.order_by(WorkoutSession.completed_at.desc(), WorkoutSet.set_number)
            .offset(skip)
            .limit(limit)
        )
        result = await db.execute(stmt)
        return list(result.scalars().all()), total

    @staticmethod
    async def get_batch_last_performances(
        db: AsyncSession, exercise_ids: list[int], user_id: int
    ) -> dict[int, Optional[dict]]:
        """批量获取每个动作的最新训练记录

        ponytail: single query via max(id) subquery — id order proxies for recency.
        """
        if not exercise_ids:
            return {}

        # Latest set id per exercise for this user's completed sessions
        subq = (
            select(
                WorkoutSet.exercise_id,
                func.max(WorkoutSet.id).label("max_id"),
            )
            .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSet.exercise_id.in_(exercise_ids),
                WorkoutSession.status == "completed",
            )
            .group_by(WorkoutSet.exercise_id)
        ).subquery()

        stmt = (
            select(WorkoutSet, WorkoutSession.started_at)
            .join(subq, WorkoutSet.id == subq.c.max_id)
            .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
        )
        result = await db.execute(stmt)
        rows = result.all()

        # Build result dict — null for exercises with no history
        perf_map: dict[int, Optional[dict]] = {eid: None for eid in exercise_ids}
        for workout_set, session_date in rows:
            perf_map[workout_set.exercise_id] = {
                "exercise_id": workout_set.exercise_id,
                "set_number": workout_set.set_number,
                "reps": workout_set.reps,
                "weight_kg": workout_set.weight_kg,
                "duration_seconds": workout_set.duration_seconds,
                "distance_meters": workout_set.distance_meters,
                "completed_at": workout_set.completed_at,
                "session_date": session_date,
                "rpe": workout_set.rpe,
            }
        return perf_map

    @staticmethod
    async def list_exercise_set_rows(
        db: AsyncSession,
        exercise_id: int,
        user_id: int,
    ) -> list[tuple]:
        """某动作全部已完成组，供图表聚合。"""
        stmt = (
            select(
                WorkoutSet.session_id,
                WorkoutSet.set_number,
                WorkoutSet.reps,
                WorkoutSet.weight_kg,
                WorkoutSet.rpe,
                WorkoutSet.notes,
                WorkoutSet.completed_at,
                WorkoutSession.started_at,
                WorkoutSession.completed_at,
                WorkoutSet.set_kind,
            )
            .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSet.exercise_id == exercise_id,
                WorkoutSession.status == "completed",
            )
            .order_by(
                WorkoutSession.started_at.desc(),
                WorkoutSet.set_number,
            )
        )
        result = await db.execute(stmt)
        return list(result.all())

    @staticmethod
    async def list_completed_sessions_since(
        db: AsyncSession, user_id: int, since: datetime
    ) -> list[tuple]:
        """周期内已完成会话：(id, started_at, completed_at)。"""
        since = _naive_utc(since)
        result = await db.execute(
            select(
                WorkoutSession.id,
                WorkoutSession.started_at,
                WorkoutSession.completed_at,
            ).where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == "completed",
                WorkoutSession.started_at >= since,
            )
        )
        return list(result.all())

    @staticmethod
    async def list_period_set_rows(
        db: AsyncSession, user_id: int, since: datetime
    ) -> list[tuple]:
        """周期内组行，供总览 KPI / 肌群 / 常练动作。"""
        since = _naive_utc(since)
        result = await db.execute(
            select(
                WorkoutSet.session_id,
                WorkoutSet.exercise_id,
                Exercise.name,
                MuscleGroup.name,
                WorkoutSet.reps,
                WorkoutSet.weight_kg,
                WorkoutSet.rpe,
            )
            .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
            .join(Exercise, WorkoutSet.exercise_id == Exercise.id)
            .outerjoin(MuscleGroup, Exercise.primary_muscle_group_id == MuscleGroup.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == "completed",
                WorkoutSession.started_at >= since,
                _load_sets(),
            )
        )
        return list(result.all())

    @staticmethod
    async def list_lifetime_weight_sets(db: AsyncSession, user_id: int) -> list[tuple]:
        """全量有重量的组，供判定周期内是否破最大重量 PR。

        ponytail: 全表扫描；用户组数上万再改 SQL argmax。
        """
        result = await db.execute(
            select(
                WorkoutSet.exercise_id,
                Exercise.name,
                WorkoutSet.weight_kg,
                func.coalesce(WorkoutSet.completed_at, WorkoutSession.started_at),
            )
            .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
            .join(Exercise, WorkoutSet.exercise_id == Exercise.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == "completed",
                WorkoutSet.weight_kg.is_not(None),
                WorkoutSet.weight_kg > 0,
                _load_sets(),
            )
        )
        return list(result.all())

    @staticmethod
    async def list_session_detail_rows(
        db: AsyncSession, session_id: int
    ) -> list[tuple]:
        """会话内全部组（含热身），供分享快照：
        (set_id, set_number, exercise_id, 动作名, 肌群名, reps, weight_kg, rpe, set_kind)。"""
        result = await db.execute(
            select(
                WorkoutSet.id,
                WorkoutSet.set_number,
                WorkoutSet.exercise_id,
                Exercise.name,
                MuscleGroup.name,
                WorkoutSet.reps,
                WorkoutSet.weight_kg,
                WorkoutSet.rpe,
                WorkoutSet.set_kind,
            )
            .join(Exercise, WorkoutSet.exercise_id == Exercise.id)
            .outerjoin(MuscleGroup, Exercise.primary_muscle_group_id == MuscleGroup.id)
            .where(WorkoutSet.session_id == session_id)
            .order_by(WorkoutSet.set_number, WorkoutSet.id)
        )
        return list(result.all())

    @staticmethod
    async def list_set_loads_by_exercises(
        db: AsyncSession,
        user_id: int,
        exercise_ids: list[int],
        before: datetime,
    ) -> list[tuple]:
        """指定动作在 `before` 之前的全部工作组，供分享快照判定 PR：
        (exercise_id, reps, weight_kg, rpe)。严格 < 以排除本次会话自身。"""
        if not exercise_ids:
            return []
        result = await db.execute(
            select(
                WorkoutSet.exercise_id,
                WorkoutSet.reps,
                WorkoutSet.weight_kg,
                WorkoutSet.rpe,
            )
            .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == "completed",
                WorkoutSet.exercise_id.in_(exercise_ids),
                WorkoutSession.started_at < _naive_utc(before),
                WorkoutSet.weight_kg.is_not(None),
                WorkoutSet.weight_kg > 0,
                _load_sets(),
            )
        )
        return list(result.all())


set_crud = WorkoutSetCRUD()
