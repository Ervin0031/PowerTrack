"""RPE 自动调节：下一组重量、额外休息、力竭降重。

规则与客户端 `domain/rpe.dart` 保持一致，便于离线训练与后端/iOS 共用同一套建议。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

PLATE_STEP_KG = 2.5
SWEET_SPOT_MIN = 7.0
SWEET_SPOT_MAX = 8.5
RED_ZONE_RPE = 9.5
FAILURE_RPE = 10.0
EXTRA_REST_SECONDS = 60
COMPOUND_FAILURE_FACTOR = 0.95
ISOLATION_FAILURE_FACTOR = 0.925
COMPOUND_SWEET_FACTOR = 1.015
ISOLATION_SWEET_FACTOR = 1.025
LIGHT_FACTOR = 1.075

REST_MESSAGE = "刚才那组非常极限，系统已为你增加 60 秒..."
FAILURE_AGAIN_MESSAGE = "已经力竭过，后面的组可以不做"
REASON_FAILURE = "力竭，同次数降到目标余力"
REASON_FAILURE_AGAIN = "已经力竭过，不再降重"
REASON_RED = "红区，保持重量 + 60s"
REASON_RED_REPEAT = "连续红区，再降一片"
REASON_RISING = "连续升 RPE，锁定重量"
REASON_CAPPED = "已到目标区上限，不再加码"
REASON_ISOLATION = "孤立动作，甜区微加"
REASON_COMPOUND = "复合动作，甜区微加"
REASON_TABLE = "无 1RM 锚点，按 RPE 表"
REASON_HOLD = "接近极限，保持重量"


def round_to_plate(kg: float, step: float = PLATE_STEP_KG) -> float:
    """四舍五入到最近配重片（默认 2.5kg）。"""
    if step <= 0:
        return kg
    return round(kg / step + 1e-9) * step


def normalize_rpe(rpe: float) -> float:
    """夹到 0.5–10.0，并对齐到 0.5 步进。"""
    clamped = min(10.0, max(0.5, rpe))
    return round(clamped * 2) / 2


def zone_for_goal(goal: Optional[str]) -> Optional[tuple[float, float]]:
    if goal == "performance":
        return (0.85, 0.95)
    if goal in ("muscle_gain", "hypertrophy"):
        return (0.65, 0.80)
    if goal in ("reshape", "both"):
        return (0.75, 0.85)
    return None


@dataclass(frozen=True)
class RpeAdvice:
    suggested_weight_kg: Optional[float]
    extra_rest_seconds: int = 0
    fatigue_warning: bool = False
    reduce_remaining_factor: Optional[float] = None
    message: Optional[str] = None
    reason: Optional[str] = None
    capped_by_1rm: bool = False
    zone: Optional[tuple[float, float]] = None


def _format_kg(kg: float) -> str:
    rounded = round(kg * 10) / 10
    if abs(rounded - round(rounded)) < 1e-9:
        return str(int(round(rounded)))
    return f"{rounded:.1f}"


def failure_message(kg: float) -> str:
    return f"力竭了，下一组 {_format_kg(kg)}kg"


def red_repeat_message(kg: float) -> str:
    return f"连续顶到极限，下一组 {_format_kg(kg)}kg"


def target_rpe_for_goal(goal: Optional[str]) -> float:
    """增肌留到 RPE 8，力量留到 RPE 9。其余目标跟增肌。"""
    return 9.0 if goal == "performance" else 8.0


def _already_at(prior_rpes: list[float], threshold: float) -> bool:
    return any(normalize_rpe(rpe) >= threshold for rpe in prior_rpes)


def _at_least_one_plate_down(weight_kg: float, raw: float) -> Optional[float]:
    """对齐配重片，并且至少比本组少一片。"""
    nxt = round_to_plate(raw)
    if nxt >= weight_kg - 1e-9:
        nxt = round_to_plate(weight_kg - PLATE_STEP_KG)
    if nxt <= 0 or nxt >= weight_kg - 1e-9:
        return None
    return nxt


def _failure_weight(
    weight_kg: float,
    reps: Optional[int],
    exercise_type: str,
    goal: Optional[str],
) -> Optional[float]:
    from app.services.strength import percent_1rm

    isolation = exercise_type == "isolation"
    fallback = weight_kg * (
        ISOLATION_FAILURE_FACTOR if isolation else COMPOUND_FAILURE_FACTOR
    )
    if reps is None or reps < 1:
        return _at_least_one_plate_down(weight_kg, fallback)
    src = percent_1rm(reps, FAILURE_RPE)
    dst = percent_1rm(reps, target_rpe_for_goal(goal))
    if src is None or dst is None or src <= 0:
        return _at_least_one_plate_down(weight_kg, fallback)
    return _at_least_one_plate_down(weight_kg, weight_kg * dst / src)


def _drop_factor(weight_kg: float, nxt: Optional[float]) -> Optional[float]:
    if nxt is None or weight_kg <= 0 or nxt >= weight_kg:
        return None
    return round((weight_kg - nxt) / weight_kg, 4)


def _rising_rpes(prior_rpes: list[float], current: float) -> bool:
    if len(prior_rpes) < 2:
        return False
    series = [normalize_rpe(x) for x in prior_rpes] + [current]
    return all(series[i] < series[i + 1] for i in range(len(series) - 1))


def _table_candidate(
    weight_kg: float, rpe: float, exercise_type: str
) -> tuple[float, str]:
    isolation = exercise_type == "isolation"
    if rpe >= 9.0:
        return weight_kg, REASON_HOLD
    if SWEET_SPOT_MIN <= rpe <= SWEET_SPOT_MAX:
        if isolation:
            return round_to_plate(weight_kg * ISOLATION_SWEET_FACTOR), REASON_ISOLATION
        return round_to_plate(weight_kg * COMPOUND_SWEET_FACTOR), REASON_COMPOUND
    return round_to_plate(weight_kg * LIGHT_FACTOR), REASON_TABLE


def recommend_next_set(
    weight_kg: float,
    rpe: float,
    *,
    reps: Optional[int] = None,
    one_rm_kg: Optional[float] = None,
    exercise_type: str = "compound",
    prior_rpes: Optional[list[float]] = None,
    target_zone: Optional[tuple[float, float]] = None,
    goal: Optional[str] = None,
) -> RpeAdvice:
    """根据本组重量与 RPE 给出下一组建议。命中高优先级即返回。"""
    rpe = normalize_rpe(rpe)
    kind = "isolation" if exercise_type == "isolation" else "compound"
    zone = target_zone or zone_for_goal(goal)
    history = prior_rpes or []
    if weight_kg <= 0:
        return RpeAdvice(suggested_weight_kg=None, zone=zone)

    if rpe >= FAILURE_RPE:
        if _already_at(history, FAILURE_RPE):
            return RpeAdvice(
                suggested_weight_kg=None,
                extra_rest_seconds=EXTRA_REST_SECONDS,
                fatigue_warning=True,
                message=FAILURE_AGAIN_MESSAGE,
                reason=REASON_FAILURE_AGAIN,
                zone=zone,
            )
        reduced = _failure_weight(weight_kg, reps, kind, goal)
        return RpeAdvice(
            suggested_weight_kg=reduced,
            extra_rest_seconds=EXTRA_REST_SECONDS,
            fatigue_warning=True,
            reduce_remaining_factor=_drop_factor(weight_kg, reduced),
            message=(
                FAILURE_AGAIN_MESSAGE if reduced is None else failure_message(reduced)
            ),
            reason=REASON_FAILURE,
            zone=zone,
        )
    if rpe >= RED_ZONE_RPE:
        if _already_at(history, RED_ZONE_RPE):
            reduced = _at_least_one_plate_down(weight_kg, weight_kg - PLATE_STEP_KG)
            return RpeAdvice(
                suggested_weight_kg=weight_kg if reduced is None else reduced,
                extra_rest_seconds=EXTRA_REST_SECONDS,
                message=(
                    REST_MESSAGE if reduced is None else red_repeat_message(reduced)
                ),
                reason=REASON_RED if reduced is None else REASON_RED_REPEAT,
                zone=zone,
            )
        return RpeAdvice(
            suggested_weight_kg=weight_kg,
            extra_rest_seconds=EXTRA_REST_SECONDS,
            message=REST_MESSAGE,
            reason=REASON_RED,
            zone=zone,
        )
    if _rising_rpes(prior_rpes or [], rpe):
        return RpeAdvice(
            suggested_weight_kg=weight_kg,
            reason=REASON_RISING,
            zone=zone,
        )

    candidate, reason = _table_candidate(weight_kg, rpe, kind)
    if one_rm_kg is None and reason == REASON_HOLD:
        reason = REASON_TABLE
    capped = False
    if one_rm_kg is not None and one_rm_kg > 0 and zone is not None:
        low, high = zone[0] * one_rm_kg, zone[1] * one_rm_kg
        clamped = round_to_plate(min(high, max(low, candidate)))
        if clamped != candidate:
            capped = True
            reason = REASON_CAPPED
        candidate = clamped

    return RpeAdvice(
        suggested_weight_kg=candidate,
        reason=reason,
        capped_by_1rm=capped,
        zone=zone,
    )
