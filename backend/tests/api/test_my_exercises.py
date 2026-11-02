"""用户只能创建、修改、删除自己的动作。"""

from datetime import datetime, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup
from app.models.user import User
from app.models.workout import WorkoutSession, WorkoutSet


async def _muscle(db: AsyncSession) -> MuscleGroup:
    muscle = MuscleGroup(name="肩袖", name_en="Rotator Cuff", category="upper")
    db.add(muscle)
    await db.commit()
    await db.refresh(muscle)
    return muscle


@pytest.mark.asyncio
async def test_user_creates_lists_and_deletes_own_exercise(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified: User,
):
    muscle = await _muscle(db_session)
    created = await client.post(
        "/api/v1/exercises/mine",
        json={
            "name": "弹力带外旋",
            "exercise_type": "isolation",
            "primary_muscle_group_id": muscle.id,
        },
        headers=auth_headers,
    )
    assert created.status_code == 201
    body = created.json()
    assert body["is_custom"] is True
    exercise_id = body["id"]

    listed = await client.get("/api/v1/exercises/mine", headers=auth_headers)
    assert listed.status_code == 200
    assert [item["id"] for item in listed.json()["items"]] == [exercise_id]

    stored = await db_session.get(Exercise, exercise_id)
    assert stored.created_by_user_id == test_user_verified.id

    deleted = await client.delete(
        f"/api/v1/exercises/mine/{exercise_id}", headers=auth_headers
    )
    assert deleted.status_code == 204
    assert await db_session.get(Exercise, exercise_id) is None


@pytest.mark.asyncio
async def test_user_cannot_delete_catalog_or_used_exercise(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified: User,
):
    muscle = await _muscle(db_session)
    catalog = Exercise(
        name="公共动作",
        exercise_type="compound",
        primary_muscle_group_id=muscle.id,
        is_custom=False,
    )
    db_session.add(catalog)
    await db_session.commit()
    await db_session.refresh(catalog)

    denied = await client.delete(
        f"/api/v1/exercises/mine/{catalog.id}", headers=auth_headers
    )
    assert denied.status_code == 403

    created = await client.post(
        "/api/v1/exercises/mine",
        json={
            "name": "已练过的自建",
            "exercise_type": "compound",
            "primary_muscle_group_id": muscle.id,
        },
        headers=auth_headers,
    )
    exercise_id = created.json()["id"]
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    session = WorkoutSession(
        client_uuid="mine-session",
        user_id=test_user_verified.id,
        started_at=now,
    )
    db_session.add(session)
    await db_session.commit()
    await db_session.refresh(session)
    db_session.add(
        WorkoutSet(
            client_uuid="mine-set",
            session_id=session.id,
            exercise_id=exercise_id,
            set_number=1,
        )
    )
    await db_session.commit()

    blocked = await client.delete(
        f"/api/v1/exercises/mine/{exercise_id}", headers=auth_headers
    )
    assert blocked.status_code == 409
    assert await db_session.get(Exercise, exercise_id) is not None
