"""分享卡片快照：把一次已完成的训练加工成带 PR / 肌群高亮的 JSON。

会话被物理删除后快照仍要完整，因此这里只依赖传入的行数据，不查库。
"""

from __future__ import annotations

import json
from datetime import datetime
from typing import Optional

from app.models.feed import FeedPost
from app.services.strength import (
    counts_as_load,
    estimate_1rm,
    is_hard_set,
    set_volume,
)

SNAPSHOT_SCHEMA_VERSION = 1
PR_HIGHLIGHT_MAX = 5
MUSCLE_HIGHLIGHT_MAX = 5


def _best_estimates(rows: list[tuple]) -> dict[int, float]:
    """(exercise_id, reps, weight_kg, rpe) 行 → {exercise_id: 最大 e1RM}。"""
    best: dict[int, float] = {}
    for exercise_id, reps, weight_kg, rpe in rows:
        est = estimate_1rm(weight_kg, reps, rpe)
        if est is None:
            continue
        if est > best.get(exercise_id, 0.0):
            best[exercise_id] = est
    return best


def build_session_snapshot(
    rows: list[tuple],
    prior_rows: list[tuple],
    *,
    session_id: int,
    started_at: Optional[datetime],
    completed_at: Optional[datetime],
    notes: Optional[str],
) -> dict:
    """rows 来自 `list_session_detail_rows`（9 元组），prior_rows 来自
    `list_set_loads_by_exercises`（本次之前的组，用于判定 PR）。"""
    prior_best = _best_estimates(prior_rows)

    total_volume = 0.0
    hard_sets = 0
    load_sets = 0
    exercise_ids: set[int] = set()
    muscles: dict[str, dict] = {}
    # 每动作本次最好的组：(est, set_id, set_number, 动作名, weight_kg, reps, rpe)
    best_set: dict[int, tuple] = {}

    for row in rows:
        (
            set_id,
            set_number,
            exercise_id,
            exercise_name,
            muscle_name,
            reps,
            weight_kg,
            rpe,
            set_kind,
        ) = row
        if not counts_as_load(set_kind):
            continue
        load_sets += 1
        exercise_ids.add(exercise_id)
        vol = set_volume(weight_kg, reps)
        total_volume += vol
        hard = is_hard_set(rpe)
        if hard:
            hard_sets += 1
        name = muscle_name or "其他"
        bucket = muscles.setdefault(name, {"name": name, "hard_sets": 0, "volume": 0.0})
        bucket["volume"] += vol
        if hard:
            bucket["hard_sets"] += 1
        est = estimate_1rm(weight_kg, reps, rpe)
        if est is not None:
            current = best_set.get(exercise_id)
            if current is None or est > current[0]:
                best_set[exercise_id] = (
                    est,
                    set_id,
                    set_number,
                    exercise_name,
                    weight_kg,
                    reps,
                    rpe,
                )

    prs = []
    for exercise_id, (
        est,
        set_id,
        set_number,
        name,
        weight_kg,
        reps,
        rpe,
    ) in best_set.items():
        previous = prior_best.get(exercise_id)
        if previous is not None and est <= previous:
            continue
        prs.append(
            {
                "exercise_id": exercise_id,
                "exercise_name": name,
                "set_id": set_id,
                "set_number": set_number,
                "weight_kg": weight_kg,
                "reps": reps,
                "rpe": rpe,
                "estimated_1rm_kg": round(est, 1),
                "previous_best_kg": (
                    round(previous, 1) if previous is not None else None
                ),
                "improvement_kg": (
                    round(est - previous, 1) if previous is not None else None
                ),
            }
        )
    prs.sort(key=lambda item: item["estimated_1rm_kg"], reverse=True)

    duration = None
    if started_at is not None and completed_at is not None:
        duration = int((completed_at - started_at).total_seconds())

    muscle_items = sorted(muscles.values(), key=lambda m: m["volume"], reverse=True)[
        :MUSCLE_HIGHLIGHT_MAX
    ]

    return {
        "schema_version": SNAPSHOT_SCHEMA_VERSION,
        "session_id": session_id,
        "started_at": started_at.isoformat() if started_at else None,
        "completed_at": completed_at.isoformat() if completed_at else None,
        "duration_seconds": duration,
        "notes": notes,
        "total_volume_kg": round(total_volume, 1),
        "hard_sets": hard_sets,
        "total_sets": load_sets,
        "exercises_count": len(exercise_ids),
        "muscles": [
            {
                "name": m["name"],
                "hard_sets": m["hard_sets"],
                "volume": round(m["volume"], 1),
            }
            for m in muscle_items
        ],
        "prs": prs[:PR_HIGHLIGHT_MAX],
    }


def parse_highlights(raw: Optional[str]) -> Optional[dict]:
    """容错解析快照 JSON；坏数据返回 None 而不是 500。"""
    if not raw:
        return None
    try:
        data = json.loads(raw)
    except (TypeError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def post_to_dict(
    post: FeedPost,
    *,
    author_username: str,
    like_count: int = 0,
    comment_count: int = 0,
    liked_by_me: bool = False,
) -> dict:
    return {
        "id": post.id,
        "user_id": post.user_id,
        "author_username": author_username,
        "session_id": post.session_id,
        "caption": post.caption,
        "highlights": parse_highlights(post.highlights),
        "created_at": post.created_at,
        "like_count": like_count,
        "comment_count": comment_count,
        "liked_by_me": liked_by_me,
    }
