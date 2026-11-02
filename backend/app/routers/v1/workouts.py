"""训练会话 & 训练记录接口"""

from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.crud.one_rm import blend_stored_samples, one_rm_crud
from app.crud.profile import profile_crud
from app.crud.recovery import recovery_crud
from app.crud.workout import session_crud, set_crud
from app.models.user import User
from app.schemas.workout import (
    BatchLastPerformanceResponse,
    ExerciseStatsResponse,
    LastPerformanceResponse,
    LastSessionSetsResponse,
    MuscleGroupStatusItem,
    MuscleGroupStatusResponse,
    MuscleVolume,
    OneRmHistoryPoint,
    OneRmHistoryResponse,
    OneRmResponse,
    RpeRecommendRequest,
    RpeRecommendResponse,
    SessionComplete,
    SessionCreate,
    SessionDetailResponse,
    SessionResponse,
    StatsOverviewResponse,
    StrengthStandardsResponse,
    VolumeLandmarkItem,
    VolumeLandmarksResponse,
    WeeklyVolumeResponse,
    WeekVolumeResponse,
    WorkoutSetResponse,
)
from app.services.exercise_stats import build_exercise_stats
from app.services.rpe import recommend_next_set
from app.services.stats_overview import build_stats_overview
from app.services.strength import (
    WeekVolume,
    build_weekly_report,
    estimate_1rm,
    should_suggest_deload,
    week_monday,
)
from app.services.strength_standards import (
    PUSH_PULL_WINDOW_DAYS,
    build_strength_standards,
)
from app.services.volume_landmarks import volume_landmarks

session_router = APIRouter(prefix="/sessions", tags=["Training Sessions"])


