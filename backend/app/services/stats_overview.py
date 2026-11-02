"""数据页总览聚合：周期 KPI、打卡日、肌群分布、近期 PR、常练动作。"""

from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from typing import Optional

from app.services.strength import is_hard_set, set_volume


def period_label(days: int) -> str:
    if days == 7:
        return "近 7 天"
    if days == 30:
        return "本月"
    if days == 90:
        return "近 90 天"
    return f"近 {days} 天"


def _naive(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def _day(dt: datetime) -> date:
    return dt.date()


def build_stats_overview(
    sessions: list[tuple],
    set_rows: list[tuple],
    lifetime_sets: list[tuple],
    one_rms: dict[int, float],
    *,
    period_days: int = 30,
    now: Optional[datetime] = None,
) -> dict:
    """聚合数据页总览。

    sessions: (id, started_at, completed_at) 周期内已完成会话
    set_rows: (session_id, exercise_id, exercise_name, muscle_name,
               reps, weight_kg, rpe) 周期内组
    lifetime_sets: (exercise_id, exercise_name, weight_kg, when)
                   全量有重量的组，用于判定周期内是否破 PR
    one_rms: exercise_id → estimated_kg
    """
    clock = _naive(now) or datetime.now(timezone.utc).replace(tzinfo=None)
    period_start = clock - timedelta(days=period_days)

    sessions_count = 0
    total_duration = 0
    trained_days: set[date] = set()
    for _sid, started_at, completed_at in sessions:
        started = _naive(started_at)
        if started is None:
            continue
        sessions_count += 1
        trained_days.add(_day(started))
        ended = _naive(completed_at)
        if ended is not None and ended >= started:
            total_duration += int((ended - started).total_seconds())

    total_volume = 0.0
    hard_sets = 0
    rpe_sum = 0.0
    rpe_n = 0
    muscle_vol: dict[str, dict] = defaultdict(lambda: {"volume": 0.0, "hard_sets": 0})
    ex_agg: dict[int, dict] = {}

    for (
        session_id,
        exercise_id,
        exercise_name,
        muscle_name,
        reps,
        weight_kg,
        rpe,
    ) in set_rows:
        vol = set_volume(weight_kg, reps)
        total_volume += vol
        hard = is_hard_set(rpe)
        if hard:
            hard_sets += 1
        if rpe is not None:
            rpe_sum += rpe
            rpe_n += 1
        mname = muscle_name or "其他"
        muscle_vol[mname]["volume"] += vol
        if hard:
            muscle_vol[mname]["hard_sets"] += 1

        bucket = ex_agg.setdefault(
            exercise_id,
            {
                "name": exercise_name or f"动作 {exercise_id}",
                "sessions": set(),
                "volume": 0.0,
            },
        )
        bucket["sessions"].add(session_id)
        bucket["volume"] += vol

    # 全量最大重量；若破纪录时间落在周期内 → 近期 PR
    best: dict[int, dict] = {}
    for exercise_id, exercise_name, weight_kg, when in lifetime_sets:
        if weight_kg is None or weight_kg <= 0:
            continue
        at = _naive(when)
        if at is None:
            continue
        cur = best.get(exercise_id)
        if cur is None or weight_kg > cur["value"]:
            best[exercise_id] = {
                "name": exercise_name or f"动作 {exercise_id}",
                "value": float(weight_kg),
                "at": at,
            }

    recent_prs = []
    for exercise_id, info in best.items():
        if info["at"] < period_start:
            continue
        recent_prs.append(
            {
                "exercise_id": exercise_id,
                "name": info["name"],
                "kind": "max_weight",
                "value": round(info["value"], 1),
                "at": info["at"],
            }
        )
    recent_prs.sort(key=lambda p: p["at"], reverse=True)
    recent_prs = recent_prs[:10]

    top_exercises = sorted(
        (
            {
                "exercise_id": eid,
                "name": data["name"],
                "sessions": len(data["sessions"]),
                "volume": round(data["volume"], 1),
                "estimated_1rm_kg": one_rms.get(eid),
            }
            for eid, data in ex_agg.items()
        ),
        key=lambda e: e["volume"],
        reverse=True,
    )[:8]

    by_muscle = [
        {
            "name": name,
            "volume": round(v["volume"], 1),
            "hard_sets": v["hard_sets"],
        }
        for name, v in sorted(
            muscle_vol.items(), key=lambda kv: kv[1]["volume"], reverse=True
        )
    ]

    return {
        "period_days": period_days,
        "period_label": period_label(period_days),
        "sessions_count": sessions_count,
        "total_volume_kg": round(total_volume, 1),
        "total_duration_seconds": total_duration,
        "avg_rpe": round(rpe_sum / rpe_n, 1) if rpe_n else None,
        "hard_sets": hard_sets,
        "trained_days": sorted(d.isoformat() for d in trained_days),
        "by_muscle": by_muscle,
        "recent_prs": recent_prs,
        "top_exercises": top_exercises,
    }
