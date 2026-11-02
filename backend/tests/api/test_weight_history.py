"""体重历史与 7 日移动平均。"""

from datetime import date, datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.profile import WeightLog
from app.services.metrics import build_weight_history


def test_empty_history():
    data = build_weight_history([], today=date(2026, 9, 11))
    assert data["points"] == []
    assert data["change_kg"] is None
    assert data["records"] == 0


def test_same_day_merge_single_point_change_none():
    t = datetime(2026, 9, 11, 8, 0)
    data = build_weight_history(
        [(t, 75.0), (t.replace(hour=20), 76.0)], today=date(2026, 9, 11)
    )
    assert data["records"] == 2
    assert len(data["points"]) == 1
    assert data["points"][0]["weight_kg"] == 75.5
    assert data["points"][0]["ma7_kg"] == 75.5
    assert data["change_kg"] is None


def test_forward_fill_and_change():
    base = datetime(2026, 9, 1, 8, 0)
    rows = [(base, 80.0), (base + timedelta(days=2), 82.0)]
    data = build_weight_history(rows, today=date(2026, 9, 3))
    assert [p["date"] for p in data["points"]] == ["2026-09-01", "2026-09-03"]
    # 首日窗口里只有当天有值
    assert data["points"][0]["ma7_kg"] == 80.0
    # 次日窗口 08-28..09-03：09-01 之前无记录的天不计入；09-01 前向填充 2 天 + 09-03 当天
    assert data["points"][1]["ma7_kg"] == pytest.approx((80.0 * 2 + 82.0) / 3, abs=0.01)
    assert data["change_kg"] == 2.0


def test_window_filter_excludes_old_points():
    rows = [
        (datetime(2026, 9, 1, 8, 0), 90.0),  # 窗口外，且不参与前向填充
        (datetime(2026, 9, 8, 8, 0), 88.0),
    ]
    data = build_weight_history(rows, today=date(2026, 9, 10), days=7)
    assert len(data["points"]) == 1
    assert data["points"][0]["weight_kg"] == 88.0
    assert data["points"][0]["ma7_kg"] == 88.0


@pytest.mark.asyncio
async def test_weight_history_empty_for_new_user(
    client: AsyncClient, auth_headers: dict
):
    resp = await client.get("/api/v1/users/me/weight-history", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["points"] == []
    assert data["records"] == 0
    assert data["change_kg"] is None


@pytest.mark.asyncio
async def test_weight_history_written_by_profile_updates(
    client: AsyncClient, auth_headers: dict
):
    payload = {
        "gender": "male",
        "birthYear": 1995,
        "heightCm": 178,
        "weightKg": 75.0,
        "goal": "muscle_gain",
        "experience": "intermediate",
    }
    first = await client.put(
        "/api/v1/users/me/profile", json=payload, headers=auth_headers
    )
    assert first.status_code == 200
    # 体重未变化：不写流水
    again = await client.put(
        "/api/v1/users/me/profile", json=payload, headers=auth_headers
    )
    assert again.status_code == 200
    # 体重变化：写第二条流水
    payload["weightKg"] = 74.5
    changed = await client.put(
        "/api/v1/users/me/profile", json=payload, headers=auth_headers
    )
    assert changed.status_code == 200

    resp = await client.get("/api/v1/users/me/weight-history", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["records"] == 2  # 三次 PUT 只有两次体重变化
    # 同日两条归并为均值
    assert len(data["points"]) == 1
    assert data["points"][0]["weight_kg"] == 74.75
    assert data["points"][0]["ma7_kg"] == 74.75
    assert data["change_kg"] is None


@pytest.mark.asyncio
async def test_weight_history_sparse_points(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified,
):
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    db_session.add(
        WeightLog(
            user_id=test_user_verified.id,
            weight_kg=80.0,
            recorded_at=now - timedelta(days=10),
        )
    )
    db_session.add(
        WeightLog(
            user_id=test_user_verified.id,
            weight_kg=78.0,
            recorded_at=now - timedelta(days=1),
        )
    )
    await db_session.commit()

    resp = await client.get(
        "/api/v1/users/me/weight-history?days=90", headers=auth_headers
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["records"] == 2
    assert len(data["points"]) == 2
    assert data["points"][0]["weight_kg"] == 80.0
    assert data["points"][1]["weight_kg"] == 78.0
    assert data["change_kg"] == -2.0
    assert all(p["ma7_kg"] is not None for p in data["points"])


@pytest.mark.asyncio
async def test_weight_history_days_bounds(client: AsyncClient, auth_headers: dict):
    resp = await client.get(
        "/api/v1/users/me/weight-history?days=3", headers=auth_headers
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_weight_history_requires_auth(client: AsyncClient):
    resp = await client.get("/api/v1/users/me/weight-history")
    assert resp.status_code == 401
