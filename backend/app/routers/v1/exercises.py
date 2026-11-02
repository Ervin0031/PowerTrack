"""动作库管理接口 — 仅管理员可操作"""

import json
from urllib.parse import quote

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    Response,
    UploadFile,
    status,
)
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_superuser, get_current_user
from app.crud.exercise import equipment_crud, exercise_crud, muscle_group_crud
from app.models.exercise import Exercise
from app.models.one_rm import UserExercise1RM
from app.models.template import WorkoutTemplateExercise
from app.models.user import User
from app.models.workout import WorkoutSet
from app.schemas.exercise import (
    ExerciseCreate,
    ExerciseDetailResponse,
    ExerciseResponse,
    ExerciseUpdate,
    MuscleGroupResponse,
)
from app.services.storage import storage_service

router = APIRouter(prefix="/exercises", tags=["Exercises"])


@router.get(
    "",
    response_model=dict,
    summary="获取动作列表",
    description=(
        "公开接口，无需认证。分页查询动作库，支持关键词与多维度筛选。\n\n"
        "请求格式（Query）：\n"
        "- `skip`: int 默认 0，分页偏移量\n"
        "- `limit`: int 默认 20，1-100\n"
        "- `search`: string 可选，匹配中英文名称\n"
        "- `muscle_group_id`: int 可选，按主肌群筛选\n"
        "- `equipment_id`: int 可选，按器械筛选\n"
        "- `exercise_type`: string 可选 compound（复合）/ isolation（孤立）\n\n"
        "返回格式（200）：\n"
        '`{"items": [ExerciseResponse...], "total": 数量}`，'
        "ExerciseResponse 字段：`id / name / name_en / exercise_type / "
        "primary_muscle_group_id / "
        "equipment_id / instructions / is_custom / image_key / image_url / "
        "thumb_key / thumb_url / created_at`。image_url/thumb_url 均为稳定地址"
        "（列表场景指向 512px 静态缩略图端点，可长期缓存）。"
    ),
    response_description="动作分页列表。",
)
async def list_exercises(
    request: Request,
    skip: int = Query(0, ge=0, description="分页偏移量"),
    limit: int = Query(20, ge=1, le=100, description="每页条数（1-100）"),
    search: str | None = Query(None, description="搜索关键词，匹配中英文名称"),
    muscle_group_id: int | None = Query(None, description="按肌群 ID 筛选"),
    equipment_id: int | None = Query(None, description="按器械 ID 筛选"),
    exercise_type: str | None = Query(
        None, description="动作类型：compound（复合）/ isolation（孤立）"
    ),
    db: AsyncSession = Depends(get_db),
):
    """分页获取动作列表，支持多维度筛选

    Returns:
        {"items": [...], "total": int}
    """
    items, total = await exercise_crud.get_all(
        db,
        skip=skip,
        limit=limit,
        search=search,
        muscle_group_id=muscle_group_id,
        equipment_id=equipment_id,
        exercise_type=exercise_type,
    )
    result = [ExerciseResponse.model_validate(ex) for ex in items]
    for ex, resp in zip(items, result):
        # 列表里全部是小尺寸格子：两个字段都指向静态缩略图（无缩略图时端点回退原图），
        # 避免客户端为 64px 方块下载几 MB 的 GIF/JPEG。
        key = ex.thumb_key or ex.image_key
        if key:
            resp.image_url = _image_url(request, resp.id, key, thumb=True)
            resp.thumb_url = resp.image_url
    return {"items": result, "total": total}


