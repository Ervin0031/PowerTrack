"""社交动态流：分享快照、关注流、评论、点赞。"""

from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup
from app.services.feed import (
    MUSCLE_HIGHLIGHT_MAX,
    PR_HIGHLIGHT_MAX,
    build_session_snapshot,
    parse_highlights,
)

DAY = "2026-10-01"


def _row(
    set_id, set_number, exercise_id, name, muscle, reps, weight, rpe, kind="working"
):
    return (set_id, set_number, exercise_id, name, muscle, reps, weight, rpe, kind)


def _snapshot(rows, prior_rows=(), **overrides):
    kwargs = dict(
        session_id=7,
        started_at=datetime(2026, 10, 1, 10, 0),
        completed_at=datetime(2026, 10, 1, 11, 0),
        notes=None,
    )
    kwargs.update(overrides)
    return build_session_snapshot(rows, list(prior_rows), **kwargs)


def test_snapshot_first_time_counts_as_pr():
    rows = [
        _row(1, 1, 10, "杠铃卧推", "胸部", 12, 40.0, 9.0, "warmup"),
        _row(2, 2, 10, "杠铃卧推", "胸部", 8, 60.0, 8.0),
        _row(3, 3, 10, "杠铃卧推", "胸部", 8, 60.0, 8.5),
    ]
    snap = _snapshot(rows)
    assert snap["schema_version"] == 1
    assert snap["total_sets"] == 2  # warmup 不计
    assert snap["hard_sets"] == 2
    assert snap["exercises_count"] == 1
    assert snap["total_volume_kg"] == 960.0
    assert snap["duration_seconds"] == 3600
    assert snap["started_at"] == "2026-10-01T10:00:00"
    assert snap["muscles"] == [{"name": "胸部", "hard_sets": 2, "volume": 960.0}]
    # 首次做 → 算 PR，previous/improvement 为 null
    pr = snap["prs"][0]
    assert pr["exercise_name"] == "杠铃卧推"
    # 同重量下 RPE 8.0 的 e1RM（≈81.2）高于 RPE 8.5（≈80.0）→ 取第 2 组
    assert pr["set_id"] == 2
    assert pr["previous_best_kg"] is None and pr["improvement_kg"] is None
    assert pr["estimated_1rm_kg"] == pytest.approx(81.2, abs=0.1)


def test_snapshot_pr_only_when_improved():
    rows = [_row(1, 1, 10, "杠铃卧推", "胸部", 8, 60.0, 8.0)]  # e1RM ≈ 81.2
    assert _snapshot(rows, [(10, 8, 60.0, 8.0)])["prs"] == []  # 持平不算
    assert _snapshot(rows, [(10, 8, 70.0, 8.5)])["prs"] == []  # 更高纪录不算

    snap = _snapshot(rows, [(10, 8, 57.5, 8.0)])  # prior ≈ 77.8
    pr = snap["prs"][0]
    assert pr["previous_best_kg"] == pytest.approx(77.8, abs=0.1)
    assert pr["improvement_kg"] == pytest.approx(3.4, abs=0.1)


def test_snapshot_muscle_top5_and_pr_top5():
    rows = []
    sid = 0
    for i in range(7):
        sid += 1
        # 7 个动作各自肌群，volume 递减 → 只留前 5
        rows.append(
            _row(sid, 1, 100 + i, f"动作{i}", f"肌群{i}", 10, 100.0 - i * 10, 9.0)
        )
    snap = _snapshot(rows)
    assert len(snap["muscles"]) == MUSCLE_HIGHLIGHT_MAX
    assert [m["name"] for m in snap["muscles"]] == [f"肌群{i}" for i in range(5)]
    assert len(snap["prs"]) == PR_HIGHLIGHT_MAX
    # PR 按 e1RM 降序
    ests = [pr["estimated_1rm_kg"] for pr in snap["prs"]]
    assert ests == sorted(ests, reverse=True)


def test_parse_highlights_tolerant():
    assert parse_highlights(None) is None
    assert parse_highlights("") is None
    assert parse_highlights("{not json") is None
    assert parse_highlights("[1, 2]") is None
    assert parse_highlights('{"a": 1}') == {"a": 1}


# ========== API ==========


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


