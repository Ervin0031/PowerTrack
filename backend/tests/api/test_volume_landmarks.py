"""肌群周容量地标（MEV/MAV/MRV）。"""

from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup
from app.services.volume_landmarks import (
    DEFAULT_LANDMARKS,
    MUSCLE_LANDMARKS,
    landmarks_for,
    volume_landmarks,
    zone_for,
)


def test_zone_boundaries():
    lm = MUSCLE_LANDMARKS["胸部"]  # 8 / 10 / 12–20 / 22
    assert zone_for(9, lm) == "below_mev"
    assert zone_for(10, lm) == "mev"
    assert zone_for(11, lm) == "mev"
    assert zone_for(12, lm) == "mav"
    assert zone_for(20, lm) == "mav"
    assert zone_for(22, lm) == "mav"
    assert zone_for(23, lm) == "above_mrv"


def test_unlisted_muscle_uses_default():
    assert landmarks_for("胫骨前肌") == DEFAULT_LANDMARKS
    item = next(i for i in volume_landmarks({"胫骨前肌": 3}) if i["name"] == "胫骨前肌")
    assert item["is_default"] is True
    assert item["zone"] == "below_mev"


def test_zero_training_lists_all_landmark_muscles():
    items = volume_landmarks({})
    assert len(items) == len(MUSCLE_LANDMARKS)
    assert all(i["hard_sets"] == 0 and i["zone"] == "below_mev" for i in items)


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


async def _complete_session(client, auth_headers, ex, *, day, uuid_prefix, sets):
    created = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": f"{uuid_prefix}-s", "started_at": f"{day}T10:00:00Z"},
        headers=auth_headers,
    )
    assert created.status_code == 201
    payload_sets = []
    for i, s in enumerate(sets, start=1):
        payload_sets.append(
            {
                "client_uuid": f"{uuid_prefix}-set-{i}",
                "exercise_id": ex.id,
                "set_number": i,
                "completed_at": f"{day}T10:{i:02d}:00Z",
                **s,
            }
        )
    done = await client.put(
        f"/api/v1/sessions/{created.json()['id']}/complete",
        json={
            "client_uuid": f"{uuid_prefix}-s",
            "started_at": f"{day}T10:00:00Z",
            "completed_at": f"{day}T11:00:00Z",
            "sets": payload_sets,
        },
        headers=auth_headers,
    )
    assert done.status_code == 200


@pytest.mark.asyncio
async def test_landmarks_after_session(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _create_exercise(db_session)
    today = datetime.now(timezone.utc).date().isoformat()
    await _complete_session(
        client,
        auth_headers,
        ex,
        day=today,
        uuid_prefix="lm-now",
        sets=[
            {"set_kind": "warmup", "reps": 12, "weight_kg": 40.0, "rpe": 9.0},
            {"reps": 8, "weight_kg": 60.0, "rpe": 8.5},
            {"reps": 8, "weight_kg": 62.5, "rpe": 8.5},
            {"reps": 8, "weight_kg": 65.0, "rpe": 9.0},
        ],
    )

    resp = await client.get("/api/v1/volume/landmarks", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    chest = next(i for i in data["items"] if i["name"] == "胸部")
    assert chest["hard_sets"] == 3  # warmup 不计
    assert chest["zone"] == "below_mev"
    assert chest["mev"] == 10 and chest["mav_low"] == 12

    # 上周的会话不计入本周地标
    last_week = (datetime.now(timezone.utc) - timedelta(days=7)).date().isoformat()
    await _complete_session(
        client,
        auth_headers,
        ex,
        day=last_week,
        uuid_prefix="lm-past",
        sets=[
            {"reps": 5, "weight_kg": 100.0, "rpe": 9.0},
            {"reps": 5, "weight_kg": 100.0, "rpe": 9.0},
        ],
    )
    resp2 = await client.get("/api/v1/volume/landmarks", headers=auth_headers)
    chest2 = next(i for i in resp2.json()["items"] if i["name"] == "胸部")
    assert chest2["hard_sets"] == 3


@pytest.mark.asyncio
async def test_landmarks_zero_training(client: AsyncClient, auth_headers: dict):
    resp = await client.get("/api/v1/volume/landmarks", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["hard_sets"] == 0
    assert len(data["items"]) == len(MUSCLE_LANDMARKS)
    assert all(i["zone"] == "below_mev" for i in data["items"])


@pytest.mark.asyncio
async def test_landmarks_requires_auth(client: AsyncClient):
    resp = await client.get("/api/v1/volume/landmarks")
    assert resp.status_code == 401
