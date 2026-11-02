"""Tests for RPE persistence and auto-regulation."""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup
from app.services.rpe import (
    EXTRA_REST_SECONDS,
    FAILURE_AGAIN_MESSAGE,
    REASON_CAPPED,
    REASON_COMPOUND,
    REASON_ISOLATION,
    REASON_RISING,
    REST_MESSAGE,
    failure_message,
    recommend_next_set,
    round_to_plate,
)


async def _create_exercise(db: AsyncSession) -> Exercise:
    mg = MuscleGroup(name="测试肌群", name_en="Test Muscle", category="upper")
    db.add(mg)
    await db.flush()
    ex = Exercise(
        name="杠铃深蹲",
        name_en="Barbell Squat",
        exercise_type="compound",
        primary_muscle_group_id=mg.id,
    )
    db.add(ex)
    await db.commit()
    await db.refresh(ex)
    return ex


def test_round_to_plate():
    assert round_to_plate(102.5) == 102.5
    assert round_to_plate(90.0) == 90.0
    assert round_to_plate(92.25) == 92.5


def test_recommend_sweet_spot_increases_2_5kg():
    advice = recommend_next_set(100, 8.0)
    assert advice.suggested_weight_kg == 102.5
    assert advice.extra_rest_seconds == 0
    assert advice.fatigue_warning is False
    assert advice.reduce_remaining_factor is None


def test_recommend_red_zone_adds_rest():
    advice = recommend_next_set(100, 9.5)
    assert advice.suggested_weight_kg == 100
    assert advice.extra_rest_seconds == EXTRA_REST_SECONDS
    assert advice.message == REST_MESSAGE
    assert advice.fatigue_warning is False


def test_recommend_failure_without_reps_cuts_five_percent():
    advice = recommend_next_set(100, 10.0)
    assert advice.suggested_weight_kg == 95.0
    assert advice.fatigue_warning is True
    assert advice.reduce_remaining_factor == 0.05
    assert advice.extra_rest_seconds == EXTRA_REST_SECONDS
    assert advice.message == failure_message(95)


def test_recommend_single_failure_is_not_90kg():
    gain = recommend_next_set(100, 10.0, reps=1, goal="muscle_gain")
    strength = recommend_next_set(100, 10.0, reps=1, goal="performance")
    assert gain.suggested_weight_kg == 92.5
    assert strength.suggested_weight_kg == 95.0
    assert gain.suggested_weight_kg != 90.0


def test_recommend_five_rep_failure_stays_between_90_and_100():
    advice = recommend_next_set(100, 10.0, reps=5)
    assert advice.suggested_weight_kg is not None
    assert 90 < advice.suggested_weight_kg < 100
    assert advice.message == failure_message(advice.suggested_weight_kg)


def test_recommend_second_failure_gives_no_new_weight():
    advice = recommend_next_set(95, 10.0, reps=5, prior_rpes=[10])
    assert advice.suggested_weight_kg is None
    assert advice.fatigue_warning is True
    assert advice.reduce_remaining_factor is None
    assert advice.message == FAILURE_AGAIN_MESSAGE


def test_recommend_repeat_red_zone_drops_one_plate():
    advice = recommend_next_set(100, 9.5, prior_rpes=[9.5])
    assert advice.suggested_weight_kg == 97.5
    assert advice.extra_rest_seconds == EXTRA_REST_SECONDS
    assert advice.fatigue_warning is False


def test_recommend_locks_when_rpe_keeps_rising():
    advice = recommend_next_set(100, 8.5, prior_rpes=[7.5, 8.0])
    assert advice.suggested_weight_kg == 100
    assert advice.reason == REASON_RISING


def test_recommend_compound_sweet_spot_is_conservative():
    compound = recommend_next_set(80, 8.0, exercise_type="compound")
    isolation = recommend_next_set(80, 8.0, exercise_type="isolation")
    assert compound.suggested_weight_kg == 80.0
    assert isolation.suggested_weight_kg == 82.5
    assert compound.reason == REASON_COMPOUND
    assert isolation.reason == REASON_ISOLATION