async def _complete_session(client, headers, ex, *, day, prefix, sets) -> int:
    created = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": f"{prefix}-s", "started_at": f"{day}T10:00:00Z"},
        headers=headers,
    )
    assert created.status_code == 201
    session_id = created.json()["id"]
    payload_sets = [
        {
            "client_uuid": f"{prefix}-set-{i}",
            "exercise_id": ex.id,
            "set_number": i,
            "completed_at": f"{day}T10:{i:02d}:00Z",
            **s,
        }
        for i, s in enumerate(sets, start=1)
    ]
    done = await client.put(
        f"/api/v1/sessions/{session_id}/complete",
        json={
            "client_uuid": f"{prefix}-s",
            "started_at": f"{day}T10:00:00Z",
            "completed_at": f"{day}T11:00:00Z",
            "sets": payload_sets,
        },
        headers=headers,
    )
    assert done.status_code == 200
    return session_id


async def _second_user(db_session: AsyncSession):
    """第二个普通用户 + 其认证头。"""
    from app.core.security import get_password_hash, security_manager
    from app.models.user import User

    user = User(
        email="other@example.com",
        username="otheruser",
        hashed_password=get_password_hash("pw"),
        is_active=True,
        is_verified=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    token, _ = security_manager.create_access_token({"user_id": user.id})
    return user, {"Authorization": f"Bearer {token}"}


def _today(offset: int = 0) -> str:
    return (datetime.now(timezone.utc) + timedelta(days=offset)).date().isoformat()


ACCESSORY_SET = {"reps": 8, "weight_kg": 60.0, "rpe": 8.0}


@pytest.mark.asyncio
async def test_share_requires_completed_own_session(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _create_exercise(db_session)
    # 未认证
    assert (await client.post("/api/v1/sessions/1/share")).status_code == 401

    # 进行中 → 409
    created = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "feed-inprogress", "started_at": f"{_today()}T10:00:00Z"},
        headers=auth_headers,
    )
    session_id = created.json()["id"]
    resp = await client.post(
        f"/api/v1/sessions/{session_id}/share", headers=auth_headers
    )
    assert resp.status_code == 409

    # 结束该会话后，别人的分享尝试 → 404
    done = await client.put(
        f"/api/v1/sessions/{session_id}/complete",
        json={
            "client_uuid": "feed-inprogress",
            "started_at": f"{_today()}T10:00:00Z",
            "completed_at": f"{_today()}T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "feed-inprogress-set-1",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "completed_at": f"{_today()}T10:10:00Z",
                    **ACCESSORY_SET,
                }
            ],
        },
        headers=auth_headers,
    )
    assert done.status_code == 200
    _, other_headers = await _second_user(db_session)
    resp = await client.post(
        f"/api/v1/sessions/{session_id}/share", headers=other_headers
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_share_first_time_is_pr_and_idempotent(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    from sqlalchemy import func, select

    from app.models.feed import FeedPost

    ex = await _create_exercise(db_session)
    session_id = await _complete_session(
        client,
        auth_headers,
        ex,
        day=_today(),
        prefix="feed-first",
        sets=[
            {"reps": 12, "weight_kg": 40.0, "rpe": 9.0, "set_kind": "warmup"},
            ACCESSORY_SET,
        ],
    )
    resp = await client.post(
        f"/api/v1/sessions/{session_id}/share",
        json={"caption": "开练"},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["session_id"] == session_id
    assert data["caption"] == "开练"
    assert data["like_count"] == 0 and data["comment_count"] == 0
    snap = data["highlights"]
    assert snap["schema_version"] == 1
    assert snap["total_sets"] == 1  # warmup 不计
    assert snap["hard_sets"] == 1
    assert snap["total_volume_kg"] == 480.0
    assert snap["duration_seconds"] == 3600
    assert snap["muscles"][0]["name"] == "胸部"
    pr = snap["prs"][0]
    assert pr["previous_best_kg"] is None and pr["improvement_kg"] is None
    assert pr["estimated_1rm_kg"] == pytest.approx(81.2, abs=0.1)
    # 时间字段由中间件补 Z
    assert snap["started_at"].endswith("Z")
    assert data["created_at"].endswith("Z")

    # 重复分享 → 同一条动态，表里仍只有一行
    again = await client.post(
        f"/api/v1/sessions/{session_id}/share",
        json={"caption": "改个文案"},
        headers=auth_headers,
    )
    assert again.status_code == 200
    assert again.json()["id"] == data["id"]
    assert again.json()["caption"] == "改个文案"
    total = (
        await db_session.execute(select(func.count()).select_from(FeedPost))
    ).scalar()
    assert total == 1


@pytest.mark.asyncio
async def test_share_pr_progression(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _create_exercise(db_session)
    # 昨天 60kg → 今天 60kg（持平）不算 PR
    await _complete_session(
        client, auth_headers, ex, day=_today(-1), prefix="feed-a", sets=[ACCESSORY_SET]
    )
    flat_id = await _complete_session(
        client, auth_headers, ex, day=_today(), prefix="feed-b", sets=[ACCESSORY_SET]
    )
    flat = await client.post(f"/api/v1/sessions/{flat_id}/share", headers=auth_headers)
    assert flat.json()["highlights"]["prs"] == []

    # 明天 70kg → 破纪录
    up_id = await _complete_session(
        client,
        auth_headers,
        ex,
        day=_today(1),
        prefix="feed-c",
        sets=[{"reps": 8, "weight_kg": 70.0, "rpe": 8.0}],
    )
    up = await client.post(f"/api/v1/sessions/{up_id}/share", headers=auth_headers)
    pr = up.json()["highlights"]["prs"][0]
    assert pr["weight_kg"] == 70.0
    assert pr["previous_best_kg"] == pytest.approx(81.2, abs=0.1)
    assert pr["improvement_kg"] == pytest.approx(13.5, abs=0.1)


@pytest.mark.asyncio
async def test_feed_visibility_and_order(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified,
):
    from app.models.feed import Follow

    ex = await _create_exercise(db_session)
    ids = []
    for i, prefix in enumerate(("feed-v1", "feed-v2")):
        sid = await _complete_session(
            client,
            auth_headers,
            ex,
            day=_today(i),
            prefix=prefix,
            sets=[ACCESSORY_SET],
        )
        resp = await client.post(f"/api/v1/sessions/{sid}/share", headers=auth_headers)
        ids.append(resp.json()["id"])

    # 自己两条倒序可见
    mine = await client.get("/api/v1/feed", headers=auth_headers)
    assert mine.status_code == 200
    assert mine.json()["total"] == 2
    assert [i["id"] for i in mine.json()["items"]] == [ids[1], ids[0]]

    # 未关注 → 看不到
    other, other_headers = await _second_user(db_session)
    unseen = await client.get("/api/v1/feed", headers=other_headers)
    assert unseen.json()["total"] == 0

    # 关注后可见
    db_session.add(Follow(follower_id=other.id, followee_id=test_user_verified.id))
    await db_session.commit()
    seen = await client.get("/api/v1/feed", headers=other_headers)
    assert seen.json()["total"] == 2
    assert seen.json()["items"][0]["author_username"] == "testuser"

    # 分页
    page = await client.get("/api/v1/feed?skip=1&limit=1", headers=auth_headers)
    assert page.json()["total"] == 2
    assert [i["id"] for i in page.json()["items"]] == [ids[0]]


@pytest.mark.asyncio
async def test_comments_and_set_reference(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified,
):
    ex = await _create_exercise(db_session)
    session_id = await _complete_session(
        client, auth_headers, ex, day=_today(), prefix="feed-cm", sets=[ACCESSORY_SET]
    )
    post_id = (
        await client.post(f"/api/v1/sessions/{session_id}/share", headers=auth_headers)
    ).json()["id"]
    detail = await client.get(f"/api/v1/sessions/{session_id}", headers=auth_headers)
    set_id = detail.json()["sets"][0]["id"]

    other, other_headers = await _second_user(db_session)
    # 不可见用户的评论尝试 → 404
    resp = await client.post(
        f"/api/v1/feed/posts/{post_id}/comments",
        json={"body": "看不到"},
        headers=other_headers,
    )
    assert resp.status_code == 404

    # 关注后可以评论，且能带组引用
    from app.models.feed import Follow

    db_session.add(Follow(follower_id=other.id, followee_id=test_user_verified.id))
    await db_session.commit()
    resp = await client.post(
        f"/api/v1/feed/posts/{post_id}/comments",
        json={"body": "  这组很稳  ", "setId": set_id},
        headers=other_headers,
    )
    assert resp.status_code == 201
    comment = resp.json()
    assert comment["body"] == "这组很稳"
    assert comment["author_username"] == "otheruser"
    assert comment["set"]["set_id"] == set_id
    assert comment["set"]["set_number"] == 1
    assert comment["set"]["exercise_name"] == "杠铃卧推"

    # 别的会话的组 id → 400
    other_session = await _complete_session(
        client,
        auth_headers,
        ex,
        day=_today(),
        prefix="feed-other-s",
        sets=[ACCESSORY_SET],
    )
    other_detail = await client.get(
        f"/api/v1/sessions/{other_session}", headers=auth_headers
    )
    foreign_set_id = other_detail.json()["sets"][0]["id"]
    bad = await client.post(
        f"/api/v1/feed/posts/{post_id}/comments",
        json={"body": "x", "setId": foreign_set_id},
        headers=other_headers,
    )
    assert bad.status_code == 400

    # 全空白 body → 422
    blank = await client.post(
        f"/api/v1/feed/posts/{post_id}/comments",
        json={"body": "   "},
        headers=other_headers,
    )
    assert blank.status_code == 422

    # 评论列表倒序可见（作者自己可看）
    listed = await client.get(
        f"/api/v1/feed/posts/{post_id}/comments", headers=auth_headers
    )
    assert listed.json()["total"] == 1
    assert listed.json()["items"][0]["id"] == comment["id"]

    # 删别人的评论 → 403；本人 → 204
    assert (
        await client.delete(
            f"/api/v1/feed/comments/{comment['id']}", headers=auth_headers
        )
    ).status_code == 403
    assert (
        await client.delete(
            f"/api/v1/feed/comments/{comment['id']}", headers=other_headers
        )
    ).status_code == 204


@pytest.mark.asyncio
async def test_like_idempotent(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified,
):
    ex = await _create_exercise(db_session)
    session_id = await _complete_session(
        client, auth_headers, ex, day=_today(), prefix="feed-lk", sets=[ACCESSORY_SET]
    )
    post_id = (
        await client.post(f"/api/v1/sessions/{session_id}/share", headers=auth_headers)
    ).json()["id"]
    other, other_headers = await _second_user(db_session)

    first = await client.post(
        f"/api/v1/feed/posts/{post_id}/like", headers=other_headers
    )
    assert first.status_code == 404  # 未关注不可见

    from app.models.feed import Follow

    db_session.add(Follow(follower_id=other.id, followee_id=test_user_verified.id))
    await db_session.commit()

    first = await client.post(
        f"/api/v1/feed/posts/{post_id}/like", headers=other_headers
    )
    assert first.json() == {"post_id": post_id, "like_count": 1, "liked_by_me": True}
    # 幂等：重复点赞不涨
    again = await client.post(
        f"/api/v1/feed/posts/{post_id}/like", headers=other_headers
    )
    assert again.json()["like_count"] == 1

    # 作者自赞 → 2；取消 → 1；再取消仍 → 1
    assert (
        await client.post(f"/api/v1/feed/posts/{post_id}/like", headers=auth_headers)
    ).json()["like_count"] == 2
    assert (
        await client.delete(f"/api/v1/feed/posts/{post_id}/like", headers=auth_headers)
    ).json()["like_count"] == 1
    assert (
        await client.delete(f"/api/v1/feed/posts/{post_id}/like", headers=auth_headers)
    ).json()["like_count"] == 1

    # 流里带得回计数与本人状态
    feed = await client.get("/api/v1/feed", headers=other_headers)
    item = feed.json()["items"][0]
    assert item["like_count"] == 1 and item["liked_by_me"] is True


@pytest.mark.asyncio
async def test_delete_post_cascades(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified,
):
    from sqlalchemy import func, select

    from app.models.feed import FeedComment, FeedLike, Follow

    ex = await _create_exercise(db_session)
    session_id = await _complete_session(
        client, auth_headers, ex, day=_today(), prefix="feed-del", sets=[ACCESSORY_SET]
    )
    post_id = (
        await client.post(f"/api/v1/sessions/{session_id}/share", headers=auth_headers)
    ).json()["id"]
    other, other_headers = await _second_user(db_session)
    db_session.add(Follow(follower_id=other.id, followee_id=test_user_verified.id))
    await db_session.commit()
    await client.post(
        f"/api/v1/feed/posts/{post_id}/comments",
        json={"body": "好"},
        headers=other_headers,
    )
    await client.post(f"/api/v1/feed/posts/{post_id}/like", headers=other_headers)

    # 非作者删 → 404
    assert (
        await client.delete(f"/api/v1/feed/posts/{post_id}", headers=other_headers)
    ).status_code == 404
    assert (
        await client.delete(f"/api/v1/feed/posts/{post_id}", headers=auth_headers)
    ).status_code == 204

    for model in (FeedComment, FeedLike):
        count = (
            await db_session.execute(select(func.count()).select_from(model))
        ).scalar()
        assert count == 0
    # 原训练记录不受影响
    assert (
        await client.get(f"/api/v1/sessions/{session_id}", headers=auth_headers)
    ).status_code == 200


@pytest.mark.asyncio
async def test_feed_survives_session_deletion(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    """核心回归：分享后删训练 → 动态完好，快照仍可画，session_id 置空。"""
    ex = await _create_exercise(db_session)
    session_id = await _complete_session(
        client, auth_headers, ex, day=_today(), prefix="feed-keep", sets=[ACCESSORY_SET]
    )
    post = (
        await client.post(f"/api/v1/sessions/{session_id}/share", headers=auth_headers)
    ).json()

    deleted = await client.delete(
        f"/api/v1/sessions/{session_id}", headers=auth_headers
    )
    assert deleted.status_code == 204

    feed = await client.get("/api/v1/feed", headers=auth_headers)
    assert feed.status_code == 200
    assert feed.json()["total"] == 1
    item = feed.json()["items"][0]
    assert item["id"] == post["id"]
    assert item["session_id"] is None
    assert item["highlights"]["total_volume_kg"] == 480.0
    assert item["highlights"]["prs"][0]["estimated_1rm_kg"] == pytest.approx(
        81.2, abs=0.1
    )


@pytest.mark.asyncio
async def test_delete_account_cleans_dependents(
    client: AsyncClient,
    auth_headers: dict,
    db_session: AsyncSession,
    test_user_verified,
):
    """注销账号不得因外键残留 500：训练/档案/社交行全部手动级联清理。"""
    from sqlalchemy import func, select

    from app.models.feed import FeedComment, FeedLike, FeedPost, Follow
    from app.models.profile import UserFitnessProfile, WeightLog
    from app.models.user import User
    from app.models.workout import WorkoutSession, WorkoutSet

    ex = await _create_exercise(db_session)
    put = await client.put(
        "/api/v1/users/me/profile",
        json={
            "gender": "male",
            "birthYear": 1995,
            "heightCm": 178,
            "weightKg": 75.0,
            "goal": "performance",
            "experience": "intermediate",
        },
        headers=auth_headers,
    )
    assert put.status_code == 200
    session_id = await _complete_session(
        client, auth_headers, ex, day=_today(), prefix="feed-rm", sets=[ACCESSORY_SET]
    )
    post_id = (
        await client.post(f"/api/v1/sessions/{session_id}/share", headers=auth_headers)
    ).json()["id"]

    # 他人关注 + 评论 + 点赞（他人在动态下的行同样要被清掉）
    other, other_headers = await _second_user(db_session)
    db_session.add(Follow(follower_id=other.id, followee_id=test_user_verified.id))
    await db_session.commit()
    await client.post(
        "/api/v1/users/" + str(other.id) + "/follow", headers=auth_headers
    )
    await client.post(
        f"/api/v1/feed/posts/{post_id}/comments",
        json={"body": "加油"},
        headers=other_headers,
    )
    await client.post(f"/api/v1/feed/posts/{post_id}/like", headers=other_headers)

    assert (
        await client.delete("/api/v1/users/me", headers=auth_headers)
    ).status_code == 204

    for model in (
        WorkoutSession,
        WorkoutSet,
        FeedPost,
        FeedComment,
        FeedLike,
        Follow,
        UserFitnessProfile,
        WeightLog,
    ):
        count = (
            await db_session.execute(select(func.count()).select_from(model))
        ).scalar()
        assert count == 0, model.__name__
    # 他人账号不受影响，且可正常使用
    remaining = (
        await db_session.execute(select(func.count()).select_from(User))
    ).scalar()
    assert remaining == 1
    assert (await client.get("/api/v1/feed", headers=other_headers)).status_code == 200
