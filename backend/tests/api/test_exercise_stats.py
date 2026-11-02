"""动作数据图表聚合。"""

from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup
from app.services.exercise_stats import build_exercise_stats, period_label


def _row(
    session_id,
    set_number,
    reps,
    weight_kg,
    *,
    rpe=None,
    notes=None,
    completed_at=None,
    started_at=None,
    session_completed_at=None,
    set_kind=None,
):
    base = (
        session_id,
        set_number,
        reps,
        weight_kg,
        rpe,
        notes,
        completed_at,
        started_at,
        session_completed_at,
    )
    if set_kind is None:
        return base
    return base + (set_kind,)


def test_period_label():
    assert period_label(30) == "上个月"
    assert period_label(90) == "近 3 个月"
    assert period_label(14) == "近 14 天"


def test_empty_stats():
    data = build_exercise_stats([], exercise_id=7, now=datetime(2026, 9, 11, 12, 0, 0))
    assert data["exercise_id"] == 7
    assert data["period_label"] == "上个月"
    assert data["max_weight"]["value"] is None
    assert data["max_weight"]["points"] == []
    assert data["records"]["session_count"] == 0
    assert data["history"] == []
    assert len(data["axis"]) == 3


def test_aggregates_period_and_prs():
    now = datetime(2026, 9, 11, 12, 0, 0)
    rows = [
        _row(
            1,
            1,
            8,
            60,
            rpe=8,
            completed_at=datetime(2026, 9, 1, 10, 0, 0),
            started_at=datetime(2026, 9, 1, 9, 0, 0),
            session_completed_at=datetime(2026, 9, 1, 10, 30, 0),
        ),
        _row(
            1,
            2,
            6,
            80,
            rpe=9,
            completed_at=datetime(2026, 9, 1, 10, 10, 0),
            started_at=datetime(2026, 9, 1, 9, 0, 0),
            session_completed_at=datetime(2026, 9, 1, 10, 30, 0),
        ),
        _row(
            2,
            1,
            12,
            50,
            completed_at=datetime(2026, 8, 20, 10, 0, 0),
            started_at=datetime(2026, 8, 20, 9, 0, 0),
            session_completed_at=datetime(2026, 8, 20, 10, 20, 0),
        ),
        # 窗口外，只计入个人纪录
        _row(
            3,
            1,
            3,
            100,
            completed_at=datetime(2026, 6, 1, 10, 0, 0),
            started_at=datetime(2026, 6, 1, 9, 0, 0),
            session_completed_at=datetime(2026, 6, 1, 10, 10, 0),
        ),
    ]
    data = build_exercise_stats(rows, exercise_id=1, now=now, estimated_1rm_kg=110.4)
    assert data["max_weight"]["value"] == 80
    assert data["max_reps"]["value"] == 12
    assert data["total_volume"]["value"] is not None
    assert data["total_volume"]["value"] > 0
    assert data["records"]["max_weight_kg"] == 100
    assert data["records"]["max_reps"] == 12
    assert data["records"]["estimated_1rm_kg"] == 110.4
    assert data["records"]["session_count"] == 3
    assert len(data["history"]) == 3
    assert data["history"][0]["session_id"] == 1
    assert len(data["history"][0]["sets"]) == 2


def test_warmup_and_cooldown_stay_out_of_load():
    now = datetime(2026, 9, 11, 12, 0, 0)
    when = dict(
        completed_at=datetime(2026, 9, 8, 10, 0, 0),
        started_at=datetime(2026, 9, 8, 9, 0, 0),
        session_completed_at=datetime(2026, 9, 8, 11, 0, 0),
    )
    rows = [
        _row(1, 1, 10, 20, set_kind="warmup", **when),
        _row(1, 2, 5, 80, set_kind="working", **when),
        _row(1, 3, 8, 70, set_kind="drop", **when),
        _row(1, 4, 15, 40, set_kind="cooldown", **when),
    ]
    data = build_exercise_stats(rows, exercise_id=1, now=now)
    assert data["records"]["max_weight_kg"] == 80
    assert data["max_weight"]["value"] == 80
    assert data["records"]["max_reps"] == 8
    assert len(data["history"][0]["sets"]) == 4
    assert data["history"][0]["sets"][0]["set_kind"] == "warmup"


def test_bar_metrics_are_weekly_slots():
    now = datetime(2026, 9, 11, 12, 0, 0)
    rows = [
        _row(
            1,
            1,
            8,
            60,
            completed_at=datetime(2026, 9, 7, 10, 0, 0),
            started_at=datetime(2026, 9, 7, 9, 0, 0),
            session_completed_at=datetime(2026, 9, 7, 11, 0, 0),
        ),
        _row(
            2,
            1,
            12,
            50,
            completed_at=datetime(2026, 9, 8, 10, 0, 0),
            started_at=datetime(2026, 9, 8, 9, 0, 0),
            session_completed_at=datetime(2026, 9, 8, 11, 0, 0),
        ),
    ]
    data = build_exercise_stats(rows, exercise_id=1, now=now)
    loaded = [p for p in data["max_reps"]["points"] if p["v"] > 0]
    assert len(loaded) == 1
    assert loaded[0]["v"] == 12
    assert len(data["max_reps"]["points"]) == len(data["total_volume"]["points"])
    assert len(data["total_volume"]["points"]) >= 4


async def _create_exercise(db: AsyncSession) -> Exercise:
    mg = MuscleGroup(name="胸部", name_en="Chest", category="upper")
    db.add(mg)
    await db.flush()
    ex = Exercise(
        name="哑铃卧推",
        name_en="Dumbbell Bench Press",
        exercise_type="compound",
        primary_muscle_group_id=mg.id,
    )
    db.add(ex)
    await db.commit()
    await db.refresh(ex)
    return ex


@pytest.mark.asyncio
async def test_exercise_stats_empty(client: AsyncClient, auth_headers: dict):
    resp = await client.get("/api/v1/exercises/99999/stats", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["max_weight"]["value"] is None
    assert data["history"] == []
    assert data["period_label"] == "上个月"


@pytest.mark.asyncio
async def test_exercise_stats_after_session(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    # 统计窗口默认 30 天，用相对日期防止测试随时间腐烂
    day = (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y-%m-%d")
    ex = await _create_exercise(db_session)
    created = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "stats-session-1", "started_at": f"{day}T10:00:00Z"},
        headers=auth_headers,
    )
    assert created.status_code == 201
    session_id = created.json()["id"]
    done = await client.put(
        f"/api/v1/sessions/{session_id}/complete",
        json={
            "client_uuid": "stats-session-1",
            "started_at": f"{day}T10:00:00Z",
            "completed_at": f"{day}T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "stats-set-1",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 8,
                    "weight_kg": 60.0,
                    "rpe": 8.0,
                    "completed_at": f"{day}T10:20:00Z",
                },
                {
                    "client_uuid": "stats-set-2",
                    "exercise_id": ex.id,
                    "set_number": 2,
                    "reps": 5,
                    "weight_kg": 80.0,
                    "rpe": 9.0,
                    "completed_at": f"{day}T10:30:00Z",
                },
            ],
        },
        headers=auth_headers,
    )
    assert done.status_code == 200

    resp = await client.get(f"/api/v1/exercises/{ex.id}/stats", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["max_weight"]["value"] == 80
    assert data["max_reps"]["value"] == 8
    assert data["total_volume"]["value"] == pytest.approx(8 * 60 + 5 * 80)
    assert data["records"]["max_weight_kg"] == 80
    assert data["records"]["session_count"] == 1
    assert len(data["history"]) == 1
    assert len(data["history"][0]["sets"]) == 2
