"""下次课处方。和动作页的停滞标记用同一套判断。

组内 RPE 调重仍走 rpe.recommend_next_set。这里只回答下一次练这个动作时
加重量、保持、减一组、减量，或换变式。
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Optional

from app.services.rpe import PLATE_STEP_KG, round_to_plate

STALL_SESSIONS = 3
# ponytail: 孤立动作也按 2.5kg 一片。要 1.25kg 时再把步长按动作类型拆开。
ADD_LIGHT_KG = PLATE_STEP_KG * 2
HEAVY_RPE = 8.0
ADD_MAX_RPE = 8.5
DROP_RPE = 9.5


@dataclass(frozen=True)
class Exposure:
    """一次已完成训练里，这个动作的正式组摘要。按时间从旧到新。"""

    top_weight_kg: float
    top_reps: int
    top_rpe: Optional[float]
    e1rm_kg: Optional[float]
    working_sets: int


@dataclass(frozen=True)
class Prescription:
    action: str
    stalled: bool
    weight_kg: Optional[float]
    sets: Optional[int]
    reason: str
    summary: str


def block_week(started_on: date, today: date, week_count: int) -> int:
    """从开块那天起算第几周，走完 week_count 后回到第 1 周。"""
    weeks = week_count if week_count > 0 else 1
    elapsed = (today - started_on).days
    if elapsed < 0:
        return 1
    return (elapsed // 7) % weeks + 1


def prescribe(exposures: list[Exposure], *, deload: bool) -> Prescription:
    if not exposures:
        return Prescription(
            action="hold",
            stalled=False,
            weight_kg=None,
            sets=None,
            reason="还没有这个动作的正式组",
            summary="先按模板练一次",
        )

    last = exposures[-1]
    recent = exposures[-STALL_SESSIONS:]
    stalled = len(recent) >= STALL_SESSIONS and (
        _flat_weights(recent) or _flat_e1rm(recent)
    )
    sets = last.working_sets if last.working_sets > 0 else None
    weight = last.top_weight_kg

    if deload:
        halved = max(1, (last.working_sets or 1) // 2)
        return _done(
            "deload",
            stalled,
            weight,
            halved,
            "减量周，重量不变，组数减半",
        )

    rpe = last.top_rpe
    if rpe is None:
        return _done("hold", stalled, weight, sets, "上次没记 RPE，重量先保持")

    if rpe >= DROP_RPE:
        if last.working_sets > 1:
            return _done(
                "drop_set",
                stalled,
                weight,
                last.working_sets - 1,
                "最近一次顶到极限，下次少做一组",
            )
        dropped = round_to_plate(weight - PLATE_STEP_KG)
        if dropped <= 0 or dropped >= weight:
            return _done("hold", stalled, weight, sets, "已经很轻了，下次保持")
        return _done(
            "drop_set",
            stalled,
            dropped,
            sets,
            "最近一次顶到极限，下次降一片",
        )

    if stalled and rpe >= HEAVY_RPE:
        return _done(
            "swap",
            True,
            weight,
            sets,
            "连续三次顶组没动，换一个变式",
        )

    if rpe <= ADD_MAX_RPE:
        step = ADD_LIGHT_KG if rpe < 7 else PLATE_STEP_KG
        nxt = round_to_plate(weight + step)
        why = (
            "顶组没涨，但上次还有余力，下次加重量"
            if stalled
            else ("上次偏轻，下次加两片" if rpe < 7 else "上次还有余力，下次加一片")
        )
        return _done("add_load", stalled, nxt, sets, why)

    return _done("hold", stalled, weight, sets, "接近极限，下次保持重量和组数")


def _done(
    action: str,
    stalled: bool,
    weight: Optional[float],
    sets: Optional[int],
    reason: str,
) -> Prescription:
    return Prescription(
        action=action,
        stalled=stalled,
        weight_kg=weight,
        sets=sets,
        reason=reason,
        summary=_summary(action, stalled, weight, sets),
    )


def _summary(
    action: str,
    stalled: bool,
    weight: Optional[float],
    sets: Optional[int],
) -> str:
    load = ""
    if weight is not None:
        load = _kg(weight)
        if sets:
            load = f"{load} × {sets} 组"
    if action == "swap":
        return "停滞，换一个变式" + (f"，先停在 {load}" if load else "")
    if action == "deload":
        return "减量周" + (f"，{load}" if load else "")
    if action == "drop_set":
        return "下次少做" + (f"，{load}" if load else "")
    if action == "add_load":
        head = "停滞，但仍加重量" if stalled else "下次"
        return f"{head} {load}".strip()
    if action == "hold" and load:
        return f"下次保持 {load}"
    return "先按模板练一次"


def _kg(weight: float) -> str:
    rounded = round(weight, 1)
    if abs(rounded - round(rounded)) < 1e-9:
        return f"{int(round(rounded))}kg"
    return f"{rounded:.1f}kg"


def _flat_weights(exposures: list[Exposure]) -> bool:
    weights = [item.top_weight_kg for item in exposures]
    return max(weights) - min(weights) <= 0.25


def _flat_e1rm(exposures: list[Exposure]) -> bool:
    values = [item.e1rm_kg for item in exposures]
    if any(item is None or item <= 0 for item in values):
        return False
    latest = values[-1]
    assert latest is not None
    return max(values) - min(values) <= latest * 0.01
