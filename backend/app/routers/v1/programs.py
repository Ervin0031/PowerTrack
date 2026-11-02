"""当前训练块，以及动作的下次课处方。"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.program import ProgramWrite
from app.services.program import (
    delete_block,
    exercise_prescription,
    program_view,
    save_block,
)

router = APIRouter(tags=["Training Block"])


@router.get("/programs/active", summary="当前训练块")
async def get_active_program(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await program_view(db, current_user.id)


@router.put("/programs/active", summary="保存当前训练块")
async def put_active_program(
    payload: ProgramWrite,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await save_block(db, current_user.id, payload)


@router.delete("/programs/active", summary="结束当前训练块")
async def delete_active_program(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await delete_block(db, current_user.id)
    return {"active": False}


@router.get(
    "/exercises/{exercise_id}/prescription",
    summary="这个动作下次课怎么练",
)
async def get_exercise_prescription(
    exercise_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await exercise_prescription(db, current_user.id, exercise_id)