@router.post(
    "",
    response_model=ExerciseDetailResponse,
    status_code=status.HTTP_201_CREATED,
    summary="创建动作",
    description=(
        "仅管理员。multipart/form-data 上传：`data` 为 ExerciseCreate 的 JSON 字符串，`image` "
        "为可选示范图片。\n\n"
        "请求格式（Form）：\n"
        "- `data`: string 必填，JSON，字段：`name`(必填) / `name_en` / `exercise_type`(必填 "
        "compound/isolation) / "
        "`primary_muscle_group_id`(必填 int) / `equipment_id`(int) / `instructions` / "
        "`is_custom`(bool) / `secondary_muscle_ids`(int[])\n"
        "- `image`: file 可选，动作示范图片\n\n"
        '```json\n{"name": "杠铃卧推", "name_en": "Barbell Bench Press", '
        '"exercise_type": "compound", '
        '"primary_muscle_group_id": 1, "equipment_id": 1, '
        '"secondary_muscle_ids": '
        '[2, 3], "is_custom": false}\n```\n\n'
        "返回格式（201）：ExerciseDetailResponse，额外含 `primary_muscle_name / "
        "primary_muscle_name_en / "
        "equipment_name / equipment_name_en / secondary_muscles[](肌群对象) / "
        "image_url`。\n\n"
        "错误码：403 非管理员；422 表单 JSON 非法。"
    ),
    response_description="创建成功，返回动作详情。",
)
async def create_exercise(
    request: Request,
    data: str = Form(..., description="ExerciseCreate 的 JSON 字符串"),
    image: UploadFile | None = File(None, description="动作示范图片（可选）"),
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """创建新动作

    - **data**: JSON 字符串，字段同 ExerciseCreate schema
    - **image**: 可选图片文件

    示例 data JSON:
    ```json
    {
        "name": "杠铃卧推",
        "name_en": "Barbell Bench Press",
        "exercise_type": "compound",
        "primary_muscle_group_id": 1,
        "equipment_id": 1,
        "secondary_muscle_ids": [2, 3],
        "is_custom": false
    }
    ```
    """
    exercise_data = ExerciseCreate(**json.loads(data))
    exercise = await exercise_crud.create(db, exercise_data)

    if image and image.filename:
        image_key, thumb_key = storage_service.upload_with_thumbnail(image)
        exercise = await exercise_crud.set_image_keys(
            db, exercise.id, image_key, thumb_key
        )

    return await _build_detail(db, exercise, request)


@router.get(
    "/mine",
    summary="我创建的动作",
    description="需认证。只返回当前用户的自建动作。",
)
async def list_my_exercises(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    rows = (
        await db.execute(
            select(Exercise)
            .where(
                Exercise.is_custom.is_(True),
                Exercise.created_by_user_id == current_user.id,
            )
            .order_by(Exercise.id.desc())
            .limit(50)
        )
    ).scalars().all()
    return {
        "items": [
            {
                "id": row.id,
                "name": row.name,
                "name_en": row.name_en,
                "exercise_type": row.exercise_type,
                "primary_muscle_group_id": row.primary_muscle_group_id,
                "equipment_id": row.equipment_id,
                "instructions": row.instructions,
                "is_custom": True,
            }
            for row in rows
        ]
    }


@router.post(
    "/mine",
    response_model=ExerciseDetailResponse,
    status_code=status.HTTP_201_CREATED,
    summary="创建我的动作",
    description="需认证。创建的动作归当前用户，且标记为自建。不能写入公共动作库。",
)
async def create_my_exercise(
    data: ExerciseCreate,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _check_exercise_refs(db, data.primary_muscle_group_id, data.equipment_id)
    if data.exercise_type not in ("compound", "isolation"):
        raise HTTPException(422, "exercise_type 只能是 compound 或 isolation")
    payload = data.model_copy(update={"is_custom": True})
    exercise = await exercise_crud.create(db, payload)
    exercise.created_by_user_id = current_user.id
    exercise.is_custom = True
    db.add(exercise)
    await db.commit()
    await db.refresh(exercise)
    return await _build_detail(db, exercise, request)


@router.put(
    "/mine/{ex_id}",
    response_model=ExerciseDetailResponse,
    summary="修改我的动作",
    description="需认证。只能改自己创建的动作。",
)
async def update_my_exercise(
    ex_id: int,
    data: ExerciseUpdate,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    exercise = await _own_exercise(db, ex_id, current_user.id)
    if data.primary_muscle_group_id is not None or data.equipment_id is not None:
        equipment_id = (
            data.equipment_id
            if data.equipment_id is not None
            else exercise.equipment_id
        )
        await _check_exercise_refs(
            db,
            data.primary_muscle_group_id or exercise.primary_muscle_group_id,
            equipment_id,
        )
    if data.exercise_type is not None and data.exercise_type not in (
        "compound",
        "isolation",
    ):
        raise HTTPException(422, "exercise_type 只能是 compound 或 isolation")
    payload = data.model_copy(update={"is_custom": True})
    updated = await exercise_crud.update(db, exercise.id, payload)
    return await _build_detail(db, updated, request)


@router.delete(
    "/mine/{ex_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="删除我的动作",
    description="需认证。只能删自己创建、且没有训练记录或模板引用的动作。",
)
async def delete_my_exercise(
    ex_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    exercise = await _own_exercise(db, ex_id, current_user.id)
    if await _exercise_in_use(db, exercise.id):
        raise HTTPException(409, "这个动作已经有训练记录或模板，不能删除")
    await exercise_crud.delete(db, exercise.id)


async def _own_exercise(db: AsyncSession, ex_id: int, user_id: int) -> Exercise:
    exercise = await exercise_crud.get_by_id(db, ex_id)
    if exercise is None:
        raise HTTPException(404, "动作不存在")
    if not exercise.is_custom or exercise.created_by_user_id != user_id:
        raise HTTPException(403, "只能修改或删除自己创建的动作")
    return exercise


async def _check_exercise_refs(
    db: AsyncSession, muscle_id: int, equipment_id: int | None
) -> None:
    if await muscle_group_crud.get_by_id(db, muscle_id) is None:
        raise HTTPException(422, "肌群不存在")
    if equipment_id is not None:
        equipment = await equipment_crud.get_by_id(db, equipment_id)
        if equipment is None:
            raise HTTPException(422, "器械不存在")


async def _exercise_in_use(db: AsyncSession, ex_id: int) -> bool:
    for model, column in (
        (WorkoutSet, WorkoutSet.exercise_id),
        (WorkoutTemplateExercise, WorkoutTemplateExercise.exercise_id),
        (UserExercise1RM, UserExercise1RM.exercise_id),
    ):
        count = await db.scalar(
            select(func.count()).select_from(model).where(column == ex_id)
        )
        if count:
            return True
    return False


@router.get(
    "/{ex_id}",
    response_model=ExerciseDetailResponse,
    summary="获取动作详情",
    description=(
        "公开接口，无需认证。\n\n"
        "请求格式（Path）：`ex_id` int 必填，动作 ID。\n\n"
        "返回格式（200）：ExerciseDetailResponse，含主肌群/器械中英文名、辅助肌群列表、"
        "图片稳定 URL（image_url 为原图，可含 GIF 动图；thumb_url 为静态缩略图）。\n\n"
        "错误码：404 动作不存在。"
    ),
    response_description="动作完整详情。",
    responses={404: {"description": "动作不存在"}},
)
async def get_exercise(
    ex_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """获取指定动作详情

    Args:
        ex_id: 动作 ID

    Returns:
        动作详情（含关联的肌群名、器械名、辅助肌群、图片稳定 URL）

    Raises:
        404: 动作不存在
    """
    exercise = await exercise_crud.get_by_id(db, ex_id)
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Exercise not found"
        )
    return await _build_detail(db, exercise, request)


# ---- 稳定图片端点：客户端可长期缓存，URL 不随签名变化 ----

_IMAGE_CACHE = "public, max-age=86400"


def _public_base(request: Request) -> str:
    """对外 origin — 跟随本次请求的 Host，本机/内网/反代都自动正确。"""
    return str(request.base_url).rstrip("/")


def _image_url(request: Request, ex_id: int, key: str, thumb: bool = False) -> str:
    """稳定图片地址；key 作为版本参数，替换图片后 URL 立即变化、否则永久不变。"""
    kind = "thumb" if thumb else "image"
    version = quote(key, safe="")
    return f"{_public_base(request)}/api/v1/exercises/{ex_id}/{kind}?v={version}"


async def _serve_image(
    request: Request, db: AsyncSession, ex_id: int, thumb: bool
) -> Response:
    """读取并返回动作图片；ETag 命中时直接 304，不访问存储。"""
    exercise = await exercise_crud.get_by_id(db, ex_id)
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Image not found"
        )
    key = (exercise.thumb_key or exercise.image_key) if thumb else exercise.image_key
    if not key:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Image not found"
        )

    etag = f'"{key}"'  # key 每次上传都是新 uuid，天然是版本号
    headers = {"ETag": etag, "Cache-Control": _IMAGE_CACHE}
    if request.headers.get("if-none-match") == etag:
        return Response(status_code=status.HTTP_304_NOT_MODIFIED, headers=headers)

    fetched = await storage_service.fetch(key)
    if not fetched:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Image not found"
        )
    content, media_type = fetched
    return Response(content=content, media_type=media_type, headers=headers)


@router.get(
    "/{ex_id}/image",
    response_class=Response,
    summary="获取动作原图",
    description=(
        "公开接口，无需认证。稳定地址，客户端可长期缓存；"
        "支持 ETag/If-None-Match（命中返回 304，不访问对象存储）。\n\n"
        "错误码：404 动作或图片不存在。"
    ),
    response_description="图片字节流。",
    responses={
        304: {"description": "未修改"},
        404: {"description": "动作或图片不存在"},
    },
)
async def get_exercise_image(
    ex_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """返回动作原图（可能为 GIF 动图）。"""
    return await _serve_image(request, db, ex_id, thumb=False)


@router.get(
    "/{ex_id}/thumb",
    response_class=Response,
    summary="获取动作缩略图",
    description=(
        "公开接口，无需认证。512px 静态缩略图，稳定地址；无缩略图时回退原图。"
        "支持 ETag/If-None-Match（命中返回 304，不访问对象存储）。\n\n"
        "错误码：404 动作或图片不存在。"
    ),
    response_description="缩略图字节流。",
    responses={
        304: {"description": "未修改"},
        404: {"description": "动作或图片不存在"},
    },
)
async def get_exercise_thumb(
    ex_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """返回动作缩略图（静态）。"""
    return await _serve_image(request, db, ex_id, thumb=True)


@router.put(
    "/{ex_id}",
    response_model=ExerciseDetailResponse,
    summary="更新动作",
    description=(
        "仅管理员。multipart/form-data：`data` 为 ExerciseUpdate 的 JSON（只传需改字段），"
        "`image` 可选，传入则替换旧图片。\n\n"
        "请求格式：\n"
        "- Path：`ex_id` int 必填\n"
        "- Form `data`: JSON，可选字段 `name / name_en / exercise_type / "
        "primary_muscle_group_id / "
        "equipment_id / instructions / is_custom / secondary_muscle_ids`\n"
        "- Form `image`: file 可选，新示范图片\n\n"
        "返回格式（200）：更新后的 ExerciseDetailResponse。\n\n"
        "错误码：403 非管理员；404 动作不存在。"
    ),
    response_description="更新后的动作详情。",
    responses={404: {"description": "动作不存在"}},
)
async def update_exercise(
    ex_id: int,
    request: Request,
    data: str = Form(
        ..., description="ExerciseUpdate 的 JSON 字符串，只传需要修改的字段"
    ),
    image: UploadFile | None = File(
        None, description="新的动作示范图片（可选，替换旧图片）"
    ),
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """更新指定动作

    - **data**: JSON 字符串，只传需要更新的字段
    - **image**: 可选，上传新图片会替换旧图片

    Raises:
        404: 动作不存在
    """
    exercise_data = ExerciseUpdate(**json.loads(data))
    exercise = await exercise_crud.update(db, ex_id, exercise_data)
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Exercise not found"
        )

    if image and image.filename:
        # 删除旧图片与旧缩略图
        if exercise.image_key:
            storage_service.delete(exercise.image_key)
        if exercise.thumb_key:
            storage_service.delete(exercise.thumb_key)
        image_key, thumb_key = storage_service.upload_with_thumbnail(image)
        exercise = await exercise_crud.set_image_keys(db, ex_id, image_key, thumb_key)

    return await _build_detail(db, exercise, request)


@router.delete(
    "/{ex_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="删除动作",
    description=(
        "仅管理员。根据 ID 删除动作，同时清理对象存储中的关联图片。\n\n"
        "请求格式（Path）：`ex_id` int 必填。\n\n"
        "返回格式：204 无响应体。\n\n"
        "错误码：403 非管理员；404 动作不存在。"
    ),
    response_description="删除成功，无响应体。",
    responses={
        204: {"description": "删除成功"},
        404: {"description": "动作不存在"},
    },
)
async def delete_exercise(
    ex_id: int,
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """删除指定动作，同时删除 RustFS 中的图片

    Args:
        ex_id: 动作 ID

    Raises:
        404: 动作不存在
    """
    exercise = await exercise_crud.get_by_id(db, ex_id)
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Exercise not found"
        )

    if exercise.image_key:
        storage_service.delete(exercise.image_key)
    if exercise.thumb_key:
        storage_service.delete(exercise.thumb_key)

    await exercise_crud.delete(db, ex_id)


# ponytail: simple joined lookup instead of a full service layer
async def _build_detail(
    db: AsyncSession, exercise, request: Request
) -> ExerciseDetailResponse:
    """组装动作详情 — 查询关联的肌群名、器械名、辅助肌群、稳定图片 URL"""
    mg = await muscle_group_crud.get_by_id(db, exercise.primary_muscle_group_id)
    eq = (
        await equipment_crud.get_by_id(db, exercise.equipment_id)
        if exercise.equipment_id
        else None
    )

    sec_ids = await exercise_crud.get_secondary_muscle_ids(db, exercise.id)
    sec_muscles = []
    for sid in sec_ids:
        smg = await muscle_group_crud.get_by_id(db, sid)
        if smg:
            sec_muscles.append(MuscleGroupResponse.model_validate(smg))

    thumb_key = exercise.thumb_key or exercise.image_key
    return ExerciseDetailResponse(
        id=exercise.id,
        name=exercise.name,
        name_en=exercise.name_en,
        exercise_type=exercise.exercise_type,
        primary_muscle_group_id=exercise.primary_muscle_group_id,
        equipment_id=exercise.equipment_id,
        instructions=exercise.instructions,
        is_custom=exercise.is_custom,
        created_at=exercise.created_at,
        primary_muscle_name=mg.name if mg else None,
        primary_muscle_name_en=mg.name_en if mg else None,
        equipment_name=eq.name if eq else None,
        equipment_name_en=eq.name_en if eq else None,
        secondary_muscles=sec_muscles,
        # 详情里 image_url 是原图（GIF 动图能播）；缩略图供小格使用
        image_url=(
            _image_url(request, exercise.id, exercise.image_key)
            if exercise.image_key
            else None
        ),
        thumb_url=(
            _image_url(request, exercise.id, thumb_key, thumb=True)
            if thumb_key
            else None
        ),
    )
