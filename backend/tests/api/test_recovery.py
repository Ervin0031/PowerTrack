"""肌群恢复状态：完成会话更新系数，GET /muscle-groups/status 读取。"""

from datetime import datetime, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup
from app.models.recovery import UserRecoveryFactor


async def _create_chest_exercise(db: AsyncSession) -> Exercise:
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


def _hard_sets(exercise_id: int, prefix: str, weight: float = 100.0) -> list[dict]:
    return [
        {
            "client_uuid": f"{prefix}-set-{i}",
            "exercise_id": exercise_id,
            "set_number": i,
            "reps": 5,
            "weight_kg": weight,
            "rpe": 8.5,
            "completed_at": "2026-09-08T10:08:00Z",
        }
        for i in range(1, 4)
    ]


async def _complete(
    client: AsyncClient,
    headers: dict,
    *,
    uuid: str,
    started: str,
    completed: str,
    sets: list[dict],
):
    created = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": uuid, "started_at": started},
        headers=headers,
    )
    assert created.status_code == 201
    session_id = created.json()["id"]
    resp = await client.put(
        f"/api/v1/sessions/{session_id}/complete",
        json={
            "client_uuid": uuid,
            "started_at": started,
            "completed_at": completed,
            "sets": sets,
        },
        headers=headers,
    )
    assert resp.status_code == 200
    return session_id


@pytest.mark.asyncio
async def test_status_empty_for_new_user(client: AsyncClient, auth_headers: dict):
    resp = await client.get("/api/v1/muscle-groups/status", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["items"] == []
    assert body["global_factor"] == 1.0
    assert body["global_confidence"] == "low"


@pytest.mark.asyncio
async def test_light_session_does_not_create_observation(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _create_chest_exercise(db_session)
    await _complete(
        client,
        auth_headers,
        uuid="rec-light-1",
        started="2026-09-08T10:00:00Z",
        completed="2026-09-08T11:00:00Z",
        sets=[
            {
                "client_uuid": "rec-light-set-1",
                "exercise_id": ex.id,
                "set_number": 1,
                "reps": 12,
                "weight_kg": 40.0,
                "rpe": 6.0,
                "completed_at": "2026-09-08T10:10:00Z",
            }
        ],
    )
    status = await client.get("/api/v1/muscle-groups/status", headers=auth_headers)
    item = status.json()["items"][0]
    assert item["name"] == "胸部"
    assert item["observations_count"] == 0
    assert item["recovery_factor"] == 1.0
    assert item["baseline_window_hours"] == 60
    assert item["recovery_window_hours"] == 60
    assert item["recovery_confidence"] == "low"


@pytest.mark.asyncio
async def test_two_effective_high_freq_sessions_record_observation(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _create_chest_exercise(db_session)
    await _complete(
        client,
        auth_headers,
        uuid="rec-eff-1",
        started="2026-09-08T10:00:00Z",
        completed="2026-09-08T11:00:00Z",
        sets=_hard_sets(ex.id, "rec-eff-1", 100),
    )
    await _complete(
        client,
        auth_headers,
        uuid="rec-eff-2",
        started="2026-09-09T10:00:00Z",
        completed="2026-09-09T11:00:00Z",
        sets=_hard_sets(ex.id, "rec-eff-2", 102),
    )
    status = await client.get("/api/v1/muscle-groups/status", headers=auth_headers)
    item = status.json()["items"][0]
    assert item["observations_count"] == 1


@pytest.mark.asyncio
async def test_replay_complete_does_not_double_count(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _create_chest_exercise(db_session)
    await _complete(
        client,
        auth_headers,
        uuid="rec-replay-1",
        started="2026-09-08T10:00:00Z",
        completed="2026-09-08T11:00:00Z",
        sets=_hard_sets(ex.id, "rec-replay-1"),
    )
    session_id = await _complete(
        client,
        auth_headers,
        uuid="rec-replay-2",
        started="2026-09-09T10:00:00Z",
        completed="2026-09-09T11:00:00Z",
        sets=_hard_sets(ex.id, "rec-replay-2", 102),
    )
    replay = await client.put(
        f"/api/v1/sessions/{session_id}/complete",
        json={
            "client_uuid": "rec-replay-2",
            "started_at": "2026-09-09T10:00:00Z",
            "completed_at": "2026-09-09T11:00:00Z",
            "sets": _hard_sets(ex.id, "rec-replay-2", 102),
        },
        headers=auth_headers,
    )
    assert replay.status_code == 200
    status = await client.get("/api/v1/muscle-groups/status", headers=auth_headers)
    item = status.json()["items"][0]
    assert item["observations_count"] == 1


@pytest.mark.asyncio
async def test_status_uses_stored_observations_when_enough(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified,
):
    ex = await _create_chest_exercise(db_session)
    await _complete(
        client,
        auth_headers,
        uuid="rec-seed-1",
        started="2026-09-08T10:00:00Z",
        completed="2026-09-08T11:00:00Z",
        sets=_hard_sets(ex.id, "rec-seed-1"),
    )
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    payload = [
        {
            "at": now.isoformat(),
            "interval_hours": 24,
            "baseline_hours": 60,
            "performance_change": 0.02,
            "delta": -0.03,
        }
        for _ in range(5)
    ]
    import json

    from sqlalchemy import select

    result = await db_session.execute(
        select(UserRecoveryFactor).where(
            UserRecoveryFactor.user_id == test_user_verified.id,
            UserRecoveryFactor.muscle_group_id == ex.primary_muscle_group_id,
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        row = UserRecoveryFactor(
            user_id=test_user_verified.id,
            muscle_group_id=ex.primary_muscle_group_id,
            last_effective_at=now,
            last_effective_1rm=120,
        )
        db_session.add(row)
    row.factor = 0.85
    row.observations = json.dumps(payload)
    row.updated_at = now
    await db_session.commit()

    status = await client.get("/api/v1/muscle-groups/status", headers=auth_headers)
    item = status.json()["items"][0]
    assert item["observations_count"] == 5
    assert item["muscle_factor"] == pytest.approx(0.85)
    assert item["recovery_window_hours"] == pytest.approx(51.0)
    assert item["recovery_confidence"] == "medium"
