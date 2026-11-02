"""usermanagementrouter"""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.core.database import get_db
from app.core.deps import get_current_user, get_current_superuser
from app.crud.feed import follow_crud
from app.crud.profile import parse_tags, profile_crud, weight_log_crud
from app.crud.user import user_crud
from app.models.user import User
from app.schemas.profile import (
    ProfileEnvelope,
    ProfileMetricsResponse,
    ProfileResponse,
    ProfileUpsert,
    WeightHistoryResponse,
)
from app.schemas.user import (
    FollowStateResponse,
    UserListResponse,
    UserPublicResponse,
    UserResponse,
    UserUpdate,
)
from app.services.metrics import build_weight_history, compute_metrics

router = APIRouter(prefix="/users", tags=["Users"])


@router.get(
    "/me",
    response_model=UserResponse,
    summary="获取当前用户信息",
    description=(
        "需认证。返回当前登录用户的完整信息。\n\n"
        "请求格式：无参数，请求头 `Authorization: Bearer <access_token>`。\n\n"
        "返回格式（200）：UserResponse\n"
        '```json\n{"id": 1, "username": "johndoe", "email": '
        '"john@example.com", '
        '"is_active": true, "is_verified": true, "is_superuser": false, '
        '"created_at": "2026-01-01T08:00:00Z", "updated_at": '
        '"2026-01-01T08:00:00Z", '
        '"last_login_at": "2026-01-02T08:00:00Z"}\n```\n\n'
        "错误码：401 未认证。"
    ),
    response_description="当前用户信息。",
)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Getcurrentuserinformation

    Args:
        current_user: currentloginuser

    Returns:
        userinformation
    """
    return current_user


def _to_response(row) -> ProfileResponse:
    metrics = compute_metrics(
        gender=row.gender,
        birth_year=row.birth_year,
        height_cm=row.height_cm,
        weight_kg=row.weight_kg,
        goal=row.goal,
        experience=row.experience,
        weekly_days=row.weekly_days,
    )
    return ProfileResponse(
        user_id=row.user_id,
        gender=row.gender,
        birth_year=row.birth_year,
        height_cm=row.height_cm,
        weight_kg=row.weight_kg,
        goal=row.goal,
        experience=row.experience,
        injury_tags=parse_tags(row.injury_tags),
        weekly_days=row.weekly_days,
        session_minutes=row.session_minutes,
        equipment=row.equipment,
        preferences=parse_tags(row.preferences),
        updated_at=row.updated_at,
        metrics=ProfileMetricsResponse(
            age=metrics.age,
            bmr=metrics.bmr,
            tdee=metrics.tdee,
            calorie_target=metrics.calorie_target,
            max_hr=metrics.max_hr,
            activity_factor=metrics.activity_factor,
            split_name=metrics.split_name,
        ),
    )


@router.get(
    "/me/profile",
    response_model=ProfileEnvelope,
    summary="获取健身档案",
    description=(
        '需认证。未完成引导时返回 200 `{"complete": false, "profile": null}`，不返回 404。\n\n'
        "请求格式：无参数，请求头 `Authorization: Bearer <access_token>`。\n\n"
        "返回格式（200）：ProfileEnvelope\n"
        "- `complete`: bool 是否已完成引导\n"
        "- `profile`: object|null，含 `user_id / gender(male/female/undisclosed) / "
        "birth_year / "
        "height_cm / weight_kg / goal(fat_loss/muscle_gain/reshape/health/performance) "
        "/ "
        "experience(beginner/intermediate/advanced) / injury_tags[] / weekly_days / "
        "session_minutes / equipment(none/dumbbells/gym) / preferences[] / updated_at "
        "/ "
        "metrics{age/bmr/tdee/calorie_target/max_hr/activity_factor/split_name}`"
    ),
    response_description="健身档案（含服务端计算的身体指标）；未引导时 profile=null。",
)
async def get_my_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    row = await profile_crud.get_by_user(db, current_user.id)
    if not row:
        return ProfileEnvelope(complete=False, profile=None)
    return ProfileEnvelope(complete=True, profile=_to_response(row))


@router.put(
    "/me/profile",
    response_model=ProfileEnvelope,
    summary="提交/更新健身档案",
    description=(
        "需认证。引导页一次性提交；身高体重会同步写入体重流水。字段同时接受 camelCase/snake_case。\n\n"
        "请求格式（JSON Body）：\n"
        "- `gender`: string 必填 male/female/undisclosed\n"
        "- `birth_year`: int 必填 1926-2018\n"
        "- `height_cm`: float 必填 100-250；`weight_kg`: float 必填 30-300\n"
        "- `goal`: string 必填 fat_loss/muscle_gain/reshape/health/performance\n"
        "- `experience`: string 必填 beginner/intermediate/advanced\n"
        "- `injury_tags`: string[] 可选；`weekly_days`: int 可选 2-7\n"
        "- `session_minutes`: int 可选 15-180；`equipment`: string 可选 none/dumbbells/gym\n"
        "- `preferences`: string[] 可选\n\n"
        '```json\n{"gender": "male", "birthYear": 1995, "heightCm": 178, '
        '"weightKg": 75, '
        '"goal": "muscle_gain", "experience": "intermediate", "weeklyDays": '
        "4, "
        '"sessionMinutes": 60, "equipment": "gym"}\n```\n\n'
        '返回格式（200）：`{"complete": true, "profile": {...同GET...}}`'
    ),
    response_description="保存成功，返回 complete=true 及最新档案。",
)
async def upsert_my_profile(
    data: ProfileUpsert,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    row = await profile_crud.upsert(db, current_user.id, data)
    return ProfileEnvelope(complete=True, profile=_to_response(row))


@router.get(
    "/me/weight-history",
    response_model=WeightHistoryResponse,
    summary="体重历史与 7 日移动平均",
    description=(
        "需认证。返回近 N 天体重流水（按天归并，同日多条取均值），并计算 7 日前向填充移动平均，"
        "供客户端与 e1RM 力量曲线叠加观察（例：减脂期体重下降而 e1RM 维持 = 保肌成功）。\n\n"
        "请求格式（Query）：\n"
        "- `days`: int 默认 90，7-1095，统计窗口天数\n\n"
        '返回格式（200）：`{"period_days": 90, "points": [{"date": "2026-07-01", '
        '"weight_kg": 75.2, "ma7_kg": 75.3}...], "change_kg": -1.2, "records": 12}`\n\n'
        "注意：体重流水仅在档案中的体重值发生变化时写入，数据点天然稀疏；"
        "从未提交过健身档案时返回空列表（200，不 404）。"
    ),
    response_description="体重历史点（含 7 日移动平均）与窗口变化量。",
)
async def get_weight_history(
    days: int = Query(90, ge=7, le=1095, description="统计窗口天数"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    first_day = datetime.combine(
        now.date() - timedelta(days=days - 1), datetime.min.time()
    )
    rows = await weight_log_crud.list_since(db, current_user.id, first_day)
    data = build_weight_history(
        [(r.recorded_at, r.weight_kg) for r in rows], today=now.date(), days=days
    )
    return WeightHistoryResponse(**data)


@router.put(
    "/me",
    response_model=UserResponse,
    summary="更新当前用户信息",
    description=(
        "需认证。只传需要修改的字段；改用户名/邮箱时会校验唯一性。\n\n"
        "请求格式（JSON Body，均为可选）：\n"
        "- `username`: string 3-50 字符\n"
        "- `email`: string 邮箱格式\n"
        "- `password`: string 6-100 字符\n"
        "- `is_active`: bool\n\n"
        '```json\n{"username": "newname", "email": "new@example.com"}\n```\n\n'
        "返回格式（200）：更新后的 UserResponse。\n\n"
        "错误码：400 用户名/邮箱已被占用；404 用户不存在。"
    ),
    response_description="更新后的用户信息。",
)
async def update_current_user(
    user_update: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """updatecurrentuserinformation

    Args:
        user_update: user update data
        current_user: currentloginuser
        db: Database session

    Returns:
        updateafteruserinformation

    Raises:
        HTTPException: updatefailure
    """
    # ifupdateUsername，Checkwhetheralreadyexists
    if user_update.username and user_update.username != current_user.username:
        existing_user = await user_crud.get_by_username(db, user_update.username)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="Username already taken"
            )

    # ifupdateEmail，Checkwhetheralreadyexists
    if user_update.email and user_update.email != current_user.email:
        existing_user = await user_crud.get_by_email(db, user_update.email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered",
            )

    updated_user = await user_crud.update(db, current_user.id, user_update)

    if not updated_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    return updated_user


@router.delete(
    "/me",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="注销当前账号",
    description=(
        "需认证。删除当前登录用户账号，操作不可恢复。\n\n"
        "请求格式：无请求体，请求头 `Authorization: Bearer <access_token>`。\n\n"
        "返回格式：204 无响应体。\n\n"
        "错误码：404 用户不存在。"
    ),
    response_description="注销成功，无响应体。",
)
async def delete_current_user(
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    """Delete current user account

    Args:
        current_user: currentloginuser
        db: Database session

    Raises:
        HTTPException: Deletefailure
    """
    success = await user_crud.delete(db, current_user.id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )


# ========== 社交路由（必须在管理员 `/{user_id}` 之前注册） ==========


async def _public_users(
    db: AsyncSession, users: list[User], viewer_id: int
) -> list[UserPublicResponse]:
    following = await follow_crud.list_following_ids(db, viewer_id)
    return [
        UserPublicResponse(id=u.id, username=u.username, is_following=u.id in following)
        for u in users
    ]


async def _get_active_user(db: AsyncSession, user_id: int) -> User:
    user = await user_crud.get_by_id(db, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.get(
    "/search",
    response_model=UserListResponse,
    summary="搜索用户",
    description=(
        "需认证。按用户名模糊搜索（不区分大小写），排除自己与已停用账号，按用户名升序。\n\n"
        "请求格式（Query）：\n"
        "- `q`: string 必填，1-50 字符\n"
        "- `skip`: int 默认 0；`limit`: int 1-100 默认 20\n\n"
        "返回格式（200）：`{items: [{id, username, is_following}], total}`，"
        "`is_following` 表示当前用户是否已关注 TA（关注按钮直接用）。"
    ),
    response_description="匹配的用户分页列表。",
)
async def search_users(
    q: str = Query(..., min_length=1, max_length=50, description="用户名关键词"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """按用户名搜索用户（排除自己与停用账号）"""
    users, total = await follow_crud.search_users(db, q, current_user.id, skip, limit)
    return UserListResponse(
        items=await _public_users(db, users, current_user.id), total=total
    )


@router.post(
    "/{user_id}/follow",
    response_model=FollowStateResponse,
    summary="关注用户",
    description=(
        "需认证。幂等：已关注时重复调用不报错。\n\n"
        "请求格式（Path）：`user_id` int 必填。\n\n"
        "返回格式（200）：`{user_id, following: true, followers_count}`。\n\n"
        "错误码：400 不能关注自己；404 目标用户不存在或已停用。"
    ),
    response_description="关注成功（或已关注），返回最新关注状态。",
)
async def follow_user(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """关注用户（幂等）"""
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")
    await _get_active_user(db, user_id)
    await follow_crud.follow(db, current_user.id, user_id)
    return FollowStateResponse(
        user_id=user_id,
        following=True,
        followers_count=await follow_crud.count_followers(db, user_id),
    )


@router.delete(
    "/{user_id}/follow",
    response_model=FollowStateResponse,
    summary="取消关注",
    description=(
        "需认证。幂等：未关注时调用不报错。\n\n"
        "请求格式（Path）：`user_id` int 必填。\n\n"
        "返回格式（200）：`{user_id, following: false, followers_count}`。\n\n"
        "错误码：404 目标用户不存在或已停用。"
    ),
    response_description="已取消关注（幂等），返回最新关注状态。",
)
async def unfollow_user(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """取消关注（幂等）"""
    await _get_active_user(db, user_id)
    await follow_crud.unfollow(db, current_user.id, user_id)
    return FollowStateResponse(
        user_id=user_id,
        following=False,
        followers_count=await follow_crud.count_followers(db, user_id),
    )


@router.get(
    "/{user_id}/followers",
    response_model=UserListResponse,
    summary="粉丝列表",
    description=(
        "需认证。返回关注了 `user_id` 的用户，按用户名升序。\n\n"
        "请求格式（Path + Query）：`user_id` int 必填；`skip` ≥0；`limit` 1-100 默认 20。\n\n"
        "返回格式（200）：`{items: [{id, username, is_following}], total}`，"
        "`is_following` 相对当前登录用户。\n\n"
        "错误码：404 用户不存在或已停用。"
    ),
    response_description="粉丝分页列表。",
)
async def list_followers(
    user_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """某用户的粉丝列表"""
    await _get_active_user(db, user_id)
    users, total = await follow_crud.list_followers(db, user_id, skip, limit)
    return UserListResponse(
        items=await _public_users(db, users, current_user.id), total=total
    )


@router.get(
    "/{user_id}/following",
    response_model=UserListResponse,
    summary="关注列表",
    description=(
        "需认证。返回 `user_id` 关注的用户，按用户名升序。\n\n"
        "请求格式（Path + Query）：`user_id` int 必填；`skip` ≥0；`limit` 1-100 默认 20。\n\n"
        "返回格式（200）：`{items: [{id, username, is_following}], total}`，"
        "`is_following` 相对当前登录用户。\n\n"
        "错误码：404 用户不存在或已停用。"
    ),
    response_description="关注分页列表。",
)
async def list_following(
    user_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """某用户关注的人列表"""
    await _get_active_user(db, user_id)
    users, total = await follow_crud.list_following(db, user_id, skip, limit)
    return UserListResponse(
        items=await _public_users(db, users, current_user.id), total=total
    )


# ========== Admin routes ==========


@router.get(
    "/",
    response_model=List[UserResponse],
    summary="用户列表（仅管理员）",
    description=(
        "需管理员认证（is_superuser=true）。分页返回全部用户。\n\n"
        "请求格式（Query）：\n"
        "- `skip`: int 默认 0，分页偏移量\n"
        "- `limit`: int 默认 100，每页条数\n\n"
        "返回格式（200）：UserResponse 数组。\n\n"
        "错误码：403 非管理员。"
    ),
    response_description="用户列表。",
)
async def list_users(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """Get user list (admin only)

    Args:
        skip: skip count
        limit: return max count
        current_user: current logged in admin user
        db: Database session

    Returns:
        userlist
    """
    users = await user_crud.get_all(db, skip=skip, limit=limit)
    return users


@router.get(
    "/{user_id}",
    response_model=UserResponse,
    summary="查询指定用户（仅管理员）",
    description=(
        "需管理员认证。\n\n"
        "请求格式（Path）：\n"
        "- `user_id`: int 必填，用户 ID\n\n"
        "返回格式（200）：UserResponse。\n\n"
        "错误码：403 非管理员；404 用户不存在。"
    ),
    response_description="指定用户信息。",
)
async def get_user(
    user_id: int,
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """Get specified user information (admin only)

    Args:
        user_id: user ID
        current_user: current logged in admin user
        db: Database session

    Returns:
        userinformation

    Raises:
        HTTPException: user does not exist
    """
    user = await user_crud.get_by_id(db, user_id)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    return user


@router.put(
    "/{user_id}",
    response_model=UserResponse,
    summary="更新指定用户（仅管理员）",
    description=(
        "需管理员认证。\n\n"
        "请求格式：\n"
        "- Path：`user_id` int 必填\n"
        "- JSON Body（均为可选）：`username / email / password / is_active`\n\n"
        '```json\n{"is_active": false}\n```\n\n'
        "返回格式（200）：更新后的 UserResponse。\n\n"
        "错误码：403 非管理员；404 用户不存在。"
    ),
    response_description="更新后的用户信息。",
)
async def update_user(
    user_id: int,
    user_update: UserUpdate,
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """Update specified user information (admin only)

    Args:
        user_id: user ID
        user_update: user update data
        current_user: current logged in admin user
        db: Database session

    Returns:
        updateafteruserinformation

    Raises:
        HTTPException: user does not exist or update failed
    """
    updated_user = await user_crud.update(db, user_id, user_update)

    if not updated_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    return updated_user


@router.delete(
    "/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="删除指定用户（仅管理员）",
    description=(
        "需管理员认证。管理员不能删除自己。\n\n"
        "请求格式（Path）：`user_id` int 必填。\n\n"
        "返回格式：204 无响应体。\n\n"
        "错误码：400 不能删除自己；403 非管理员；404 用户不存在。"
    ),
    response_description="删除成功，无响应体。",
)
async def delete_user(
    user_id: int,
    current_user: User = Depends(get_current_superuser),
    db: AsyncSession = Depends(get_db),
):
    """Delete specified user (admin only)

    Args:
        user_id: user ID
        current_user: current logged in admin user
        db: Database session

    Raises:
        HTTPException: user does not exist or delete failed
    """
    # Prevent admin from deleting themselves
    if user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot delete yourself"
        )

    success = await user_crud.delete(db, user_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )
