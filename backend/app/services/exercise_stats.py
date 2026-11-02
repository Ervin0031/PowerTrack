"""按动作聚合图表数据：最大重量、容量、次数、个人纪录、会话历史。"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Iterable, Optional

from app.services.strength import counts_as_load, set_volume, week_monday

HISTORY_SESSION_LIMIT = 20


def period_label(days: int) -> str:
    if days == 30:
        return "上个月"
    if days == 90:
        return "近 3 个月"
    if days == 365:
        return "近一年"
    return f"近 {days} 天"


def _naive(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def _when(completed_at, started_at) -> Optional[datetime]:
    return _naive(completed_at) or _naive(started_at)


def _axis_dates(start: date, end: date) -> list[str]:
    span = (end - start).days
    mid = start + timedelta(days=max(span // 2, 0))
    return [start.isoformat(), mid.isoformat(), end.isoformat()]


def _mean_positive(values: Iterable[float]) -> Optional[float]:
    loaded = [v for v in values if v > 0]
    if not loaded:
        return None
    return round(sum(loaded) / len(loaded), 1)


def _points_from_map(
    buckets: dict[date, float], *, drop_all_zero: bool = True
) -> list[dict]:
    points = [
        {"t": day.isoformat(), "v": round(value, 1)}
        for day, value in sorted(buckets.items())
    ]
    if drop_all_zero and (not points or all(p["v"] <= 0 for p in points)):
        return []
    return points


def _week_range(start: date, end: date) -> list[date]:
    cur = week_monday(start)
    last = week_monday(end)
    out: list[date] = []
    while cur <= last:
        out.append(cur)
        cur += timedelta(weeks=1)
    return out


def build_exercise_stats(
    rows: list[tuple],
    *,
    exercise_id: int,
    period_days: int = 30,
    now: Optional[datetime] = None,
    estimated_1rm_kg: Optional[float] = None,
) -> dict:
    """rows: session_id, set_number, reps, weight, rpe, notes, times."""
    clock = _naive(now) or datetime.now(timezone.utc).replace(tzinfo=None)
    period_start = clock - timedelta(days=period_days)
    start_day = period_start.date()
    end_day = clock.date()
    weeks = _week_range(start_day, end_day)

    max_weight_by_day: dict[date, float] = {}
    max_reps_by_week: dict[date, float] = {w: 0.0 for w in weeks}
    volume_by_week: dict[date, float] = {w: 0.0 for w in weeks}
    reps_by_week: dict[date, float] = {w: 0.0 for w in weeks}

    pr_weight: Optional[float] = None
    pr_weight_at: Optional[datetime] = None
    pr_reps: Optional[int] = None
    pr_reps_at: Optional[datetime] = None
    pr_volume: Optional[float] = None
    pr_volume_at: Optional[datetime] = None
    first_at: Optional[datetime] = None
    last_at: Optional[datetime] = None
    session_ids: set[int] = set()

    history_order: list[int] = []
    history: dict[int, dict] = {}

    for row in rows:
        (
            session_id,
            set_number,
            reps,
            weight_kg,
            rpe,
            notes,
            completed_at,
            started_at,
            session_completed_at,
        ) = row[:9]
        set_kind = row[9] if len(row) > 9 and isinstance(row[9], str) else "working"
        load = counts_as_load(set_kind)
        when = _when(completed_at, started_at)
        if when is None:
            continue
        session_ids.add(session_id)
        if first_at is None or when < first_at:
            first_at = when
        if last_at is None or when > last_at:
            last_at = when

        weight = float(weight_kg) if isinstance(weight_kg, (int, float)) else None
        rep_n = int(reps) if isinstance(reps, (int, float)) else None
        vol = set_volume(weight, rep_n) if load else 0.0

        if load and weight is not None and (pr_weight is None or weight > pr_weight):
            pr_weight = weight
            pr_weight_at = when
        if load and rep_n is not None and (pr_reps is None or rep_n > pr_reps):
            pr_reps = rep_n
            pr_reps_at = when
        if load and vol > 0 and (pr_volume is None or vol > pr_volume):
            pr_volume = round(vol, 1)
            pr_volume_at = when

        if session_id not in history:
            if len(history_order) < HISTORY_SESSION_LIMIT:
                history_order.append(session_id)
                history[session_id] = {
                    "session_id": session_id,
                    "started_at": _naive(started_at) or when,
                    "completed_at": _naive(session_completed_at),
                    "sets": [],
                }
        if session_id in history:
            history[session_id]["sets"].append(
                {
                    "set_number": set_number,
                    "reps": rep_n,
                    "weight_kg": weight,
                    "rpe": float(rpe) if isinstance(rpe, (int, float)) else None,
                    "notes": notes,
                    "set_kind": set_kind,
                }
            )

        if not load or when < period_start:
            continue
        day = when.date()
        week = week_monday(day)
        if weight is not None:
            prev = max_weight_by_day.get(day)
            if prev is None or weight > prev:
                max_weight_by_day[day] = weight
        if week in max_reps_by_week and rep_n is not None:
            if rep_n > max_reps_by_week[week]:
                max_reps_by_week[week] = float(rep_n)
        if week in volume_by_week:
            volume_by_week[week] += vol
            if rep_n is not None:
                reps_by_week[week] += rep_n

    max_weight_value = max(max_weight_by_day.values()) if max_weight_by_day else None
    loaded_reps = [v for v in max_reps_by_week.values() if v > 0]
    max_reps_value = max(loaded_reps) if loaded_reps else None

    return {
        "exercise_id": exercise_id,
        "period_days": period_days,
        "period_label": period_label(period_days),
        "axis": _axis_dates(start_day, end_day),
        "max_weight": {
            "value": (
                round(max_weight_value, 1) if max_weight_value is not None else None
            ),
            "points": _points_from_map(max_weight_by_day),
        },
        "total_volume": {
            "value": _mean_positive(volume_by_week.values()),
            "points": _points_from_map(volume_by_week),
        },
        "max_reps": {
            "value": int(max_reps_value) if max_reps_value is not None else None,
            "points": _points_from_map(max_reps_by_week),
        },
        "total_reps": {
            "value": _mean_positive(reps_by_week.values()),
            "points": _points_from_map(reps_by_week),
        },
        "records": {
            "max_weight_kg": round(pr_weight, 1) if pr_weight is not None else None,
            "max_weight_at": pr_weight_at,
            "max_reps": pr_reps,
            "max_reps_at": pr_reps_at,
            "max_set_volume": pr_volume,
            "max_set_volume_at": pr_volume_at,
            "estimated_1rm_kg": (
                round(estimated_1rm_kg, 1) if estimated_1rm_kg is not None else None
            ),
            "session_count": len(session_ids),
            "first_at": first_at,
            "last_at": last_at,
        },
        "history": [history[sid] for sid in history_order],
    }
