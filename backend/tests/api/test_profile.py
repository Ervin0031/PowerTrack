"""Fitness profile metrics + API."""

from datetime import datetime, timezone

import pytest
from httpx import AsyncClient

from app.services.metrics import compute_metrics


def test_mifflin_female_example():
    # 1995 年出生、2026 年 → 31 岁；女 58kg 165cm
    m = compute_metrics(
        gender="female",
        birth_year=1995,
        height_cm=165,
        weight_kg=58,
        goal="fat_loss",
        experience="beginner",
        weekly_days=3,
        now=datetime(2026, 9, 11, tzinfo=timezone.utc),
    )
    assert m.age == 31
    # 10*58 + 6.25*165 - 5*31 - 161 = 1295.25
    assert m.bmr == pytest.approx(1295.25, abs=0.1)
    assert m.activity_factor == 1.55
    assert m.calorie_target == pytest.approx(m.tdee - 400, abs=0.1)
    assert m.max_hr == pytest.approx(208 - 0.7 * 31, abs=0.1)


def test_undisclosed_gender_averages_formulas():
    m = compute_metrics(
        gender="undisclosed",
        birth_year=1995,
        height_cm=165,
        weight_kg=58,
        goal="health",
        experience="beginner",
        now=datetime(2026, 9, 11, tzinfo=timezone.utc),
    )
    male = 10 * 58 + 6.25 * 165 - 5 * 31 + 5
    female = 10 * 58 + 6.25 * 165 - 5 * 31 - 161
    assert m.bmr == round((male + female) / 2, 1)


@pytest.mark.asyncio
async def test_profile_get_empty(client: AsyncClient, auth_headers: dict):
    resp = await client.get("/api/v1/users/me/profile", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["complete"] is False
    assert data["profile"] is None


@pytest.mark.asyncio
async def test_profile_upsert_and_metrics(client: AsyncClient, auth_headers: dict):
    payload = {
        "gender": "female",
        "birthYear": 1995,
        "heightCm": 165,
        "weightKg": 58,
        "goal": "fat_loss",
        "experience": "beginner",
        "injuryTags": ["knee"],
        "weeklyDays": 3,
        "sessionMinutes": 45,
    }
    put = await client.put(
        "/api/v1/users/me/profile", json=payload, headers=auth_headers
    )
    assert put.status_code == 200
    body = put.json()
    assert body["complete"] is True
    profile = body["profile"]
    assert profile["gender"] == "female"
    assert profile["injury_tags"] == ["knee"]
    assert profile["metrics"]["age"] == 31
    assert profile["metrics"]["bmr"] == pytest.approx(1295.25, abs=0.1)
    assert profile["metrics"]["split_name"]

    again = await client.get("/api/v1/users/me/profile", headers=auth_headers)
    assert again.json()["complete"] is True
    assert again.json()["profile"]["weekly_days"] == 3


@pytest.mark.asyncio
async def test_profile_requires_auth(client: AsyncClient):
    resp = await client.get("/api/v1/users/me/profile")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_profile_rejects_out_of_range(client: AsyncClient, auth_headers: dict):
    resp = await client.put(
        "/api/v1/users/me/profile",
        json={
            "gender": "female",
            "birth_year": 1995,
            "height_cm": 80,
            "weight_kg": 58,
            "goal": "fat_loss",
            "experience": "beginner",
        },
        headers=auth_headers,
    )
    assert resp.status_code == 422
