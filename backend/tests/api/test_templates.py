"""Tests for workout template endpoints."""

import json

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import (
    Equipment,
    Exercise,
    ExerciseSecondaryMuscle,
    MuscleGroup,
)
from app.models.user import User
from app.core.security import get_password_hash, security_manager


async def _exercise(
    db: AsyncSession,
    *,
    name: str = "杠铃卧推",
    muscle: str = "胸部",
    muscle_en: str = "Chest",
    equipment: str | None = "杠铃",
    equipment_en: str | None = "Barbell",
    secondary: str | None = "肱三头肌",
) -> Exercise:
    mg = MuscleGroup(name=muscle, name_en=muscle_en, category="upper")
    db.add(mg)
    await db.flush()
    eq = None
    if equipment:
        eq = Equipment(name=equipment, name_en=equipment_en or equipment)
        db.add(eq)
        await db.flush()
    ex = Exercise(
        name=name,
        name_en=name,
        exercise_type="compound",
        primary_muscle_group_id=mg.id,
        equipment_id=eq.id if eq else None,
    )
    db.add(ex)
    await db.flush()
    if secondary:
        sec = MuscleGroup(name=secondary, name_en=secondary, category="upper")
        db.add(sec)
        await db.flush()
        db.add(ExerciseSecondaryMuscle(exercise_id=ex.id, muscle_group_id=sec.id))
    await db.commit()
    await db.refresh(ex)
    return ex


def _payload(exercise_id: int, **overrides) -> dict:
    body = {
        "title": "推日",
        "description": "胸肩三头",
        "difficulty": "moderate",
        "isPublic": False,
        "exercises": [
            {
                "exerciseId": exercise_id,
                "sortOrder": 0,
                "restTargetSeconds": 90,
                "weightUnit": "kg",
                "sets": [
                    {"setNumber": 1, "reps": 8, "weightKg": 60},
                    {"setNumber": 2, "reps": 8, "weightKg": 62.5},
                ],
            }
        ],
    }
    body.update(overrides)
    return body


async def _create(client: AsyncClient, headers: dict, payload: dict):
    return await client.post(
        "/api/v1/templates",
        data={"data": json.dumps(payload)},
        headers=headers,
    )


