"""肌群管理接口 — 仅管理员可操作"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_superuser
from app.crud.exercise import muscle_group_crud
from app.models.user import User
from app.schemas.exercise import (
    MuscleGroupCreate,
    MuscleGroupResponse,
    MuscleGroupUpdate,
)

router = APIRouter(prefix="/exercises", tags=["Muscle Groups"])


@router.get(
    "/muscle-groups",
    response_model=dict,
    summary="获取肌群列表",
    description=(
        "公开接口，无需认证。分页返回肌群字典。\n\n"
        "请求格式（Query）：\n"
        "- `skip`: int 默认 0，分页偏移量\n"
        "- `limit`: int 默认 20，1-100\n"
        "- `category`: string 可选 upper（上肢）/ lower（下肢）/ core（核心）\n\n"
        '返回格式（200）：\n`{"items": [{"id": 1, "name": "胸部", "name_en": '
        '"Chest", "category": "upper"}...], "total": 数量}`'
    ),
    response_description="肌群分页列表。",
)
async def list_muscle_groups(
    skip: int = Query(0, ge=0, description="分页偏移量"),
    limit: int = Query(20, ge=1, le=100, description="每页条数（1-100）"),
    category: str | None = Query(
        None,
        description="筛选类型：upper / lower / core",
        examples=["upper"],
    ),
    db: AsyncSession = Depends(get_db),
):
    """获取肌群列表，支持分页和按部位分类筛选"""
    items, total = await muscle_group_crud.get_all(
        db, category=category, skip=skip, limit=limit
    )
    return {"items": items, "total": total}


@router.post(
    "/muscle-groups",
    response_model=MuscleGroupResponse,
    status_code=status.HTTP_201_CREATED,
    summary="创建肌群",
    description=(
        "仅管理员。\n\n"
        "请求格式（JSON Body）：\n"
        "- `name`: string 必填，中文名\n"
        "- `name_en`: string 必填，英文名\n"
        "- `category`: string 必填 upper/lower/core\n\n"
        '```json\n{"name": "胸部", "name_en": "Chest", "category": '
        '"upper"}\n```\n\n'
        "返回格式（201）：创建成功的肌群对象（含 id）。\n\n"
        "错误码：403 非管理员。"
    ),
    response_description="创建成功的肌群信息。",
)
async def create_muscle_group(
    data: MuscleGroupCreate,
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """创建新肌群

    Args:
        data: 肌群数据（name 中文名, name_en 英文名, category 分类）

    Returns:
        创建成功的肌群信息
    """
    return await muscle_group_crud.create(db, data)


@router.put(
    "/muscle-groups/{mg_id}",
    response_model=MuscleGroupResponse,
    summary="更新肌群",
    description=(
        "仅管理员。只传需要修改的字段。\n\n"
        "请求格式：\n"
        "- Path：`mg_id` int 必填\n"
        '- JSON Body（可选）：`{"name": "背部", "name_en": "Back", "category": '
        '"upper"}`\n\n'
        "返回格式（200）：更新后的肌群对象。\n\n"
        "错误码：403 非管理员；404 肌群不存在。"
    ),
    response_description="更新后的肌群信息。",
)
async def update_muscle_group(
    mg_id: int,
    data: MuscleGroupUpdate,
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """更新指定肌群

    Args:
        mg_id: 肌群 ID
        data: 需要更新的字段

    Returns:
        更新后的肌群信息

    Raises:
        404: 肌群不存在
    """
    obj = await muscle_group_crud.update(db, mg_id, data)
    if not obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Muscle group not found"
        )
    return obj


@router.delete(
    "/muscle-groups/{mg_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="删除肌群",
    description=(
        "仅管理员。若该肌群已被动作引用则返回 409，无法删除。\n\n"
        "请求格式（Path）：`mg_id` int 必填。\n\n"
        "返回格式：204 无响应体。\n\n"
        "错误码：403 非管理员；404 肌群不存在；409 被动作引用。"
    ),
    response_description="删除成功，无响应体。",
    responses={
        204: {"description": "删除成功"},
        404: {"description": "肌群不存在"},
        409: {"description": "肌群被动作引用，无法删除"},
    },
)
async def delete_muscle_group(
    mg_id: int,
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """删除指定肌群

    如果肌群被 exercise 引用则返回 409，不存在则返回 404。
    """
    success = await muscle_group_crud.delete(db, mg_id)
    if not success:
        exists = await muscle_group_crud.get_by_id(db, mg_id)
        if exists:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Muscle group is referenced by exercises, cannot delete",
            )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Muscle group not found"
        )
