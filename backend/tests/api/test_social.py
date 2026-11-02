"""用户搜索与关注。"""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_password_hash, security_manager
from app.models.user import User


async def _make_user(
    db: AsyncSession, username: str, *, is_active: bool = True
) -> tuple[User, dict]:
    user = User(
        email=f"{username}@example.com",
        username=username,
        hashed_password=get_password_hash("pw"),
        is_active=is_active,
        is_verified=True,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    token, _ = security_manager.create_access_token({"user_id": user.id})
    return user, {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_follow_unfollow_idempotent(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    other, _ = await _make_user(db_session, "otheruser")
    target = f"/api/v1/users/{other.id}/follow"

    assert (await client.post(target)).status_code == 401

    first = await client.post(target, headers=auth_headers)
    assert first.status_code == 200
    assert first.json() == {
        "user_id": other.id,
        "following": True,
        "followers_count": 1,
    }
    # 幂等：重复关注不涨
    assert (await client.post(target, headers=auth_headers)).json()[
        "followers_count"
    ] == 1

    off = await client.delete(target, headers=auth_headers)
    assert off.json() == {
        "user_id": other.id,
        "following": False,
        "followers_count": 0,
    }
    # 幂等：未关注时取消也不报错
    assert (await client.delete(target, headers=auth_headers)).json()[
        "followers_count"
    ] == 0


@pytest.mark.asyncio
async def test_follow_self_and_missing_user(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified,
):
    # 关注自己 → 400
    resp = await client.post(
        f"/api/v1/users/{test_user_verified.id}/follow", headers=auth_headers
    )
    assert resp.status_code == 400

    # 不存在 → 404
    assert (
        await client.post("/api/v1/users/9999/follow", headers=auth_headers)
    ).status_code == 404
    assert (
        await client.delete("/api/v1/users/9999/follow", headers=auth_headers)
    ).status_code == 404

    # 已停用 → 404
    inactive, _ = await _make_user(db_session, "ghostuser", is_active=False)
    assert (
        await client.post(f"/api/v1/users/{inactive.id}/follow", headers=auth_headers)
    ).status_code == 404


@pytest.mark.asyncio
async def test_followers_and_following_lists(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified,
):
    b, b_headers = await _make_user(db_session, "bravo")
    c, _ = await _make_user(db_session, "charlie")
    # A(test_user) 关注 B 和 C；B 关注 C
    for target in (b, c):
        assert (
            await client.post(f"/api/v1/users/{target.id}/follow", headers=auth_headers)
        ).status_code == 200
    assert (
        await client.post(f"/api/v1/users/{c.id}/follow", headers=b_headers)
    ).status_code == 200

    # B 的粉丝 = [A]
    followers = await client.get(
        f"/api/v1/users/{b.id}/followers", headers=auth_headers
    )
    assert followers.json()["total"] == 1
    item = followers.json()["items"][0]
    assert item["username"] == "testuser" and item["is_following"] is False

    # A 的关注 = [B, C]；以 B 的视角看，C 是已关注
    following = await client.get(
        f"/api/v1/users/{test_user_verified.id}/following", headers=b_headers
    )
    assert following.json()["total"] == 2
    by_name = {i["username"]: i["is_following"] for i in following.json()["items"]}
    assert by_name == {"bravo": False, "charlie": True}

    # 不存在的用户 → 404
    assert (
        await client.get("/api/v1/users/9999/followers", headers=auth_headers)
    ).status_code == 404
    assert (
        await client.get("/api/v1/users/9999/following", headers=auth_headers)
    ).status_code == 404


@pytest.mark.asyncio
async def test_search_users(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified,
):
    await _make_user(db_session, "otheruser")
    await _make_user(db_session, "zeta", is_active=False)

    # 回归守卫：普通用户可搜索（路由顺序若被挪到管理员 `/{user_id}` 之后会 422）
    resp = await client.get("/api/v1/users/search?q=oth", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert data["items"][0]["username"] == "otheruser"
    assert data["items"][0]["is_following"] is False

    # 排除自己
    assert (
        await client.get("/api/v1/users/search?q=testuser", headers=auth_headers)
    ).json()["total"] == 0

    # 排除停用账号
    assert (
        await client.get("/api/v1/users/search?q=zeta", headers=auth_headers)
    ).json()["total"] == 0

    # 关注状态回填
    other = await client.get("/api/v1/users/search?q=other", headers=auth_headers)
    other_id = other.json()["items"][0]["id"]
    await client.post(f"/api/v1/users/{other_id}/follow", headers=auth_headers)
    again = await client.get("/api/v1/users/search?q=other", headers=auth_headers)
    assert again.json()["items"][0]["is_following"] is True

    # q 缺失/空 → 422；未认证 → 401
    assert (
        await client.get("/api/v1/users/search", headers=auth_headers)
    ).status_code == 422
    assert (
        await client.get("/api/v1/users/search?q=", headers=auth_headers)
    ).status_code == 422
    assert (await client.get("/api/v1/users/search?q=a")).status_code == 401