def test_recommend_clamps_to_1rm_zone():
    advice = recommend_next_set(
        100, 6.0, one_rm_kg=100, goal="performance", exercise_type="compound"
    )
    assert advice.suggested_weight_kg == 95.0
    assert advice.capped_by_1rm is True
    assert advice.reason == REASON_CAPPED
    assert advice.zone == (0.85, 0.95)


@pytest.mark.asyncio
async def test_complete_session_persists_rpe(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _create_exercise(db_session)
    created = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "rpe-session-1", "started_at": "2026-09-03T10:00:00Z"},
        headers=auth_headers,
    )
    assert created.status_code == 201
    session_id = created.json()["id"]

    resp = await client.put(
        f"/api/v1/sessions/{session_id}/complete",
        json={
            "client_uuid": "rpe-session-1",
            "started_at": "2026-09-03T10:00:00Z",
            "completed_at": "2026-09-03T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "rpe-set-1",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 8,
                    "weight_kg": 100.0,
                    "rpe": 9.0,
                    "completed_at": "2026-09-03T10:08:00Z",
                }
            ],
        },
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["sets"][0]["rpe"] == 9.0

    last = await client.get(
        f"/api/v1/exercises/{ex.id}/last-performance", headers=auth_headers
    )
    assert last.status_code == 200
    assert last.json()["rpe"] == 9.0
    assert last.json()["weight_kg"] == 100.0

    ghost = await client.get(
        f"/api/v1/exercises/{ex.id}/last-session-sets", headers=auth_headers
    )
    assert ghost.status_code == 200
    assert ghost.json()["sets"][0]["rpe"] == 9.0
    assert ghost.json()["sets"][0]["reps"] == 8


@pytest.mark.asyncio
async def test_rpe_recommend_endpoint(client: AsyncClient, auth_headers: dict):
    sweet = await client.post(
        "/api/v1/rpe/recommend",
        json={"weight_kg": 100, "rpe": 8.0},
        headers=auth_headers,
    )
    assert sweet.status_code == 200
    assert sweet.json()["suggested_weight_kg"] == 102.5
    assert sweet.json()["fatigue_warning"] is False
    assert sweet.json()["capped_by_1rm"] is False
    assert sweet.json()["reason"]

    capped = await client.post(
        "/api/v1/rpe/recommend",
        json={
            "weight_kg": 100,
            "rpe": 6.0,
            "one_rm_kg": 100,
            "goal": "performance",
            "exercise_type": "compound",
        },
        headers=auth_headers,
    )
    assert capped.status_code == 200
    assert capped.json()["capped_by_1rm"] is True
    assert capped.json()["suggested_weight_kg"] == 95.0

    red = await client.post(
        "/api/v1/rpe/recommend",
        json={"weightKg": 100, "rpe": 9.5},
        headers=auth_headers,
    )
    assert red.status_code == 200
    assert red.json()["extra_rest_seconds"] == EXTRA_REST_SECONDS

    fail = await client.post(
        "/api/v1/rpe/recommend",
        json={"weight_kg": 100, "rpe": 10, "reps": 1},
        headers=auth_headers,
    )
    assert fail.status_code == 200
    data = fail.json()
    assert data["suggested_weight_kg"] == 92.5
    assert data["fatigue_warning"] is True
    assert data["reduce_remaining_factor"] != 0.10

    again = await client.post(
        "/api/v1/rpe/recommend",
        json={"weight_kg": 92.5, "rpe": 10, "reps": 1, "prior_rpes": [10]},
        headers=auth_headers,
    )
    assert again.status_code == 200
    assert again.json()["suggested_weight_kg"] is None


@pytest.mark.asyncio
async def test_rpe_recommend_requires_auth(client: AsyncClient):
    resp = await client.post(
        "/api/v1/rpe/recommend",
        json={"weight_kg": 100, "rpe": 8.0},
    )
    assert resp.status_code == 401
