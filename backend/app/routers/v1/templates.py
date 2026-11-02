"""训练模板接口"""

import json

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.crud.template import template_crud
from app.models.user import User
from app.schemas.template import (
    TemplateCompletionItem,
    TemplateDetailResponse,
    TemplateListItem,
    TemplateWrite,
)
from app.services.storage import storage_service
from app.core.config import settings

router = APIRouter(prefix="/templates", tags=["Workout Templates"])


def _parse_write(data: str) -> TemplateWrite:
    try:
        payload = json.loads(data)
    except json.JSONDecodeError as exc:
        raise HTTPException(400, "invalid template JSON") from exc
    return TemplateWrite.model_validate(payload)


def _can_view(template, user: User) -> bool:
    return template.is_public or template.user_id == user.id or user.is_superuser


def _can_edit(template, user: User) -> bool:
    return template.user_id == user.id or user.is_superuser


@router.get(
    "",
    response_model=dict,
    summary="获取训练模板列表",
    description=(
        "需认证。分页列出可见模板：自己的私密模板 + 全部公开模板，支持多维度筛选。\n\n"
        "请求格式（Query）：\n"
        "- `skip`: int 默认 0；`limit`: int 默认 20，1-100\n"
        "- `search`: string 可选，搜标题/说明\n"
        "- `difficulty`: string 可选 easy/moderate/hard\n"
        "- `muscle_group_id`: int 可选，按会练到的肌群筛选\n"
        "- `equipment_id`: int 可选，按用到的器械筛选\n"
        "- `is_public`: bool 可选，仅公开/仅私密\n"
        "- `scope`: string 默认 all，仅取 all/mine/public\n\n"
        '返回格式（200）：`{"items": [TemplateListItem...], "total": 数量}`，'
        "每项含 `id / user_id / owner_username / title / description / cover_url / "
        "difficulty / "
        "is_public / exercise_count / set_count / completion_count / is_owner / "
        "created_at / updated_at / "
        "primary_muscles[] / secondary_muscles[] / equipment[]`。\n\n"
        "错误码：400 scope 非法。"
    ),
    response_description="可见模板的分页列表。",
)
async def list_templates(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = Query(None, description="搜索标题或说明"),
    difficulty: str | None = Query(None, description="easy / moderate / hard"),
    muscle_group_id: int | None = Query(None, description="按会练到的肌群筛选"),
    equipment_id: int | None = Query(None, description="按用到的器械筛选"),
    is_public: bool | None = Query(None, description="仅公开或仅私密"),
    scope: str = Query("all", description="all / mine / public"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if scope not in ("all", "mine", "public"):
        raise HTTPException(400, "scope must be all, mine, or public")
    items, total = await template_crud.get_all(
        db,
        user_id=current_user.id,
        skip=skip,
        limit=limit,
        search=search,
        difficulty=difficulty,
        muscle_group_id=muscle_group_id,
        equipment_id=equipment_id,
        is_public=is_public,
        scope=scope,
    )
    listed = await template_crud.list_items(db, items, current_user.id)
    return {
        "items": [TemplateListItem.model_validate(i.model_dump()) for i in listed],
        "total": total,
    }


@router.post(
    "",
    response_model=TemplateDetailResponse,
    status_code=status.HTTP_201_CREATED,
    summary="创建训练模板",
    description=(
        "需认证。multipart/form-data：`data` 为 TemplateWrite 的 JSON 字符串，`image` 为可选封面图。\n"
        "字段兼容 camelCase/snake_case。\n\n"
        "请求格式（Form）：\n"
        "- `data`: string 必填，JSON，字段：`title`(必填 1-120) / `description` / "
        "`difficulty`(easy/moderate/hard) / `is_public`(bool) / `exercises[]`，"
        "每个 exercise 含 `exercise_id`(必填) / `sort_order / superset_id / notes / "
        "rest_target_seconds / "
        "weight_unit(默认kg) / sets[]`，每组含 `set_number`(必填≥1) / `reps / weight_kg / "
        "duration_seconds / "
        "distance_meters / notes / set_kind(默认working)`\n"
        "- `image`: file 可选，封面图\n\n"
        '```json\n{"title": "胸肌日", "difficulty": "moderate", "isPublic": '
        "true, "
        '"exercises": [{"exerciseId": 1, "sortOrder": 0, "sets": '
        '[{"setNumber": 1, "reps": 10, "weightKg": 60}]}]}\n```\n\n'
        "返回格式（201）：TemplateDetailResponse（列表项 + `exercises[]` 完整结构，每项含动作名/图片/组明细）。"
    ),
    response_description="创建成功，返回模板详情。",
)
async def create_template(
    data: str = Form(..., description="TemplateWrite 的 JSON 字符串"),
    image: UploadFile | None = File(None, description="封面图（可选）"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    payload = _parse_write(data)
    template = await template_crud.create(db, current_user.id, payload)
    if image and image.filename:
        key = storage_service.upload(
            image, prefix=settings.storage.STORAGE_TEMPLATE_IMAGES_PREFIX
        )
        template = await template_crud.set_cover_key(db, template, key)
    return await template_crud.to_detail(db, template, current_user.id)


@router.get(
    "/{template_id}",
    response_model=TemplateDetailResponse,
    summary="获取训练模板详情",
    description=(
        "需认证。仅可查看：公开模板、自己的私密模板（管理员可见全部）。\n\n"
        "请求格式（Path）：`template_id` int 必填。\n\n"
        "返回格式（200）：TemplateDetailResponse，含 `exercises[]`（动作名/图片/组明细）与肌群/器械命中统计。\n\n"
        "错误码：404 模板不存在或无权查看。"
    ),
    response_description="模板完整详情。",
)
async def get_template(
    template_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    template = await template_crud.get_by_id(db, template_id)
    if not template or not _can_view(template, current_user):
        raise HTTPException(404, "Template not found")
    return await template_crud.to_detail(db, template, current_user.id)


@router.put(
    "/{template_id}",
    response_model=TemplateDetailResponse,
    summary="更新训练模板",
    description=(
        "需认证。仅创建者本人或管理员可编辑；`image` 传入则替换旧封面。\n\n"
        "请求格式：\n"
        "- Path：`template_id` int 必填\n"
        "- Form `data`: string 必填，TemplateWrite JSON（同创建接口）\n"
        "- Form `image`: file 可选，新封面图\n\n"
        "返回格式（200）：更新后的 TemplateDetailResponse。\n\n"
        "错误码：403 无权编辑；404 模板不存在或无权查看。"
    ),
    response_description="更新后的模板详情。",
)
async def update_template(
    template_id: int,
    data: str = Form(..., description="TemplateWrite 的 JSON 字符串"),
    image: UploadFile | None = File(None, description="封面图（可选，传入则替换）"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    template = await template_crud.get_by_id(db, template_id)
    if not template or not _can_view(template, current_user):
        raise HTTPException(404, "Template not found")
    if not _can_edit(template, current_user):
        raise HTTPException(403, "Access denied")
    payload = _parse_write(data)
    template = await template_crud.update(db, template, payload)
    if image and image.filename:
        if template.cover_image_key:
            storage_service.delete(template.cover_image_key)
        key = storage_service.upload(
            image, prefix=settings.storage.STORAGE_TEMPLATE_IMAGES_PREFIX
        )
        template = await template_crud.set_cover_key(db, template, key)
    return await template_crud.to_detail(db, template, current_user.id)


@router.delete(
    "/{template_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="删除训练模板",
    description=(
        "需认证。仅创建者本人或管理员可删除，同时清理封面图。\n\n"
        "请求格式（Path）：`template_id` int 必填。\n\n"
        "返回格式：204 无响应体。\n\n"
        "错误码：403 无权删除；404 模板不存在或无权查看。"
    ),
    response_description="删除成功，无响应体。",
)
async def delete_template(
    template_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    template = await template_crud.get_by_id(db, template_id)
    if not template or not _can_view(template, current_user):
        raise HTTPException(404, "Template not found")
    if not _can_edit(template, current_user):
        raise HTTPException(403, "Access denied")
    if template.cover_image_key:
        storage_service.delete(template.cover_image_key)
    await template_crud.delete(db, template)


@router.get(
    "/{template_id}/completions",
    response_model=dict,
    summary="模板完成记录列表",
    description=(
        "需认证。列出使用该模板完成过训练的记录；私密模板仅创建者可见。\n\n"
        "请求格式：\n"
        "- Path：`template_id` int 必填\n"
        "- Query：`skip` 默认 0；`limit` 默认 20，1-100\n\n"
        '返回格式（200）：`{"items": [{"session_id": 10, "user_id": 1, "username": '
        '"...", '
        '"started_at": "...", "completed_at": "...", "duration_seconds": '
        "3600, "
        '"set_count": 12, "is_self": true}...], "total": 数量}`\n\n'
        "错误码：404 模板不存在或无权查看。"
    ),
    response_description="该模板的完成记录分页列表。",
)
async def list_completions(
    template_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    template = await template_crud.get_by_id(db, template_id)
    if not template or not _can_view(template, current_user):
        raise HTTPException(404, "Template not found")
    items, total = await template_crud.list_completions(
        db, template_id, current_user.id, skip=skip, limit=limit
    )
    return {
        "items": [TemplateCompletionItem.model_validate(i) for i in items],
        "total": total,
    }