@pytest.mark.asyncio
async def test_create_and_get_template(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _exercise(db_session)
    resp = await _create(client, auth_headers, _payload(ex.id))
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["title"] == "推日"
    assert data["difficulty"] == "moderate"
    assert data["is_public"] is False
    assert data["is_owner"] is True
    assert data["exercise_count"] == 1
    assert data["set_count"] == 2
    assert any(m["name"] == "胸部" for m in data["primary_muscles"])
    assert data["exercises"][0]["sets"][0]["reps"] == 8

    detail = await client.get(f"/api/v1/templates/{data['id']}", headers=auth_headers)
    assert detail.status_code == 200
    assert detail.json()["id"] == data["id"]


@pytest.mark.asyncio
async def test_list_filters_and_scope(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified: User,
):
    push = await _exercise(db_session)
    other = User(
        email="other@example.com",
        username="otheruser",
        hashed_password=get_password_hash("testpassword"),
        is_active=True,
        is_verified=True,
    )
    db_session.add(other)
    await db_session.commit()
    await db_session.refresh(other)
    other_headers = {
        "Authorization": f"Bearer {security_manager.create_access_token({'user_id': other.id})[0]}"
    }

    mine = await _create(client, auth_headers, _payload(push.id, title="我的私密"))
    assert mine.status_code == 201
    public = await _create(
        client,
        other_headers,
        _payload(push.id, title="公开推", isPublic=True, difficulty="hard"),
    )
    assert public.status_code == 201
    hidden = await _create(
        client, other_headers, _payload(push.id, title="别人的私密", isPublic=False)
    )
    assert hidden.status_code == 201

    listed = await client.get("/api/v1/templates", headers=auth_headers)
    titles = {item["title"] for item in listed.json()["items"]}
    assert "我的私密" in titles
    assert "公开推" in titles
    assert "别人的私密" not in titles

    mine_only = await client.get("/api/v1/templates?scope=mine", headers=auth_headers)
    assert {i["title"] for i in mine_only.json()["items"]} == {"我的私密"}

    hard = await client.get("/api/v1/templates?difficulty=hard", headers=auth_headers)
    assert {i["title"] for i in hard.json()["items"]} == {"公开推"}

    search = await client.get("/api/v1/templates?search=公开", headers=auth_headers)
    assert {i["title"] for i in search.json()["items"]} == {"公开推"}


@pytest.mark.asyncio
async def test_private_template_hidden_from_others(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _exercise(db_session)
    created = await _create(client, auth_headers, _payload(ex.id, isPublic=False))
    template_id = created.json()["id"]

    other = User(
        email="viewer@example.com",
        username="viewer",
        hashed_password=get_password_hash("testpassword"),
        is_active=True,
        is_verified=True,
    )
    db_session.add(other)
    await db_session.commit()
    await db_session.refresh(other)
    other_headers = {
        "Authorization": f"Bearer {security_manager.create_access_token({'user_id': other.id})[0]}"
    }
    resp = await client.get(f"/api/v1/templates/{template_id}", headers=other_headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_update_delete_and_superset(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    a = await _exercise(db_session, name="卧推")
    b = await _exercise(
        db_session,
        name="飞鸟",
        muscle="胸部",
        muscle_en="Chest",
        equipment="哑铃",
        equipment_en="Dumbbell",
    )
    created = await _create(
        client,
        auth_headers,
        {
            "title": "超级组日",
            "difficulty": "easy",
            "isPublic": False,
            "exercises": [
                {
                    "exerciseId": a.id,
                    "supersetId": 1,
                    "sets": [{"setNumber": 1, "reps": 10}],
                },
                {
                    "exerciseId": b.id,
                    "supersetId": 1,
                    "sets": [{"setNumber": 1, "reps": 12}],
                },
            ],
        },
    )
    assert created.status_code == 201, created.text
    data = created.json()
    assert [e["superset_id"] for e in data["exercises"]] == [1, 1]

    updated = await client.put(
        f"/api/v1/templates/{data['id']}",
        data={
            "data": json.dumps(
                _payload(a.id, title="改名", difficulty="hard", isPublic=True)
            )
        },
        headers=auth_headers,
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["title"] == "改名"
    assert updated.json()["is_public"] is True
    assert len(updated.json()["exercises"]) == 1

    deleted = await client.delete(
        f"/api/v1/templates/{data['id']}", headers=auth_headers
    )
    assert deleted.status_code == 204
    missing = await client.get(f"/api/v1/templates/{data['id']}", headers=auth_headers)
    assert missing.status_code == 404


@pytest.mark.asyncio
async def test_filter_by_muscle_and_equipment(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    chest = await _exercise(db_session)
    listed = await _create(client, auth_headers, _payload(chest.id, title="胸"))
    assert listed.status_code == 201
    muscle_id = chest.primary_muscle_group_id
    eq_id = chest.equipment_id
    by_muscle = await client.get(
        f"/api/v1/templates?muscle_group_id={muscle_id}", headers=auth_headers
    )
    assert by_muscle.json()["total"] >= 1
    by_eq = await client.get(
        f"/api/v1/templates?equipment_id={eq_id}", headers=auth_headers
    )
    assert by_eq.json()["total"] >= 1


@pytest.mark.asyncio
async def test_completions_from_session(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _exercise(db_session)
    created = await _create(client, auth_headers, _payload(ex.id, title="完成用"))
    template_id = created.json()["id"]

    session = await client.post(
        "/api/v1/sessions",
        json={
            "clientUuid": "tpl-session-1",
            "startedAt": "2026-09-11T10:00:00Z",
            "templateId": template_id,
        },
        headers=auth_headers,
    )
    assert session.status_code == 201
    done = await client.put(
        f"/api/v1/sessions/{session.json()['id']}/complete",
        json={
            "clientUuid": "tpl-session-1",
            "startedAt": "2026-09-11T10:00:00Z",
            "completedAt": "2026-09-11T10:40:00Z",
            "templateId": template_id,
            "sets": [
                {
                    "clientUuid": "tpl-set-1",
                    "exerciseId": ex.id,
                    "setNumber": 1,
                    "reps": 8,
                    "weightKg": 60,
                    "completedAt": "2026-09-11T10:10:00Z",
                }
            ],
        },
        headers=auth_headers,
    )
    assert done.status_code == 200, done.text
    assert done.json()["template_id"] == template_id

    completions = await client.get(
        f"/api/v1/templates/{template_id}/completions", headers=auth_headers
    )
    assert completions.status_code == 200
    body = completions.json()
    assert body["total"] == 1
    assert body["items"][0]["is_self"] is True
    assert body["items"][0]["duration_seconds"] == 40 * 60

    listed = await client.get(f"/api/v1/templates/{template_id}", headers=auth_headers)
    assert listed.json()["completion_count"] == 1


@pytest.mark.asyncio
async def test_invalid_difficulty_rejected(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _exercise(db_session)
    resp = await _create(client, auth_headers, _payload(ex.id, difficulty="insane"))
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_templates_require_auth(client: AsyncClient):
    resp = await client.get("/api/v1/templates")
    assert resp.status_code == 401
