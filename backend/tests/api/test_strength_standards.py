"""相对力量、Dots/Wilks 系数与推拉比。"""

from datetime import datetime, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup
from app.services.strength_standards import (
    build_big_three,
    build_push_pull,
    build_strength_standards,
    dots_score,
    lift_key,
    relative_strength,
    wilks_score,
)


def test_dots_anchors():
    # 男 75kg 总成绩 340kg → ≈243.9（手算：340*500/696.94）
    assert dots_score(340, 75, "male") == pytest.approx(243.9, abs=0.1)
    # 女 60kg 总成绩 250kg → ≈277.1
    assert dots_score(250, 60, "female") == pytest.approx(277.1, abs=0.1)


def test_wilks_anchor():
    assert wilks_score(340, 75, "male") == pytest.approx(242.3, abs=0.1)


def test_scores_none_on_missing_or_invalid():
    assert dots_score(340, 75, "undisclosed") is None
    assert dots_score(340, 75, None) is None
    assert dots_score(340, None, "male") is None
    assert dots_score(340, 0, "male") is None
    assert dots_score(None, 75, "male") is None
    assert wilks_score(340, 75, "undisclosed") is None
    assert wilks_score(None, None, None) is None


def test_relative_strength():
    assert relative_strength(100, 75) == 1.33
    assert relative_strength(100, None) is None
    assert relative_strength(None, 75) is None


def test_lift_key_matching():
    assert lift_key("Barbell Squat") == "squat"
    assert lift_key(" SQUAT ") == "squat"
    assert lift_key("Bench Press") == "bench"
    assert lift_key("Barbell Deadlift") == "deadlift"
    assert lift_key("Hack Squat Machine") is None
    assert lift_key(None) is None


def test_big_three_takes_best_and_reports_missing():
    entries = [
        (1, "杠铃深蹲", "Barbell Squat", 100.0),
        (2, "深蹲", "Squat", 120.0),
        (3, "杠铃卧推", "Barbell Bench Press", 80.0),
        (4, "弯举", "Barbell Curl", 40.0),
    ]
    big = build_big_three(entries)
    assert big.squat_kg == 120.0 and big.squat_exercise_id == 2
    assert big.bench_kg == 80.0
    assert big.deadlift_kg is None
    assert big.total_kg is None  # 三项不全不硬算
    assert big.complete is False
    assert big.missing == ["deadlift"]

    full = build_big_three(entries + [(5, "杠铃硬拉", "Barbell Deadlift", 140.0)])
    assert full.complete is True
    assert full.total_kg == 340.0


def test_push_pull_verdicts():
    def rows(muscle, n, weight=100.0):
        return [(datetime(2026, 9, 10, 8, 0), 8, weight, 8.5, muscle) for _ in range(n)]

    pp = build_push_pull(rows("胸部", 3) + rows("背阔肌", 6))
    assert pp.push_hard_sets == 3 and pp.pull_hard_sets == 6
    assert pp.ratio == pytest.approx(0.5, abs=0.01)
    assert pp.verdict == "pull_dominant"

    pp2 = build_push_pull(rows("胸部", 6) + rows("背阔肌", 4))
    assert pp2.verdict == "push_dominant"

    pp3 = build_push_pull(rows("胸部", 5) + rows("背阔肌", 5))
    assert pp3.verdict == "balanced"

    pp4 = build_push_pull(rows("胸部", 5))
    assert pp4.ratio is None and pp4.verdict == "unknown"


def test_build_without_profile_degrades():
    data = build_strength_standards(
        [(1, "杠铃卧推", "Barbell Bench Press", 80.0)],
        [],
        has_profile=False,
        bodyweight_kg=None,
        gender=None,
    )
    assert data["has_profile"] is False
    assert data["relative_strength"][0]["ratio"] is None
    assert data["relative_strength"][0]["lift"] == "bench"
    assert data["big_three"]["complete"] is False
    assert data["dots"] is None and data["wilks"] is None
    assert data["push_pull"]["verdict"] == "unknown"


async def _create_exercise(db: AsyncSession) -> Exercise:
    mg = MuscleGroup(name="胸部", name_en="Chest", category="upper")
    db.add(mg)
    await db.flush()
    ex = Exercise(
        name="杠铃卧推",
        name_en="Barbell Bench Press",
        exercise_type="compound",
        primary_muscle_group_id=mg.id,
    )
    db.add(ex)
    await db.commit()
    await db.refresh(ex)
    return ex


@pytest.mark.asyncio
async def test_api_without_profile(client: AsyncClient, auth_headers: dict):
    resp = await client.get("/api/v1/stats/strength-standards", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["has_profile"] is False
    assert data["bodyweight_kg"] is None
    assert data["relative_strength"] == []
    assert data["big_three"]["complete"] is False
    assert data["big_three"]["missing"] == ["squat", "bench", "deadlift"]
    assert data["dots"] is None and data["wilks"] is None
    assert data["push_pull"]["verdict"] == "unknown"


@pytest.mark.asyncio
async def test_api_with_profile_and_bench_session(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    put = await client.put(
        "/api/v1/users/me/profile",
        json={
            "gender": "male",
            "birthYear": 1995,
            "heightCm": 178,
            "weightKg": 75.0,
            "goal": "performance",
            "experience": "intermediate",
        },
        headers=auth_headers,
    )
    assert put.status_code == 200

    ex = await _create_exercise(db_session)
    day = datetime.now(timezone.utc).date().isoformat()
    created = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "ss-1", "started_at": f"{day}T10:00:00Z"},
        headers=auth_headers,
    )
    assert created.status_code == 201
    done = await client.put(
        f"/api/v1/sessions/{created.json()['id']}/complete",
        json={
            "client_uuid": "ss-1",
            "started_at": f"{day}T10:00:00Z",
            "completed_at": f"{day}T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "ss-set-1",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 8,
                    "weight_kg": 60.0,
                    "rpe": 8.0,
                    "completed_at": f"{day}T10:20:00Z",
                }
            ],
        },
        headers=auth_headers,
    )
    assert done.status_code == 200

    resp = await client.get("/api/v1/stats/strength-standards", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["has_profile"] is True
    assert data["bodyweight_kg"] == 75.0
    top = data["relative_strength"][0]
    assert top["lift"] == "bench" and top["is_big_three"] is True
    # RPE 8 × 8 次 → 等效 10 次 @73.9% → e1RM ≈ 81.2；81.2/75 ≈ 1.08
    assert top["estimated_1rm_kg"] == pytest.approx(81.2, abs=0.1)
    assert top["ratio"] == pytest.approx(1.08, abs=0.01)
    # 三大项不全 → 不返回总分与系数
    assert data["big_three"]["complete"] is False
    assert "squat" in data["big_three"]["missing"]
    assert data["dots"] is None and data["wilks"] is None
    # 推拉：本次卧推计入推力容量
    assert data["push_pull"]["push_hard_sets"] == 1
    assert data["push_pull"]["pull_volume_kg"] == 0


@pytest.mark.asyncio
async def test_api_requires_auth(client: AsyncClient):
    resp = await client.get("/api/v1/stats/strength-standards")
    assert resp.status_code == 401
