"""数据页总览聚合。"""

from datetime import datetime

import pytest
from httpx import AsyncClient

from app.services.stats_overview import build_stats_overview, period_label


def test_period_label():
    assert period_label(7) == "近 7 天"
    assert period_label(30) == "本月"
    assert period_label(90) == "近 90 天"


def test_empty_overview():
    data = build_stats_overview(
        [],
        [],
        [],
        {},
        period_days=30,
        now=datetime(2026, 9, 12, 12, 0, 0),
    )
    assert data["sessions_count"] == 0
    assert data["total_volume_kg"] == 0
    assert data["trained_days"] == []
    assert data["recent_prs"] == []
    assert data["top_exercises"] == []


def test_aggregates_kpis_muscle_prs_and_top():
    now = datetime(2026, 9, 12, 12, 0, 0)
    sessions = [
        (1, datetime(2026, 9, 1, 9, 0, 0), datetime(2026, 9, 1, 10, 0, 0)),
        (2, datetime(2026, 9, 8, 9, 0, 0), datetime(2026, 9, 8, 10, 30, 0)),
    ]
    set_rows = [
        (1, 10, "杠铃卧推", "胸部", 8, 80, 8.0),
        (1, 10, "杠铃卧推", "胸部", 6, 90, 9.0),
        (2, 10, "杠铃卧推", "胸部", 5, 100, 9.5),
        (2, 20, "深蹲", "腿部", 5, 120, 8.0),
    ]
    # 100kg 卧推是全量最大且落在周期内 → PR；深蹲全量最大在周期外
    lifetime = [
        (10, "杠铃卧推", 95, datetime(2026, 6, 1, 10, 0, 0)),
        (10, "杠铃卧推", 100, datetime(2026, 9, 8, 10, 0, 0)),
        (20, "深蹲", 120, datetime(2026, 9, 8, 10, 10, 0)),
        (20, "深蹲", 140, datetime(2026, 5, 1, 10, 0, 0)),
    ]
    data = build_stats_overview(
        sessions,
        set_rows,
        lifetime,
        {10: 115.0, 20: 150.0},
        period_days=30,
        now=now,
    )
    assert data["sessions_count"] == 2
    assert data["total_duration_seconds"] == 3600 + 5400
    assert data["trained_days"] == ["2026-09-01", "2026-09-08"]
    assert data["hard_sets"] == 4
    assert data["avg_rpe"] == 8.6
    # 80*8 + 90*6 + 100*5 + 120*5 = 2280
    assert data["total_volume_kg"] == 2280.0
    assert data["by_muscle"][0]["name"] == "胸部"
    assert len(data["recent_prs"]) == 1
    assert data["recent_prs"][0]["exercise_id"] == 10
    assert data["recent_prs"][0]["value"] == 100.0
    assert data["top_exercises"][0]["name"] == "杠铃卧推"
    assert data["top_exercises"][0]["estimated_1rm_kg"] == 115.0
    assert data["top_exercises"][1]["name"] == "深蹲"


@pytest.mark.asyncio
async def test_stats_overview_api_empty(client: AsyncClient, auth_headers: dict):
    resp = await client.get("/api/v1/stats/overview?days=30", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["sessions_count"] == 0
    assert data["period_label"] == "本月"
    assert data["trained_days"] == []
    assert data["by_muscle"] == []
    assert data["recent_prs"] == []
    assert data["top_exercises"] == []
