"""Tests for workout session & set endpoints"""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup
from app.models.user import User

# ========== helpers ==========


async def _create_exercise(db: AsyncSession) -> Exercise:
    """Create a minimal exercise for testing."""
    mg = MuscleGroup(name="测试肌群", name_en="Test Muscle", category="upper")
    db.add(mg)
    await db.flush()
    ex = Exercise(
        name="测试动作",
        name_en="Test Exercise",
        exercise_type="compound",
        primary_muscle_group_id=mg.id,
    )
    db.add(ex)
    await db.commit()
    await db.refresh(ex)
    return ex


async def _create_session(client: AsyncClient, headers: dict) -> dict:
    """Create a session via API, return the response JSON."""
    resp = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "test-session-uuid", "started_at": "2026-08-05T10:00:00Z"},
        headers=headers,
    )
    assert resp.status_code == 201
    return resp.json()


# ========== Session CRUD ==========


@pytest.mark.asyncio
async def test_create_session(client: AsyncClient, auth_headers: dict):
    """POST /sessions creates a new in-progress session."""
    resp = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "create-001", "started_at": "2026-08-05T10:00:00Z"},
        headers=auth_headers,
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["client_uuid"] == "create-001"
    assert data["status"] == "in_progress"


@pytest.mark.asyncio
async def test_create_session_idempotent(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """Same client_uuid twice → second call returns existing session."""
    payload = {"client_uuid": "idempotent-001", "started_at": "2026-08-05T10:00:00Z"}
    r1 = await client.post("/api/v1/sessions", json=payload, headers=auth_headers)
    assert r1.status_code == 201
    r2 = await client.post("/api/v1/sessions", json=payload, headers=auth_headers)
    assert r2.status_code == 201
    assert r2.json()["id"] == r1.json()["id"]


@pytest.mark.asyncio
async def test_create_second_in_progress_session_rejected(
    client: AsyncClient, auth_headers: dict
):
    """同一用户已有进行中会话时，再创建不同 uuid 的会话 → 409。"""
    await _create_session(client, auth_headers)
    resp = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "second-001", "started_at": "2026-08-05T11:00:00Z"},
        headers=auth_headers,
    )
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_create_session_accepts_camel_case(
    client: AsyncClient, auth_headers: dict
):
    """POST /sessions accepts camelCase body (Flutter client default)."""
    resp = await client.post(
        "/api/v1/sessions",
        json={"clientUuid": "camel-001", "startedAt": "2026-08-05T10:00:00Z"},
        headers=auth_headers,
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["client_uuid"] == "camel-001"
    assert data["status"] == "in_progress"


@pytest.mark.asyncio
async def test_create_session_requires_auth(client: AsyncClient):
    """POST /sessions without auth → 401."""
    resp = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "no-auth", "started_at": "2026-08-05T10:00:00Z"},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_complete_session_success(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """PUT /sessions/{id}/complete writes session + sets."""
    ex = await _create_exercise(db_session)
    session = await _create_session(client, auth_headers)

    resp = await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json={
            "client_uuid": "test-session-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "notes": "练得不错",
            "sets": [
                {
                    "client_uuid": "set-uuid-001",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 10,
                    "weight_kg": 60.0,
                    "completed_at": "2026-08-05T10:05:00Z",
                },
                {
                    "client_uuid": "set-uuid-002",
                    "exercise_id": ex.id,
                    "set_number": 2,
                    "reps": 8,
                    "weight_kg": 65.0,
                    "completed_at": "2026-08-05T10:10:00Z",
                },
            ],
        },
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "completed"
    assert data["completed_at"] is not None
    assert data["notes"] == "练得不错"
    assert len(data["sets"]) == 2
    assert data["sets"][0]["reps"] == 10


@pytest.mark.asyncio
async def test_complete_session_nonexistent(client: AsyncClient, auth_headers: dict):
    """PUT to nonexistent session → 404."""
    resp = await client.put(
        "/api/v1/sessions/99999/complete",
        json={
            "client_uuid": "nonexistent",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [],
        },
        headers=auth_headers,
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_complete_session_wrong_user(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """User B cannot complete User A's session."""
    from app.core.security import get_password_hash

    # Create user A + session
    user_a = User(
        email="a@test.com",
        username="userA",
        hashed_password=get_password_hash("pw"),
        is_active=True,
        is_verified=True,
    )
    db_session.add(user_a)
    await db_session.commit()
    await db_session.refresh(user_a)

    from app.crud.workout import session_crud
    from app.schemas.workout import SessionCreate

    session = await session_crud.create(
        db_session,
        SessionCreate(client_uuid="owner-test-uuid", started_at="2026-08-05T10:00:00Z"),
        user_a.id,
    )

    # User B (auth_headers is for test_user_verified) tries to complete
    resp = await client.put(
        f"/api/v1/sessions/{session.id}/complete",
        json={
            "client_uuid": "owner-test-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [],
        },
        headers=auth_headers,
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_complete_session_uuid_mismatch(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """PUT with wrong client_uuid → 400."""
    session = await _create_session(client, auth_headers)
    resp = await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json={
            "client_uuid": "wrong-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [],
        },
        headers=auth_headers,
    )
    assert resp.status_code == 400


# ========== Idempotency ==========


@pytest.mark.asyncio
async def test_complete_session_sets_idempotent(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """Upload same sets twice → no duplicates."""
    ex = await _create_exercise(db_session)
    session = await _create_session(client, auth_headers)

    sets_payload = [
        {
            "client_uuid": "iset-001",
            "exercise_id": ex.id,
            "set_number": 1,
            "reps": 10,
            "weight_kg": 50.0,
        },
        {
            "client_uuid": "iset-002",
            "exercise_id": ex.id,
            "set_number": 2,
            "reps": 8,
            "weight_kg": 55.0,
        },
    ]
    complete_payload = {
        "client_uuid": "test-session-uuid",
        "started_at": "2026-08-05T10:00:00Z",
        "completed_at": "2026-08-05T11:00:00Z",
        "sets": sets_payload,
    }

    # First upload
    r1 = await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json=complete_payload,
        headers=auth_headers,
    )
    assert r1.status_code == 200
    assert len(r1.json()["sets"]) == 2

    # Second upload — same sets
    r2 = await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json=complete_payload,
        headers=auth_headers,
    )
    assert r2.status_code == 200
    assert len(r2.json()["sets"]) == 2  # still 2, not 4


@pytest.mark.asyncio
async def test_complete_session_partial_duplicate_sets(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """First [A,B], second [B,C] → only C added (B skipped as duplicate)."""
    ex = await _create_exercise(db_session)

    # Create two sessions for this test
    s1 = await _create_session(client, auth_headers)

    # First session: upload sets A, B
    r1 = await client.put(
        f"/api/v1/sessions/{s1['id']}/complete",
        json={
            "client_uuid": "test-session-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "partial-A",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 10,
                },
                {
                    "client_uuid": "partial-B",
                    "exercise_id": ex.id,
                    "set_number": 2,
                    "reps": 8,
                },
            ],
        },
        headers=auth_headers,
    )
    assert r1.status_code == 200
    assert len(r1.json()["sets"]) == 2

    # Create a new session and try to upload B (duplicate) + C (new)
    s2 = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "partial-session-2", "started_at": "2026-08-06T10:00:00Z"},
        headers=auth_headers,
    )
    assert s2.status_code == 201

    r2 = await client.put(
        f"/api/v1/sessions/{s2.json()['id']}/complete",
        json={
            "client_uuid": "partial-session-2",
            "started_at": "2026-08-06T10:00:00Z",
            "completed_at": "2026-08-06T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "partial-B",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 8,
                },  # duplicate UUID
                {
                    "client_uuid": "partial-C",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 12,
                },  # new
            ],
        },
        headers=auth_headers,
    )
    assert r2.status_code == 200
    # B skipped (duplicate UUID across sessions), C inserted
    assert len(r2.json()["sets"]) == 1