@session_router.post(
    "",
    response_model=SessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="创建训练会话",
    description=(
        "需认证。开始训练时轻量创建，仅需客户端 UUID + 开始时间；同 UUID 重复请求幂等返回已有记录。\n\n"
        "请求格式（JSON Body，兼容 camelCase/snake_case）：\n"
        "- `client_uuid`: string 必填，≤36 字符，客户端生成的幂等键\n"
        "- `started_at`: datetime 必填，训练开始时间\n"
        "- `template_id`: int 可选，来源模板 ID\n\n"
        '```json\n{"clientUuid": "550e8400-e29b-41d4-a716-446655440000", '
        '"startedAt": "2026-01-01T08:00:00Z", "templateId": 3}\n```\n\n'
        "返回格式（201）：SessionResponse，字段 `id / client_uuid / user_id / "
        "status(in_progress) "
        "/ "
        "started_at / completed_at(null) / notes / template_id / created_at / "
        "updated_at`。"
    ),
    response_description="创建成功（或幂等返回已有会话）。",
)
async def create_session(
    data: SessionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """创建训练会话（幂等：同UUID重复请求返回已有记录）"""
    session = await session_crud.create(db, data, current_user.id)
    return session


@session_router.put(
    "/{session_id}/complete",
    response_model=SessionDetailResponse,
    summary="结束训练",
    description=(
        "需认证。训练结束时批量上传完整数据（session 信息 + 所有 sets 数组），单事务写入；"
        "每个 set 按 client_uuid 幂等。\n\n"
        "请求格式：\n"
        "- Path：`session_id` int 必填\n"
        "- JSON Body：`client_uuid`(必填，须与创建时一致) / `started_at` / `completed_at` / "
        "`notes` / `template_id` / `sets[]`，每组含 `client_uuid`(必填) / `exercise_id` / "
        "`set_number`(≥1) / `reps / weight_kg / duration_seconds / distance_meters / "
        "rpe(0.5-10) / notes / completed_at`\n\n"
        '```json\n{"clientUuid": "550e8400-...", "startedAt": '
        '"2026-01-01T08:00:00Z", '
        '"completedAt": "2026-01-01T09:00:00Z", "sets": [{"clientUuid": '
        '"...", '
        '"exerciseId": 1, "setNumber": 1, "reps": 10, "weightKg": 60, "rpe": '
        "8}]}\n```\n\n"
        "返回格式（200）：SessionDetailResponse（SessionResponse + `sets[]` 完整训练组）。\n\n"
        "错误码：404 会话不存在或不属于当前用户。"
    ),
    response_description="训练结束并落库，返回含全部组的会话详情。",
)
async def complete_session(
    session_id: int,
    data: SessionComplete,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """结束训练，批量上传完整数据"""
    session = await session_crud.complete_session(db, session_id, current_user.id, data)
    sets = await set_crud.get_by_session(db, session.id)
    detail = SessionDetailResponse.model_validate(session)
    detail.sets = [WorkoutSetResponse.model_validate(s) for s in sets]
    return detail


@session_router.get(
    "",
    response_model=dict,
    summary="获取训练历史列表",
    description=(
        "需认证。分页获取当前用户的训练历史，支持状态与日期筛选。\n\n"
        "请求格式（Query）：\n"
        "- `skip`: int 默认 0；`limit`: int 默认 20，1-100\n"
        "- `status`: string 可选 in_progress/completed\n"
        "- `start_date`: datetime 可选；`end_date`: datetime 可选\n\n"
        '返回格式（200）：`{"items": [SessionResponse...], "total": 数量}`'
    ),
    response_description="训练历史分页列表。",
)
async def list_sessions(
    skip: int = Query(0, ge=0, description="分页偏移量"),
    limit: int = Query(20, ge=1, le=100, description="每页条数"),
    status_filter: Optional[str] = Query(
        None, alias="status", description="状态筛选：in_progress / completed"
    ),
    start_date: Optional[datetime] = Query(None, description="开始日期（含）"),
    end_date: Optional[datetime] = Query(None, description="结束日期（含）"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """分页获取当前用户训练历史"""
    items, total = await session_crud.get_all_by_user(
        db,
        user_id=current_user.id,
        status=status_filter,
        start_date=start_date,
        end_date=end_date,
        skip=skip,
        limit=limit,
    )
    return {
        "items": [SessionResponse.model_validate(s) for s in items],
        "total": total,
    }


@session_router.get(
    "/in-progress",
    response_model=SessionResponse,
    summary="查询未完成的训练",
    description=(
        "需认证。查询当前用户是否有 status=in_progress 的会话，用于 App 冷启动恢复提示。\n\n"
        "请求格式：无参数，请求头 `Authorization: Bearer <access_token>`。\n\n"
        "返回格式（200）：SessionResponse。\n\n"
        "错误码：404 当前无未完成的训练。"
    ),
    response_description="未完成的训练会话。",
)
async def get_in_progress(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """查询未完成的训练"""
    session = await session_crud.get_in_progress(db, current_user.id)
    if not session:
        raise HTTPException(404, "No in-progress session found")
    return session


@session_router.get(
    "/{session_id}",
    response_model=SessionDetailResponse,
    summary="获取训练详情",
    description=(
        "需认证。获取单次训练完整信息（含所有训练组），仅可查看自己的记录。\n\n"
        "请求格式（Path）：`session_id` int 必填。\n\n"
        "返回格式（200）：SessionDetailResponse，每组含 `id / client_uuid / session_id / "
        "exercise_id / "
        "set_number / reps / weight_kg / duration_seconds / distance_meters / rpe / "
        "notes / completed_at / created_at`。\n\n"
        "错误码：404 会话不存在或不属于当前用户。"
    ),
    response_description="单次训练的完整详情。",
)
async def get_session(
    session_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取单次训练详情"""
    session = await session_crud.get_by_id(db, session_id)
    if not session or session.user_id != current_user.id:
        raise HTTPException(404, "Session not found")
    sets = await set_crud.get_by_session(db, session.id)
    detail = SessionDetailResponse.model_validate(session)
    detail.sets = [WorkoutSetResponse.model_validate(s) for s in sets]
    return detail


@session_router.delete(
    "/{session_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="删除训练记录",
    description=(
        "需认证。删除某次训练及其所有训练组，仅可删除自己的记录。\n\n"
        "请求格式（Path）：`session_id` int 必填。\n\n"
        "返回格式：204 无响应体。\n\n"
        "错误码：404 会话不存在或不属于当前用户。"
    ),
    response_description="删除成功，无响应体。",
)
async def delete_session(
    session_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """删除训练记录"""
    session = await session_crud.get_by_id(db, session_id)
    if not session or session.user_id != current_user.id:
        raise HTTPException(404, "Session not found")
    await session_crud.delete(db, session_id)


# ========== Performance Query Endpoints ==========

performance_router = APIRouter(tags=["Training Performance"])


@performance_router.get(
    "/exercises/{ex_id}/last-performance",
    response_model=LastPerformanceResponse,
    summary="获取上一次训练记录",
    description=(
        "需认证。返回某动作最近一次训练的单组数据（重量/次数/日期），训练中用于参考上次表现。\n\n"
        "请求格式（Path）：`ex_id` int 必填，动作 ID。\n\n"
        '返回格式（200）：`{"exercise_id": 1, "set_number": 3, "reps": 10, '
        '"weight_kg": 60, '
        '"duration_seconds": null, "distance_meters": null, "completed_at": '
        '"...", '
        '"session_date": "...", "rpe": 8}`\n\n'
        "错误码：404 该动作暂无历史记录。"
    ),
    response_description="该动作最近一次的单组表现。",
)
async def get_last_performance(
    ex_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取某动作上一次训练记录"""
    perf = await set_crud.get_last_performance(db, ex_id, current_user.id)
    if not perf:
        raise HTTPException(404, "No previous performance found for this exercise")
    return perf


@performance_router.get(
    "/exercises/{ex_id}/last-session-sets",
    response_model=LastSessionSetsResponse,
    summary="获取某动作上一次训练的完整组数据",
    description=(
        "需认证。返回某动作最近一次训练会话的全部组数据，用于训练中添加该动作时自动预填（幽灵组）。\n\n"
        "请求格式（Path）：`ex_id` int 必填。\n\n"
        '返回格式（200）：`{"exercise_id": 1, "session_id": 10, "session_date": '
        '"...", '
        '"sets": [WorkoutSetResponse...]}`\n\n'
        "错误码：404 该动作暂无历史会话。"
    ),
    response_description="该动作上一次会话的完整组数据。",
)
async def get_last_session_sets(
    ex_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取某动作上一次训练的完整组数据"""
    data = await set_crud.get_last_session_sets(db, ex_id, current_user.id)
    if not data:
        raise HTTPException(404, "No previous session found for this exercise")
    return data


@performance_router.get(
    "/exercises/{ex_id}/stats",
    response_model=ExerciseStatsResponse,
    summary="动作数据图表",
    description=(
        "需认证。按周期聚合最大重量/容量/次数曲线，并附个人纪录与最近会话明细。\n\n"
        "请求格式：\n"
        "- Path：`ex_id` int 必填\n"
        "- Query：`days` int 默认 30，7-365，统计窗口天数\n\n"
        "返回格式（200）：ExerciseStatsResponse，字段 `exercise_id / period_days / period_label "
        "/ "
        "axis[](横轴) / "
        "max_weight{value/points[]} / total_volume / max_reps / total_reps / "
        "records{max_weight_kg/max_reps/max_set_volume/estimated_1rm_kg/session_count/first_at/last_at} / "
        "history[{session_id/started_at/completed_at/sets[]}]`。"
    ),
    response_description="该动作的图表聚合数据。",
)
async def get_exercise_stats(
    ex_id: int,
    days: int = Query(30, ge=7, le=365, description="统计窗口天数，默认上个月"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    rows = await set_crud.list_exercise_set_rows(db, ex_id, current_user.id)
    one = await one_rm_crud.get(db, current_user.id, ex_id)
    estimated = None
    if one is not None:
        blended = blend_stored_samples(one.samples)
        estimated = blended.estimated_kg or one.estimated_kg
    return build_exercise_stats(
        rows,
        exercise_id=ex_id,
        period_days=days,
        estimated_1rm_kg=estimated,
    )


@performance_router.get(
    "/exercises/{ex_id}/history",
    response_model=dict,
    summary="获取动作历史记录",
    description=(
        "需认证。分页返回某动作的历史训练组列表，用于画进度曲线。\n\n"
        "请求格式：\n"
        "- Path：`ex_id` int 必填\n"
        "- Query：`skip` 默认 0；`limit` 默认 20，1-100\n\n"
        '返回格式（200）：`{"items": [WorkoutSetResponse...], "total": 数量}`'
    ),
    response_description="该动作的历史训练组分页列表。",
)
async def get_exercise_history(
    ex_id: int,
    skip: int = Query(0, ge=0, description="分页偏移量"),
    limit: int = Query(20, ge=1, le=100, description="每页条数"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """某动作历史训练记录"""
    items, total = await set_crud.get_exercise_history(
        db, ex_id, current_user.id, skip=skip, limit=limit
    )
    return {
        "items": [WorkoutSetResponse.model_validate(s) for s in items],
        "total": total,
    }


@performance_router.get(
    "/sync/last-performances",
    response_model=BatchLastPerformanceResponse,
    summary="批量获取最近训练记录",
    description=(
        "需认证。一次性拉取多个常用动作的最新记录，供 App 登录后/联网时批量刷新本地缓存。\n\n"
        "请求格式（Query）：\n"
        "- `exercise_ids`: string 必填，逗号分隔的 ID 列表，如 `1,3,5,7`\n\n"
        '返回格式（200）：`{"performances": {"1": LastPerformanceResponse|null, ...}}`，'
        "key 为动作 ID，无记录时 value 为 null。"
    ),
    response_description="多动作的最新记录映射表。",
)
async def batch_last_performances(
    exercise_ids: str = Query(..., description="逗号分隔的动作ID列表，如 '1,3,5,7'"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """批量获取所有常用动作的最新记录"""
    ids = [int(x.strip()) for x in exercise_ids.split(",") if x.strip()]
    perfs = await set_crud.get_batch_last_performances(db, ids, current_user.id)
    return BatchLastPerformanceResponse(performances=perfs)


@performance_router.post(
    "/rpe/recommend",
    response_model=RpeRecommendResponse,
    summary="根据 RPE 给出下一组建议",
    description=(
        "需认证（纯计算，不查库）。训练中完成本组并提交 RPE 后调用；"
        "甜蜜区（RPE 8.0）上调约 2.5%，红区（RPE ≥ 9.5）额外休息 60 秒。"
        "第一次力竭（RPE 10）按次数表把同样次数折到目标余力；"
        "没记次数时复合降 5%、孤立降 7.5%。同一动作再力竭不再给新重量。"
        "客户端离线时应使用同一套本地规则。\n\n"
        "请求格式（JSON Body，兼容 camelCase/snake_case）：\n"
        "- `weight_kg`: float 必填 >0，本组重量\n"
        "- `rpe`: float 必填 0.5-10\n"
        "- `reps`: int 可选，力竭时用来查 RPE 表\n"
        "- `one_rm_kg`: float 可选，当前估算 1RM\n"
        "- `exercise_type`: string 默认 compound，仅取 compound/isolation\n"
        "- `prior_rpes`: float[] 可选；`goal`: string 可选\n\n"
        '```json\n{"weightKg": 60, "rpe": 9.5, "reps": 8, "exerciseType": '
        '"compound"}\n```\n\n'
        '返回格式（200）：`{"suggested_weight_kg": 61.5, "extra_rest_seconds": 60, '
        '"fatigue_warning": false, "reduce_remaining_factor": null, "message": '
        '"...", '
        '"reason": "...", "capped_by_1rm": false, "zone": [7.5, 8.5]}`'
    ),
    response_description="下一组的重量/休息/疲劳预警建议。",
)
async def recommend_rpe(
    data: RpeRecommendRequest,
    current_user: User = Depends(get_current_user),
):
    """根据本组重量与 RPE 计算自动调节建议。"""
    _ = current_user
    advice = recommend_next_set(
        weight_kg=data.weight_kg,
        rpe=data.rpe,
        reps=data.reps,
        one_rm_kg=data.one_rm_kg,
        exercise_type=data.exercise_type,
        prior_rpes=data.prior_rpes,
        goal=data.goal,
    )
    return RpeRecommendResponse(
        suggested_weight_kg=advice.suggested_weight_kg,
        extra_rest_seconds=advice.extra_rest_seconds,
        fatigue_warning=advice.fatigue_warning,
        reduce_remaining_factor=advice.reduce_remaining_factor,
        message=advice.message,
        reason=advice.reason,
        capped_by_1rm=advice.capped_by_1rm,
        zone=list(advice.zone) if advice.zone else None,
    )


@performance_router.get(
    "/exercises/{ex_id}/one-rm",
    response_model=OneRmResponse,
    summary="动作估算 1RM",
    description=(
        "需认证。返回某动作当前估算的 1RM（已融合多样本并判断是否需重新校准）。\n\n"
        "请求格式（Path）：`ex_id` int 必填。\n\n"
        '返回格式（200）：`{"exercise_id": 1, "estimated_kg": 100.0, '
        '"needs_recalibrate": false, "samples_count": 5}`\n\n'
        "错误码：404 暂无该动作的 1RM 估算。"
    ),
    response_description="该动作的 1RM 估算结果。",
)
async def get_one_rm(
    ex_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    row = await one_rm_crud.get(db, current_user.id, ex_id)
    if not row:
        raise HTTPException(status_code=404, detail="No estimated 1RM yet")
    blended = blend_stored_samples(row.samples)
    estimated = blended.estimated_kg
    if estimated is None:
        estimated = row.estimated_kg
    return OneRmResponse(
        exercise_id=ex_id,
        estimated_kg=estimated,
        needs_recalibrate=blended.stale,
        samples_count=blended.samples_count,
    )


@performance_router.get(
    "/exercises/{ex_id}/one-rm/history",
    response_model=OneRmHistoryResponse,
    summary="由历史组反推的 1RM 时间序列",
    description=(
        "需认证。遍历历史组（仅 reps ≤ 10 的组参与 Epley/RPE 反推），生成 1RM 进步曲线。\n\n"
        "请求格式：\n"
        "- Path：`ex_id` int 必填\n"
        "- Query：`skip` 默认 0；`limit` 默认 50，1-100\n\n"
        '返回格式（200）：`{"items": [{"date": "...", "estimated_kg": 95.5, '
        '"rpe": 8, "source_set_id": 123}...]}`'
    ),
    response_description="1RM 时间序列点列表。",
)
async def get_one_rm_history(
    ex_id: int,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    items, _total = await set_crud.get_exercise_history(
        db, ex_id, current_user.id, skip=skip, limit=limit
    )
    points: list[OneRmHistoryPoint] = []
    for s in items:
        if s.reps is None or s.reps > 10:
            continue
        est = estimate_1rm(s.weight_kg, s.reps, s.rpe)
        if est is None:
            continue
        when = s.completed_at or s.created_at
        points.append(
            OneRmHistoryPoint(
                date=when,
                estimated_kg=round(est, 1),
                rpe=s.rpe,
                source_set_id=s.id,
            )
        )
    return OneRmHistoryResponse(items=points)


@performance_router.get(
    "/volume/weekly",
    response_model=WeeklyVolumeResponse,
    summary="近 8 周训练容量与 Deload 建议",
    description=(
        "需认证。按自然周（周一开头）聚合近 8 周总容量/高强度容量/高强度组数/平均 RPE（含肌群分布），"
        "并判断是否建议减载（deload）。\n\n"
        "请求格式：无参数，请求头 `Authorization: Bearer <access_token>`。\n\n"
        '返回格式（200）：`{"weeks": [{"week_start": "2026-01-05", "volume": 12000, '
        '"hard_volume": 3000, "hard_sets": 20, "avg_rpe": 8.1, '
        '"by_muscle": [{"name": "胸部", "volume": 3000, "hard_sets": 8}]...}], '
        '"suggest_deload": false, "deload_reason": null}`'
    ),
    response_description="近 8 周容量报告与减载建议。",
)
async def get_weekly_volume(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    today = datetime.now(timezone.utc).date()
    since = datetime.combine(
        week_monday(today) - timedelta(weeks=7), datetime.min.time()
    )
    rows = await one_rm_crud.list_completed_set_loads(db, current_user.id, since)
    reports = build_weekly_report(rows, today)
    suggest, reason = should_suggest_deload(
        [
            WeekVolume(
                week_start=w.week_start,
                volume=w.volume,
                hard_volume=w.hard_volume,
                hard_sets=w.hard_sets,
                avg_rpe=w.avg_rpe,
            )
            for w in reports
        ]
    )
    return WeeklyVolumeResponse(
        weeks=[
            WeekVolumeResponse(
                week_start=w.week_start.isoformat(),
                volume=w.volume,
                hard_volume=w.hard_volume,
                hard_sets=w.hard_sets,
                avg_rpe=w.avg_rpe,
                by_muscle=[
                    MuscleVolume(name=m.name, volume=m.volume, hard_sets=m.hard_sets)
                    for m in w.by_muscle
                ],
            )
            for w in reports
        ],
        suggest_deload=suggest,
        deload_reason=reason,
    )


@performance_router.get(
    "/stats/overview",
    response_model=StatsOverviewResponse,
    summary="数据页总览",
    description=(
        "需认证。数据页总览：按窗口聚合训练次数/容量/时长/打卡日/肌群分布/近期 PR/常练动作。\n\n"
        "请求格式（Query）：\n"
        "- `days`: int 默认 30，7-365，统计窗口天数\n\n"
        '返回格式（200）：`{"period_days": 30, "period_label": "近30天", '
        '"sessions_count": 12, '
        '"total_volume_kg": 36000, "total_duration_seconds": 21600, "avg_rpe": '
        "8.0, "
        '"hard_sets": 80, "trained_days": ["2026-01-01"...], '
        '"by_muscle": [{"name": "胸部", "volume": 8000, "hard_sets": 20}...], '
        '"recent_prs": [{"exercise_id": 1, "name": "杠铃卧推", "kind": '
        '"weight", "value": 100, "at": "..."}...], '
        '"top_exercises": [{"exercise_id": 1, "name": "杠铃卧推", "sessions": 8, '
        '"volume": 9000, "estimated_1rm_kg": 100}...]}`'
    ),
    response_description="指定窗口的数据总览。",
)
async def get_stats_overview(
    days: int = Query(30, ge=7, le=365, description="统计窗口天数"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    since = now - timedelta(days=days)
    sessions = await set_crud.list_completed_sessions_since(db, current_user.id, since)
    set_rows = await set_crud.list_period_set_rows(db, current_user.id, since)
    lifetime = await set_crud.list_lifetime_weight_sets(db, current_user.id)
    one_rms = await one_rm_crud.list_estimated_map(db, current_user.id)
    data = build_stats_overview(
        sessions,
        set_rows,
        lifetime,
        one_rms,
        period_days=days,
        now=now,
    )
    return StatsOverviewResponse(**data)


@performance_router.get(
    "/muscle-groups/status",
    response_model=MuscleGroupStatusResponse,
    summary="肌群恢复状态",
    description=(
        "需认证。根据训练历史推断各肌群恢复进度：实际窗口 = 文献基线 × 全局恢复系数 × 单肌群恢复系数；"
        "系数仅在有效高频观察足够时偏离 1.0。\n\n"
        "请求格式：无参数，请求头 `Authorization: Bearer <access_token>`。\n\n"
        '返回格式（200）：`{"items": [{"muscle_group_id": 1, "name": "胸部", '
        '"name_en": "Chest", '
        '"category": "upper", "last_trained_at": "...", "hours_since_last": '
        "30, "
        '"recovery_progress": 0.8, "recovery_window_hours": 48, '
        '"baseline_window_hours": 48, '
        '"recovery_factor": 1.0, "global_factor": 1.0, "muscle_factor": 1.0, '
        '"recovery_confidence": "high", "observations_count": 10}...], '
        '"global_factor": 1.0, "global_observations_count": 50, '
        '"global_confidence": "high"}`'
    ),
    response_description="各肌群恢复进度与全局恢复系数。",
)
async def get_muscle_group_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    data = await recovery_crud.list_status(db, current_user.id)
    return MuscleGroupStatusResponse(
        items=[MuscleGroupStatusItem(**s.__dict__) for s in data["items"]],
        global_factor=data["global_factor"],
        global_observations_count=data["global_observations_count"],
        global_confidence=data["global_confidence"],
    )


@performance_router.get(
    "/volume/landmarks",
    response_model=VolumeLandmarksResponse,
    summary="本周肌群容量地标（MEV/MAV/MRV）",
    description=(
        "需认证。返回当前自然周（周一起始）各肌群 hard set（RPE≥8 的工作组/递减组）数量"
        "及其所处的生理区间：`below_mev`（低于最小有效容量）/ `mev` / `mav`（最佳适应区）/ "
        "`above_mrv`。常量表未收录的肌群使用保守默认值并标记 `is_default=true`。\n\n"
        "请求格式：无参数，请求头 `Authorization: Bearer <access_token>`。\n\n"
        '返回格式（200）：`{"week_start": "2026-10-12", "week_volume": 8000, '
        '"hard_sets": 14, "items": [{"name": "胸部", "hard_sets": 14, '
        '"zone": "mav", "mv": 8, "mev": 10, "mav_low": 12, "mav_high": 20, '
        '"mrv": 22, "is_default": false}...]}`\n\n'
        "注意：hard set 只统计填写了 RPE≥8 的组，未记录 RPE 的训练不会计入。"
    ),
    response_description="本周各肌群 hard set 数与 MEV/MAV/MRV 区间。",
)
async def get_volume_landmarks(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    today = datetime.now(timezone.utc).date()
    since = datetime.combine(week_monday(today), datetime.min.time())
    rows = await one_rm_crud.list_completed_set_loads(db, current_user.id, since)
    week = build_weekly_report(rows, today, n_weeks=1)[0]
    trained = {m.name: m.hard_sets for m in week.by_muscle}
    return VolumeLandmarksResponse(
        week_start=week.week_start.isoformat(),
        week_volume=week.volume,
        hard_sets=week.hard_sets,
        items=[VolumeLandmarkItem(**item) for item in volume_landmarks(trained)],
    )


@performance_router.get(
    "/stats/strength-standards",
    response_model=StrengthStandardsResponse,
    summary="相对力量与体型对称度",
    description=(
        "需认证。结合档案体重与各动作估算 1RM，返回倍体重比、三大项（深蹲/卧推/硬拉）"
        "总和及 Dots / Wilks 力量系数，以及近 28 天推/拉肌群容量比（Push:Pull Ratio）。\n\n"
        "请求格式：无参数，请求头 `Authorization: Bearer <access_token>`。\n\n"
        '返回格式（200）：`{"has_profile": true, "gender": "male", "bodyweight_kg": 75, '
        '"relative_strength": [{"exercise_id": 1, "name": "杠铃卧推", '
        '"name_en": "Barbell Bench Press", "estimated_1rm_kg": 100, "ratio": 1.33, '
        '"is_big_three": true, "lift": "bench"}...], '
        '"big_three": {"squat": {...}, "bench": {...}, "deadlift": {...}, '
        '"total_kg": 340, "complete": true, "missing": []}, '
        '"dots": 243.9, "wilks": 242.3, '
        '"push_pull": {"window_days": 28, "push_volume_kg": 12000, '
        '"pull_volume_kg": 10000, "push_hard_sets": 20, "pull_hard_sets": 18, '
        '"ratio": 1.2, "verdict": "balanced"}}`\n\n'
        "边界：未提交档案时 `has_profile=false`、倍体重比与系数均为 null（200，不 404）；"
        "性别为 undisclosed 时 Dots/Wilks 为 null；三大项不全时 `total_kg`/系数为 null 并在 "
        "`missing` 列出缺失项。推拉比按主肌群聚合（卧推的辅助肌群不计入）。"
    ),
    response_description="倍体重比、三大项总和与力量系数、推拉容量比。",
)
async def get_strength_standards(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    profile = await profile_crud.get_by_user(db, current_user.id)
    entries = await one_rm_crud.list_entries_with_names(db, current_user.id)
    rows = await one_rm_crud.list_completed_set_loads(
        db, current_user.id, now - timedelta(days=PUSH_PULL_WINDOW_DAYS)
    )
    data = build_strength_standards(
        entries,
        rows,
        has_profile=profile is not None,
        bodyweight_kg=profile.weight_kg if profile else None,
        gender=profile.gender if profile else None,
    )
    return StrengthStandardsResponse(**data)
