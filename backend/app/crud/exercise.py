"""Exercise library CRUD operations"""

from datetime import datetime
from typing import Optional

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import (
    Equipment,
    Exercise,
    ExerciseSecondaryMuscle,
    MuscleGroup,
)
from app.schemas.exercise import (
    EquipmentCreate,
    EquipmentUpdate,
    ExerciseCreate,
    ExerciseUpdate,
    MuscleGroupCreate,
    MuscleGroupUpdate,
)


class MuscleGroupCRUD:
    """Muscle group CRUD"""

    @staticmethod
    async def get_all(
        db: AsyncSession,
        category: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> tuple[list[MuscleGroup], int]:
        base = select(MuscleGroup)
        if category:
            base = base.where(MuscleGroup.category == category)
        # count total
        total_stmt = select(func.count()).select_from(base.subquery())
        total = (await db.execute(total_stmt)).scalar() or 0
        # paginated query
        stmt = base.order_by(MuscleGroup.id).offset(skip).limit(limit)
        result = await db.execute(stmt)
        return list(result.scalars().all()), total

    @staticmethod
    async def get_by_id(db: AsyncSession, mg_id: int) -> Optional[MuscleGroup]:
        return await db.get(MuscleGroup, mg_id)

    @staticmethod
    async def create(db: AsyncSession, data: MuscleGroupCreate) -> MuscleGroup:
        obj = MuscleGroup(**data.model_dump())
        db.add(obj)
        await db.commit()
        await db.refresh(obj)
        return obj

    @staticmethod
    async def update(
        db: AsyncSession, mg_id: int, data: MuscleGroupUpdate
    ) -> Optional[MuscleGroup]:
        obj = await MuscleGroupCRUD.get_by_id(db, mg_id)
        if not obj:
            return None
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(obj, field, value)
        db.add(obj)
        await db.commit()
        await db.refresh(obj)
        return obj

    @staticmethod
    async def delete(db: AsyncSession, mg_id: int) -> bool:
        obj = await MuscleGroupCRUD.get_by_id(db, mg_id)
        if not obj:
            return False
        # ponytail: check for referenced exercises before deleting
        ref = await db.execute(
            select(Exercise).where(Exercise.primary_muscle_group_id == mg_id).limit(1)
        )
        if ref.scalar_one_or_none():
            return False  # caller should return 409
        await db.delete(obj)
        await db.commit()
        return True


muscle_group_crud = MuscleGroupCRUD()


class EquipmentCRUD:
    """Equipment CRUD"""

    @staticmethod
    async def get_all(
        db: AsyncSession,
        skip: int = 0,
        limit: int = 100,
    ) -> tuple[list[Equipment], int]:
        base = select(Equipment)
        total_stmt = select(func.count()).select_from(base.subquery())
        total = (await db.execute(total_stmt)).scalar() or 0
        stmt = base.order_by(Equipment.id).offset(skip).limit(limit)
        result = await db.execute(stmt)
        return list(result.scalars().all()), total

    @staticmethod
    async def get_by_id(db: AsyncSession, eq_id: int) -> Optional[Equipment]:
        return await db.get(Equipment, eq_id)

    @staticmethod
    async def create(db: AsyncSession, data: EquipmentCreate) -> Equipment:
        obj = Equipment(**data.model_dump())
        db.add(obj)
        await db.commit()
        await db.refresh(obj)
        return obj

    @staticmethod
    async def update(
        db: AsyncSession, eq_id: int, data: EquipmentUpdate
    ) -> Optional[Equipment]:
        obj = await EquipmentCRUD.get_by_id(db, eq_id)
        if not obj:
            return None
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(obj, field, value)
        db.add(obj)
        await db.commit()
        await db.refresh(obj)
        return obj

    @staticmethod
    async def delete(db: AsyncSession, eq_id: int) -> bool:
        obj = await EquipmentCRUD.get_by_id(db, eq_id)
        if not obj:
            return False
        ref = await db.execute(
            select(Exercise).where(Exercise.equipment_id == eq_id).limit(1)
        )
        if ref.scalar_one_or_none():
            return False
        await db.delete(obj)
        await db.commit()
        return True


equipment_crud = EquipmentCRUD()


class ExerciseCRUD:
    """Exercise CRUD"""

    @staticmethod
    async def get_all(
        db: AsyncSession,
        skip: int = 0,
        limit: int = 20,
        search: Optional[str] = None,
        muscle_group_id: Optional[int] = None,
        equipment_id: Optional[int] = None,
        exercise_type: Optional[str] = None,
    ) -> tuple[list[Exercise], int]:
        # base query
        base = select(Exercise)
        count_base = select(Exercise)

        if search:
            base = base.where(Exercise.name.ilike(f"%{search}%"))
            count_base = count_base.where(Exercise.name.ilike(f"%{search}%"))
        if muscle_group_id:
            base = base.where(Exercise.primary_muscle_group_id == muscle_group_id)
            count_base = count_base.where(
                Exercise.primary_muscle_group_id == muscle_group_id
            )
        if equipment_id:
            base = base.where(Exercise.equipment_id == equipment_id)
            count_base = count_base.where(Exercise.equipment_id == equipment_id)
        if exercise_type:
            base = base.where(Exercise.exercise_type == exercise_type)
            count_base = count_base.where(Exercise.exercise_type == exercise_type)

        # count — ponytail: subquery avoids with_only_columns entity-mapping quirks
        count_stmt = select(func.count()).select_from(
            count_base.order_by(None).subquery()
        )
        total = (await db.execute(count_stmt)).scalar() or 0

        # paginated results
        stmt = base.order_by(Exercise.id).offset(skip).limit(limit)
        result = await db.execute(stmt)
        return list(result.scalars().all()), total

    @staticmethod
    async def get_by_id(db: AsyncSession, ex_id: int) -> Optional[Exercise]:
        return await db.get(Exercise, ex_id)

    @staticmethod
    async def get_secondary_muscle_ids(db: AsyncSession, ex_id: int) -> list[int]:
        result = await db.execute(
            select(ExerciseSecondaryMuscle.muscle_group_id).where(
                ExerciseSecondaryMuscle.exercise_id == ex_id
            )
        )
        return [r for r in result.scalars().all()]

    @staticmethod
    async def create(db: AsyncSession, data: ExerciseCreate) -> Exercise:
        obj = Exercise(**data.model_dump(exclude={"secondary_muscle_ids"}))
        db.add(obj)
        await db.flush()  # get the id for secondary muscles

        for mg_id in data.secondary_muscle_ids:
            db.add(ExerciseSecondaryMuscle(exercise_id=obj.id, muscle_group_id=mg_id))

        await db.commit()
        await db.refresh(obj)
        return obj

    @staticmethod
    async def update(
        db: AsyncSession, ex_id: int, data: ExerciseUpdate
    ) -> Optional[Exercise]:
        obj = await ExerciseCRUD.get_by_id(db, ex_id)
        if not obj:
            return None

        update_data = data.model_dump(exclude_unset=True)
        secondary_ids = update_data.pop("secondary_muscle_ids", None)

        for field, value in update_data.items():
            setattr(obj, field, value)

        if secondary_ids is not None:
            # replace secondary muscles wholesale
            await db.execute(
                delete(ExerciseSecondaryMuscle).where(
                    ExerciseSecondaryMuscle.exercise_id == ex_id
                )
            )
            for mg_id in secondary_ids:
                db.add(
                    ExerciseSecondaryMuscle(exercise_id=ex_id, muscle_group_id=mg_id)
                )

        db.add(obj)
        await db.commit()
        await db.refresh(obj)
        return obj

    @staticmethod
    async def set_image_keys(
        db: AsyncSession, ex_id: int, image_key: str, thumb_key: Optional[str]
    ) -> Optional[Exercise]:
        """Update image_key + thumb_key fields on an existing exercise."""
        obj = await ExerciseCRUD.get_by_id(db, ex_id)
        if not obj:
            return None
        obj.image_key = image_key
        obj.thumb_key = thumb_key
        db.add(obj)
        await db.commit()
        await db.refresh(obj)
        return obj

    @staticmethod
    async def delete(db: AsyncSession, ex_id: int) -> bool:
        obj = await ExerciseCRUD.get_by_id(db, ex_id)
        if not obj:
            return False
        # cascade delete secondary muscles
        await db.execute(
            delete(ExerciseSecondaryMuscle).where(
                ExerciseSecondaryMuscle.exercise_id == ex_id
            )
        )
        await db.delete(obj)
        await db.commit()
        return True


exercise_crud = ExerciseCRUD()
