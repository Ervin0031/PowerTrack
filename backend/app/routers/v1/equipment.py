"""器械管理接口 — 仅管理员可操作"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_superuser
from app.crud.exercise import equipment_crud
from app.models.user import User
from app.schemas.exercise import (
    EquipmentCreate,
    EquipmentResponse,
    EquipmentUpdate,
)

router = APIRouter(prefix="/exercises", tags=["Equipment"])


@router.get(
    "/equipment",
    response_model=dict,
    summary="获取器械列表",
    description=(
        "公开接口，无需认证。分页返回训练器械字典。\n\n"
        "请求格式（Query）：\n"
        "- `skip`: int 默认 0，分页偏移量\n"
        "- `limit`: int 默认 20，1-100\n\n"
        '返回格式（200）：\n`{"items": [{"id": 1, "name": "杠铃", "name_en": '
        '"Barbell"}...], "total": 数量}`'
    ),
    response_description="器械分页列表。",
)
async def list_equipment(
    skip: int = Query(0, ge=0, description="分页偏移量"),
    limit: int = Query(20, ge=1, le=100, description="每页条数（1-100）"),
    db: AsyncSession = Depends(get_db),
):
    """获取器械列表，支持分页"""
    items, total = await equipment_crud.get_all(db, skip=skip, limit=limit)
    return {"items": items, "total": total}


@router.post(
    "/equipment",
    response_model=EquipmentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="创建器械",
    description=(
        "仅管理员。\n\n"
        "请求格式（JSON Body）：\n"
        "- `name`: string 必填，1-50 字符，中文名\n"
        "- `name_en`: string 必填，1-50 字符，英文名\n\n"
        '```json\n{"name": "杠铃", "name_en": "Barbell"}\n```\n\n'
        '返回格式（201）：`{"id": 1, "name": "杠铃", "name_en": "Barbell"}`\n\n'
        "错误码：403 非管理员。"
    ),
    response_description="创建成功的器械信息。",
)
async def create_equipment(
    data: EquipmentCreate,
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """创建新器械

    Args:
        data: 器械数据（name 中文名, name_en 英文名）

    Returns:
        创建成功的器械信息
    """
    return await equipment_crud.create(db, data)


@router.put(
    "/equipment/{eq_id}",
    response_model=EquipmentResponse,
    summary="更新器械",
    description=(
        "仅管理员。只传需要修改的字段。\n\n"
        "请求格式：\n"
        "- Path：`eq_id` int 必填\n"
        '- JSON Body（可选）：`{"name": "新名称", "name_en": "New Name"}`\n\n'
        "返回格式（200）：更新后的器械对象。\n\n"
        "错误码：403 非管理员；404 器械不存在。"
    ),
    response_description="更新后的器械信息。",
)
async def update_equipment(
    eq_id: int,
    data: EquipmentUpdate,
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """更新指定器械

    Args:
        eq_id: 器械 ID
        data: 需要更新的字段

    Returns:
        更新后的器械信息

    Raises:
        404: 器械不存在
    """
    obj = await equipment_crud.update(db, eq_id, data)
    if not obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Equipment not found"
        )
    return obj


@router.delete(
    "/equipment/{eq_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="删除器械",
    description=(
        "仅管理员。若该器械已被动作引用则返回 409，无法删除。\n\n"
        "请求格式（Path）：`eq_id` int 必填。\n\n"
        "返回格式：204 无响应体。\n\n"
        "错误码：403 非管理员；404 器械不存在；409 被动作引用。"
    ),
    response_description="删除成功，无响应体。",
    responses={
        204: {"description": "删除成功"},
        404: {"description": "器械不存在"},
        409: {"description": "器械被动作引用，无法删除"},
    },
)
async def delete_equipment(
    eq_id: int,
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """删除指定器械

    如果器械被 exercise 引用则返回 409，不存在则返回 404。
    """
    success = await equipment_crud.delete(db, eq_id)
    if not success:
        exists = await equipment_crud.get_by_id(db, eq_id)
        if exists:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Equipment is referenced by exercises, cannot delete",
            )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Equipment not found"
        )
