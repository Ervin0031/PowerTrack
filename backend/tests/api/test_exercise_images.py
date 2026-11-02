"""Tests for the stable exercise image endpoints."""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup

FAKE_OBJECTS = {
    "k1": (b"\xff\xd8fake-jpeg-bytes", "image/jpeg"),
    "k2": (b"\xff\xd8fake-thumb-bytes", "image/jpeg"),
}


async def _exercise(
    db: AsyncSession, *, image_key: str | None, thumb_key: str | None
) -> Exercise:
    mg = MuscleGroup(name="胸部", name_en="Chest", category="upper")
    db.add(mg)
    await db.flush()
    ex = Exercise(
        name="杠铃卧推",
        name_en="Barbell Bench Press",
        exercise_type="compound",
        primary_muscle_group_id=mg.id,
        image_key=image_key,
        thumb_key=thumb_key,
    )
    db.add(ex)
    await db.commit()
    await db.refresh(ex)
    return ex


@pytest.fixture
def fake_storage(monkeypatch) -> list[str]:
    """Stub storage reads; returns the list of keys actually fetched."""
    fetched: list[str] = []

    async def _fetch(key):
        fetched.append(key)
        return FAKE_OBJECTS.get(key)

    monkeypatch.setattr("app.routers.v1.exercises.storage_service.fetch", _fetch)
    return fetched


async def test_image_returns_bytes_with_cache_headers(
    client: AsyncClient, db_session: AsyncSession, fake_storage: list[str]
):
    ex = await _exercise(db_session, image_key="k1", thumb_key="k2")

    resp = await client.get(f"/api/v1/exercises/{ex.id}/image")

    assert resp.status_code == 200
    assert resp.headers["content-type"] == "image/jpeg"
    assert resp.headers["etag"] == '"k1"'
    assert resp.headers["cache-control"] == "public, max-age=86400"
    assert resp.content == FAKE_OBJECTS["k1"][0]
    assert fake_storage == ["k1"]


async def test_image_etag_hit_returns_304_without_storage(
    client: AsyncClient, db_session: AsyncSession, fake_storage: list[str]
):
    ex = await _exercise(db_session, image_key="k1", thumb_key="k2")

    resp = await client.get(
        f"/api/v1/exercises/{ex.id}/image", headers={"If-None-Match": '"k1"'}
    )

    assert resp.status_code == 304
    assert fake_storage == []  # 304 不碰对象存储


async def test_thumb_falls_back_to_image_key(
    client: AsyncClient, db_session: AsyncSession, fake_storage: list[str]
):
    ex = await _exercise(db_session, image_key="k1", thumb_key=None)

    resp = await client.get(f"/api/v1/exercises/{ex.id}/thumb")

    assert resp.status_code == 200
    assert resp.content == FAKE_OBJECTS["k1"][0]
    assert fake_storage == ["k1"]


async def test_missing_image_and_unknown_exercise_return_404(
    client: AsyncClient, db_session: AsyncSession, fake_storage: list[str]
):
    ex = await _exercise(db_session, image_key=None, thumb_key=None)

    assert (await client.get(f"/api/v1/exercises/{ex.id}/image")).status_code == 404
    assert (await client.get(f"/api/v1/exercises/{ex.id}/thumb")).status_code == 404
    assert (await client.get("/api/v1/exercises/999999/image")).status_code == 404
    assert fake_storage == []


async def test_list_urls_point_at_stable_thumb_endpoint(
    client: AsyncClient, db_session: AsyncSession
):
    ex = await _exercise(db_session, image_key="k1", thumb_key="k2")

    resp = await client.get("/api/v1/exercises")

    assert resp.status_code == 200
    item = next(i for i in resp.json()["items"] if i["id"] == ex.id)
    expected = f"http://test/api/v1/exercises/{ex.id}/thumb?v=k2"
    assert item["image_url"] == expected
    assert item["thumb_url"] == expected


async def test_detail_urls_image_is_original_thumb_is_thumbnail(
    client: AsyncClient, db_session: AsyncSession
):
    ex = await _exercise(db_session, image_key="k1", thumb_key="k2")

    resp = await client.get(f"/api/v1/exercises/{ex.id}")

    assert resp.status_code == 200
    body = resp.json()
    assert body["image_url"] == f"http://test/api/v1/exercises/{ex.id}/image?v=k1"
    assert body["thumb_url"] == f"http://test/api/v1/exercises/{ex.id}/thumb?v=k2"
