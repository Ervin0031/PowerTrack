"""Coach thread and proposal loop. The model is scripted."""

import json

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.main import app
from app.models.exercise import Exercise, MuscleGroup
from app.routers.v1.coach import get_llm
from app.services.coach.llm import AssistantTurn, ToolCall
from app.services.coach.prompts import user_wants_plan
from app.services.coach.tools import ToolContext


class ScriptedLLM:
    async def complete(self, messages, tools, thinking=None):
        tool_messages = [item for item in messages if item.get("role") == "tool"]
        if not tool_messages:
            return AssistantTurn(
                None,
                [ToolCall("s1", "search_exercises", json.dumps({"search": "测试"}))],
            )
        parsed = [json.loads(item["content"]) for item in tool_messages]
        if any(item.get("ok") for item in parsed):
            return AssistantTurn("今天练测试动作，两组正式组。", [])
        exercise_id = parsed[0]["items"][0]["exercise_id"]
        proposal = {
            "title": "测试日",
            "summary": "一组热身，两组正式。",
            "estimated_minutes": 45,
            "exercises": [
                {
                    "exercise_id": exercise_id,
                    "sets": [
                        {
                            "set_number": 1,
                            "set_kind": "warmup",
                            "reps": 12,
                            "weight_kg": 20,
                        },
                        {
                            "set_number": 2,
                            "set_kind": "working",
                            "reps": 8,
                            "weight_kg": 40,
                        },
                    ],
                }
            ],
        }
        return AssistantTurn(
            None,
            [ToolCall("p1", "propose_session", json.dumps(proposal))],
        )


async def _exercise(db: AsyncSession) -> Exercise:
    muscle = MuscleGroup(name="测试肌群", name_en="Test", category="upper")
    db.add(muscle)
    await db.flush()
    exercise = Exercise(
        name="测试动作",
        exercise_type="compound",
        primary_muscle_group_id=muscle.id,
    )
    db.add(exercise)
    await db.commit()
    await db.refresh(exercise)
    return exercise


async def _profile(client: AsyncClient, headers: dict) -> None:
    response = await client.put(
        "/api/v1/users/me/profile",
        json={
            "gender": "male",
            "birthYear": 1990,
            "heightCm": 180,
            "weightKg": 80,
            "goal": "muscle_gain",
            "experience": "intermediate",
            "sessionMinutes": 60,
            "equipment": "gym",
        },
        headers=headers,
    )
    assert response.status_code == 200


def test_analysis_does_not_count_as_a_plan_request():
    assert user_wants_plan("给我分析最近训练数据") is False
    assert user_wants_plan("按我的档案排今天这一堂力量训练") is True


@pytest.mark.asyncio
async def test_propose_blocked_during_chat():
    context = ToolContext(db=None, user_id=1)
    context.allow_plan = False
    context.catalog[1] = {"name": "卧推", "exercise_type": "compound"}
    result = await context.propose_session(
        {
            "title": "推",
            "summary": "练胸",
            "estimated_minutes": 45,
            "exercises": [
                {
                    "exercise_id": 1,
                    "sets": [{"set_number": 1, "set_kind": "working", "reps": 5}],
                }
            ],
        }
    )
    assert "不是要排课" in result["error"]


@pytest.mark.asyncio
async def test_propose_rejects_unknown_exercise():
    context = ToolContext(db=None, user_id=1)
    result = await context.propose_session(
        {
            "title": "推",
            "summary": "练胸",
            "estimated_minutes": 45,
            "exercises": [
                {
                    "exercise_id": 9,
                    "sets": [
                        {
                            "set_number": 1,
                            "set_kind": "working",
                            "reps": 5,
                        }
                    ],
                }
            ],
        }
    )
    assert "error" in result


@pytest.mark.asyncio
async def test_suggest_next_rejects_exercise_already_in_session():
    context = ToolContext(db=None, user_id=1, blocked_ids={3})
    context.catalog[3] = {"name": "卧推", "exercise_type": "compound"}
    result = await context.suggest_next(
        {
            "reason": "继续练胸",
            "exercise": {
                "exercise_id": 3,
                "sets": [
                    {
                        "set_number": 1,
                        "set_kind": "working",
                        "reps": 8,
                        "weight_kg": 40,
                    }
                ],
            },
        }
    )
    assert "已经在练" in result["error"]


@pytest.mark.asyncio
async def test_list_threads(client: AsyncClient, auth_headers: dict):
    created = await client.post("/api/v1/coach/threads", headers=auth_headers)
    assert created.status_code == 200
    thread_id = created.json()["id"]
    listed = await client.get("/api/v1/coach/threads", headers=auth_headers)
    assert listed.status_code == 200
    assert listed.json()[0]["id"] == thread_id
    assert listed.json()[0]["title"] == "新对话"
    detail = await client.get(
        f"/api/v1/coach/threads/{thread_id}",
        headers=auth_headers,
    )
    assert detail.status_code == 200
    assert detail.json()["messages"] == []