@pytest.mark.asyncio
async def test_complete_session_invalid_exercise_id(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """PUT with invalid exercise_id → rollback, session stays in_progress."""
    session = await _create_session(client, auth_headers)

    resp = await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json={
            "client_uuid": "test-session-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "bad-fk-001",
                    "exercise_id": 99999,
                    "set_number": 1,
                    "reps": 10,
                },
            ],
        },
        headers=auth_headers,
    )
    assert resp.status_code == 422

    # Session should still be in_progress (rollback worked)
    r = await client.get(f"/api/v1/sessions/{session['id']}", headers=auth_headers)
    assert r.json()["status"] == "in_progress"


@pytest.mark.asyncio
async def test_complete_session_duplicate_uuids_in_payload(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """Same UUID appears twice in one payload → only first inserted."""
    ex = await _create_exercise(db_session)
    session = await _create_session(client, auth_headers)

    resp = await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json={
            "client_uuid": "test-session-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "dup-in-payload",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 5,
                },
                {
                    "client_uuid": "dup-in-payload",
                    "exercise_id": ex.id,
                    "set_number": 2,
                    "reps": 5,
                },
            ],
        },
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert len(resp.json()["sets"]) == 1  # deduped within payload


# ========== List / Detail / Delete ==========


@pytest.mark.asyncio
async def test_list_sessions(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """GET /sessions returns paginated list."""
    # 同一用户同时只允许一个进行中会话：逐个创建后完成，再建下一个
    for i in range(3):
        started_at = f"2026-08-0{i+1}T10:00:00Z"
        created = await client.post(
            "/api/v1/sessions",
            json={
                "client_uuid": f"list-{i:03d}",
                "started_at": started_at,
            },
            headers=auth_headers,
        )
        assert created.status_code == 201
        await client.put(
            f"/api/v1/sessions/{created.json()['id']}/complete",
            json={
                "client_uuid": f"list-{i:03d}",
                "started_at": started_at,
                "completed_at": "2026-08-07T10:00:00Z",
                "sets": [],
            },
            headers=auth_headers,
        )

    resp = await client.get("/api/v1/sessions", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3
    assert len(data["items"]) == 3


@pytest.mark.asyncio
async def test_list_sessions_filter_status(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """GET /sessions?status=completed only returns completed."""
    # Create + complete one session
    await _create_exercise(db_session)
    session = await _create_session(client, auth_headers)
    await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json={
            "client_uuid": "test-session-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [],
        },
        headers=auth_headers,
    )

    # Create another session left in_progress
    await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "in-progress-001", "started_at": "2026-08-06T10:00:00Z"},
        headers=auth_headers,
    )

    resp = await client.get(
        "/api/v1/sessions", params={"status": "completed"}, headers=auth_headers
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1


@pytest.mark.asyncio
async def test_list_sessions_filter_date_range(client: AsyncClient, auth_headers: dict):
    """GET /sessions with date range filters correctly."""
    # 同一用户同时只允许一个进行中会话：逐个创建后完成，再建下一个
    for i in range(3):
        started_at = f"2026-08-0{i+1}T10:00:00Z"
        created = await client.post(
            "/api/v1/sessions",
            json={
                "client_uuid": f"date-{i:03d}",
                "started_at": started_at,
            },
            headers=auth_headers,
        )
        assert created.status_code == 201
        await client.put(
            f"/api/v1/sessions/{created.json()['id']}/complete",
            json={
                "client_uuid": f"date-{i:03d}",
                "started_at": started_at,
                "completed_at": "2026-08-07T10:00:00Z",
                "sets": [],
            },
            headers=auth_headers,
        )

    resp = await client.get(
        "/api/v1/sessions",
        params={
            "start_date": "2026-08-01T00:00:00Z",
            "end_date": "2026-08-02T23:59:59Z",
        },
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    # Should only include Aug 1 and Aug 2 sessions
    assert data["total"] == 2


@pytest.mark.asyncio
async def test_list_sessions_other_user_isolation(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """User A's sessions don't appear in User B's list."""
    from app.core.security import get_password_hash

    user_b = User(
        email="b@test.com",
        username="userB",
        hashed_password=get_password_hash("pw"),
        is_active=True,
        is_verified=True,
    )
    db_session.add(user_b)
    await db_session.commit()

    from app.crud.workout import session_crud
    from app.schemas.workout import SessionCreate

    await session_crud.create(
        db_session,
        SessionCreate(client_uuid="user-b-session", started_at="2026-08-05T10:00:00Z"),
        user_b.id,
    )

    # auth_headers is for test_user_verified
    resp = await client.get("/api/v1/sessions", headers=auth_headers)
    assert resp.status_code == 200
    # User B's session should not appear
    for item in resp.json()["items"]:
        assert item["user_id"] != user_b.id


@pytest.mark.asyncio
async def test_get_session_detail(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """GET /sessions/{id} returns session with sets."""
    ex = await _create_exercise(db_session)
    session = await _create_session(client, auth_headers)
    await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json={
            "client_uuid": "test-session-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "detail-set-1",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 10,
                },
            ],
        },
        headers=auth_headers,
    )

    resp = await client.get(f"/api/v1/sessions/{session['id']}", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "completed"
    assert len(data["sets"]) == 1


@pytest.mark.asyncio
async def test_get_session_wrong_user(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """GET other user's session → 404."""
    from app.core.security import get_password_hash

    user_b = User(
        email="c@test.com",
        username="userC",
        hashed_password=get_password_hash("pw"),
        is_active=True,
        is_verified=True,
    )
    db_session.add(user_b)
    await db_session.commit()

    from app.crud.workout import session_crud
    from app.schemas.workout import SessionCreate

    session = await session_crud.create(
        db_session,
        SessionCreate(client_uuid="user-c-session", started_at="2026-08-05T10:00:00Z"),
        user_b.id,
    )

    resp = await client.get(f"/api/v1/sessions/{session.id}", headers=auth_headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_session(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """DELETE /sessions/{id} returns 204, subsequent GET returns 404."""
    session = await _create_session(client, auth_headers)
    sid = session["id"]

    resp = await client.delete(f"/api/v1/sessions/{sid}", headers=auth_headers)
    assert resp.status_code == 204

    resp = await client.get(f"/api/v1/sessions/{sid}", headers=auth_headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_session_wrong_user(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """DELETE other user's session → 404."""
    from app.core.security import get_password_hash

    user_b = User(
        email="d@test.com",
        username="userD",
        hashed_password=get_password_hash("pw"),
        is_active=True,
        is_verified=True,
    )
    db_session.add(user_b)
    await db_session.commit()

    from app.crud.workout import session_crud
    from app.schemas.workout import SessionCreate

    session = await session_crud.create(
        db_session,
        SessionCreate(client_uuid="user-d-session", started_at="2026-08-05T10:00:00Z"),
        user_b.id,
    )

    resp = await client.delete(f"/api/v1/sessions/{session.id}", headers=auth_headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_get_in_progress(client: AsyncClient, auth_headers: dict):
    """GET /sessions/in-progress returns active session."""
    resp = await client.get("/api/v1/sessions/in-progress", headers=auth_headers)
    assert resp.status_code == 404  # none yet

    await _create_session(client, auth_headers)

    resp = await client.get("/api/v1/sessions/in-progress", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["status"] == "in_progress"


# ========== Performance Queries ==========


@pytest.mark.asyncio
async def test_last_performance(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """GET /exercises/{id}/last-performance returns last set data."""
    ex = await _create_exercise(db_session)
    session = await _create_session(client, auth_headers)
    await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json={
            "client_uuid": "test-session-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "perf-set-1",
                    "exercise_id": ex.id,
                    "set_number": 3,
                    "reps": 12,
                    "weight_kg": 70.0,
                    "completed_at": "2026-08-05T10:30:00Z",
                },
            ],
        },
        headers=auth_headers,
    )

    resp = await client.get(
        f"/api/v1/exercises/{ex.id}/last-performance", headers=auth_headers
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["exercise_id"] == ex.id
    assert data["reps"] == 12
    assert data["weight_kg"] == 70.0


@pytest.mark.asyncio
async def test_last_performance_none(client: AsyncClient, auth_headers: dict):
    """Exercise with no history → 404."""
    resp = await client.get(
        "/api/v1/exercises/99999/last-performance", headers=auth_headers
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_last_session_sets(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """GET /exercises/{id}/last-session-sets returns all sets of last session."""
    ex = await _create_exercise(db_session)
    session = await _create_session(client, auth_headers)
    await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json={
            "client_uuid": "test-session-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "lss-1",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 10,
                    "weight_kg": 60.0,
                },
                {
                    "client_uuid": "lss-2",
                    "exercise_id": ex.id,
                    "set_number": 2,
                    "reps": 8,
                    "weight_kg": 65.0,
                },
            ],
        },
        headers=auth_headers,
    )

    resp = await client.get(
        f"/api/v1/exercises/{ex.id}/last-session-sets", headers=auth_headers
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["exercise_id"] == ex.id
    assert len(data["sets"]) == 2
    assert data["sets"][0]["set_number"] == 1
    assert data["sets"][0]["weight_kg"] == 60.0


@pytest.mark.asyncio
async def test_last_session_sets_takes_latest_session(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """Returns sets from the most recent session for the exercise."""
    ex = await _create_exercise(db_session)

    for i in range(2):
        created = await client.post(
            "/api/v1/sessions",
            json={
                "client_uuid": f"lss-sess-{i}",
                "started_at": f"2026-08-0{i+1}T10:00:00Z",
            },
            headers=auth_headers,
        )
        await client.put(
            f"/api/v1/sessions/{created.json()['id']}/complete",
            json={
                "client_uuid": f"lss-sess-{i}",
                "started_at": f"2026-08-0{i+1}T10:00:00Z",
                "completed_at": f"2026-08-0{i+1}T11:00:00Z",
                "sets": [
                    {
                        "client_uuid": f"lss-old-{i}",
                        "exercise_id": ex.id,
                        "set_number": 1,
                        "reps": 10 + i,
                        "weight_kg": 50.0 + i * 5,
                    },
                ],
            },
            headers=auth_headers,
        )

    resp = await client.get(
        f"/api/v1/exercises/{ex.id}/last-session-sets", headers=auth_headers
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["sets"][0]["reps"] == 11  # from the latest session (i=1)


@pytest.mark.asyncio
async def test_last_session_sets_none(client: AsyncClient, auth_headers: dict):
    """Exercise with no history → 404."""
    resp = await client.get(
        "/api/v1/exercises/99999/last-session-sets", headers=auth_headers
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_exercise_history(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """GET /exercises/{id}/history returns paginated list."""
    ex = await _create_exercise(db_session)
    session = await _create_session(client, auth_headers)
    await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json={
            "client_uuid": "test-session-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "hist-1",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 5,
                },
                {
                    "client_uuid": "hist-2",
                    "exercise_id": ex.id,
                    "set_number": 2,
                    "reps": 5,
                },
            ],
        },
        headers=auth_headers,
    )

    resp = await client.get(f"/api/v1/exercises/{ex.id}/history", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 2


@pytest.mark.asyncio
async def test_batch_last_performances(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """GET /sync/last-performances returns dict keyed by exercise_id."""
    ex1 = await _create_exercise(db_session)
    mg_id = ex1.primary_muscle_group_id
    # Create a second exercise reusing the same muscle group
    ex2 = Exercise(
        name="测试动作2",
        name_en="Test Ex 2",
        exercise_type="isolation",
        primary_muscle_group_id=mg_id,
    )
    db_session.add(ex2)
    await db_session.commit()
    await db_session.refresh(ex2)

    session = await _create_session(client, auth_headers)
    await client.put(
        f"/api/v1/sessions/{session['id']}/complete",
        json={
            "client_uuid": "test-session-uuid",
            "started_at": "2026-08-05T10:00:00Z",
            "completed_at": "2026-08-05T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "batch-1",
                    "exercise_id": ex1.id,
                    "set_number": 1,
                    "reps": 10,
                },
            ],
        },
        headers=auth_headers,
    )

    resp = await client.get(
        "/api/v1/sync/last-performances",
        params={"exercise_ids": f"{ex1.id},{ex2.id}"},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert str(ex1.id) in data["performances"]
    assert str(ex2.id) in data["performances"]
    assert data["performances"][str(ex1.id)] is not None  # has data
    assert data["performances"][str(ex2.id)] is None  # no history


@pytest.mark.asyncio
async def test_batch_last_performances_empty_ids(
    client: AsyncClient, auth_headers: dict
):
    """GET /sync/last-performances with empty ids returns empty dict."""
    resp = await client.get(
        "/api/v1/sync/last-performances",
        params={"exercise_ids": ""},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["performances"] == {}


@pytest.mark.asyncio
async def test_performance_requires_auth(client: AsyncClient):
    """Performance endpoints require auth."""
    resp = await client.get("/api/v1/exercises/1/last-performance")
    assert resp.status_code == 401