@pytest.mark.asyncio
async def test_message_requires_auth(client: AsyncClient):
    response = await client.post("/api/v1/coach/threads/1/messages", json={})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_message_requires_profile(client: AsyncClient, auth_headers: dict):
    app.dependency_overrides[get_llm] = lambda: ScriptedLLM()
    created = await client.post("/api/v1/coach/threads", headers=auth_headers)
    assert created.status_code == 200
    response = await client.post(
        f"/api/v1/coach/threads/{created.json()['id']}/messages",
        json={},
        headers=auth_headers,
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_scripted_proposal(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    await _exercise(db_session)
    await _profile(client, auth_headers)
    app.dependency_overrides[get_llm] = lambda: ScriptedLLM()
    created = await client.post("/api/v1/coach/threads", headers=auth_headers)
    thread_id = created.json()["id"]
    response = await client.post(
        f"/api/v1/coach/threads/{thread_id}/messages",
        json={"content": "今天练推"},
        headers=auth_headers,
    )
    assert response.status_code == 200
    body = response.text
    assert "event: proposal" in body
    assert "测试动作" in body
    assert "event: message" in body
    assert "两组正式组" in body


_PROPOSAL = {
    "title": "测试日",
    "summary": "一组热身，两组正式。",
    "estimated_minutes": 45,
    "exercises": [
        {
            "exercise_id": 1,
            "name": "卧推",
            "exercise_type": "compound",
            "image_url": "https://cdn.example.com/1-thumb.jpg",
            "sets": [
                {"set_number": 1, "set_kind": "working", "reps": 8, "weight_kg": 40}
            ],
        }
    ],
}


async def _other_headers(db_session: AsyncSession) -> dict:
    from app.core.security import get_password_hash, security_manager
    from app.models.user import User

    user = User(
        email="other@example.com",
        username="otheruser",
        hashed_password=get_password_hash("testpassword"),
        is_active=True,
        is_verified=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    token, _ = security_manager.create_access_token({"user_id": user.id})
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_import_turn_requires_auth(client: AsyncClient):
    response = await client.post(
        "/api/v1/coach/threads/1/messages/import",
        json={"user_content": "你好", "assistant_content": "在"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_import_turn_rejects_other_users_thread(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
):
    other = await _other_headers(db_session)
    created = await client.post("/api/v1/coach/threads", headers=other)
    response = await client.post(
        f"/api/v1/coach/threads/{created.json()['id']}/messages/import",
        json={"user_content": "你好", "assistant_content": "在"},
        headers=auth_headers,
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_import_turn_persists_messages(
    client: AsyncClient,
    auth_headers: dict,
):
    created = await client.post("/api/v1/coach/threads", headers=auth_headers)
    thread_id = created.json()["id"]
    response = await client.post(
        f"/api/v1/coach/threads/{thread_id}/messages/import",
        json={
            "user_content": "按档案排今天这一堂",
            "assistant_content": "练推，两组正式组。",
            "proposal": _PROPOSAL,
            "trace": [
                {
                    "kind": "tool",
                    "title": "读取档案",
                    "detail": "增肌 · 中级",
                    "state": "done",
                }
            ],
        },
        headers=auth_headers,
    )
    assert response.status_code == 204

    detail = await client.get(
        f"/api/v1/coach/threads/{thread_id}", headers=auth_headers
    )
    messages = detail.json()["messages"]
    assert [item["role"] for item in messages] == ["user", "assistant"]
    assert messages[0]["content"] == "按档案排今天这一堂"
    assert messages[1]["proposal"]["title"] == "测试日"
    assert (
        messages[1]["proposal"]["exercises"][0]["image_url"]
        == "https://cdn.example.com/1-thumb.jpg"
    )
    assert messages[1]["trace"][0]["title"] == "读取档案"

    listed = await client.get("/api/v1/coach/threads", headers=auth_headers)
    assert listed.json()[0]["title"] == "按档案排今天这一堂"


@pytest.mark.asyncio
async def test_import_turn_rejects_invalid_proposal(
    client: AsyncClient,
    auth_headers: dict,
):
    created = await client.post("/api/v1/coach/threads", headers=auth_headers)
    response = await client.post(
        f"/api/v1/coach/threads/{created.json()['id']}/messages/import",
        json={
            "user_content": "排课",
            "assistant_content": "好",
            "proposal": {**_PROPOSAL, "estimated_minutes": 1},
        },
        headers=auth_headers,
    )
    assert response.status_code == 422
