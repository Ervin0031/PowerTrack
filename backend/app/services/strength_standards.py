"""相对力量与体型对称度：倍体重比、Dots / Wilks 系数、推拉容量比。

系数为公开公式常量；gender 只有 male/female 两套，undisclosed 不猜、返回 None。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from app.services.strength import is_hard_set, set_volume

# Dots（Konertz 2019）：total*500 / (A*bw^4 + B*bw^3 + C*bw^2 + D*bw + E)
DOTS_COEFFS: dict[str, tuple[float, ...]] = {
    "male": (-0.0000010930, 0.0007391293, -0.1918759221, 24.0900756, -307.75076),
    "female": (-0.0000010706, 0.0005158568, -0.1126655495, 13.6175032, -57.96288),
}

# Wilks（1994）：total*500 / (a + b*bw + c*bw^2 + d*bw^3 + e*bw^4 + f*bw^5)
WILKS_COEFFS: dict[str, tuple[float, ...]] = {
    "male": (
        -216.0475144,
        16.2606339,
        -0.002388645,
        -0.00113732,
        7.01863e-06,
        -1.291e-08,
    ),
    "female": (
        594.31747775582,
        -27.23842536447,
        0.82112226871,
        -0.00930733913,
        4.731582e-05,
        -9.054e-08,
    ),
}

# 三大项识别：动作库只有中文 name 与英文 name_en，按归一化 name_en 精确匹配
# （seed 动作带 "Barbell"，dataset 导入的不带，两种都要覆盖）。
BIG_THREE_ALIASES: dict[str, frozenset[str]] = {
    "squat": frozenset({"barbell squat", "squat", "back squat"}),
    "bench": frozenset({"barbell bench press", "bench press"}),
    "deadlift": frozenset({"barbell deadlift", "deadlift", "conventional deadlift"}),
}
BIG_THREE_LABELS = {"squat": "深蹲", "bench": "卧推", "deadlift": "硬拉"}

PUSH_MUSCLES = frozenset(
    {"胸部", "上胸部", "下胸部", "肩部", "三角肌前束", "三角肌中束", "肱三头肌"}
)
PULL_MUSCLES = frozenset(
    {"背部", "背阔肌", "上背部", "下背部", "三角肌后束", "斜方肌", "肱二头肌", "前臂"}
)
PUSH_PULL_WINDOW_DAYS = 28
PUSH_PULL_BALANCED_LOW = 0.8
PUSH_PULL_BALANCED_HIGH = 1.2


def dots_score(
    total_kg: Optional[float],
    bodyweight_kg: Optional[float],
    gender: Optional[str],
) -> Optional[float]:
    coeffs = DOTS_COEFFS.get(gender or "")
    if coeffs is None or not total_kg or total_kg <= 0:
        return None
    if not bodyweight_kg or bodyweight_kg <= 0:
        return None
    a, b, c, d, e = coeffs
    bw = bodyweight_kg
    denom = a * bw**4 + b * bw**3 + c * bw**2 + d * bw + e
    if denom <= 0:
        return None
    return round(total_kg * 500.0 / denom, 1)


def wilks_score(
    total_kg: Optional[float],
    bodyweight_kg: Optional[float],
    gender: Optional[str],
) -> Optional[float]:
    coeffs = WILKS_COEFFS.get(gender or "")
    if coeffs is None or not total_kg or total_kg <= 0:
        return None
    if not bodyweight_kg or bodyweight_kg <= 0:
        return None
    a, b, c, d, e, f = coeffs
    bw = bodyweight_kg
    denom = a + b * bw + c * bw**2 + d * bw**3 + e * bw**4 + f * bw**5
    if denom <= 0:
        return None
    return round(total_kg * 500.0 / denom, 1)


def relative_strength(
    estimated_kg: Optional[float], bodyweight_kg: Optional[float]
) -> Optional[float]:
    if not estimated_kg or estimated_kg <= 0:
        return None
    if not bodyweight_kg or bodyweight_kg <= 0:
        return None
    return round(estimated_kg / bodyweight_kg, 2)


def lift_key(name_en: Optional[str]) -> Optional[str]:
    if not name_en:
        return None
    normalized = name_en.strip().lower()
    for key, aliases in BIG_THREE_ALIASES.items():
        if normalized in aliases:
            return key
    return None


@dataclass(frozen=True)
class BigThree:
    squat_kg: Optional[float] = None
    bench_kg: Optional[float] = None
    deadlift_kg: Optional[float] = None
    squat_exercise_id: Optional[int] = None
    bench_exercise_id: Optional[int] = None
    deadlift_exercise_id: Optional[int] = None

    @property
    def complete(self) -> bool:
        return self.total_kg is not None

    @property
    def total_kg(self) -> Optional[float]:
        """三项齐全才有值；部分总和的系数没有可比性，不硬算。"""
        if self.squat_kg is None or self.bench_kg is None or self.deadlift_kg is None:
            return None
        return round(self.squat_kg + self.bench_kg + self.deadlift_kg, 1)

    @property
    def missing(self) -> list[str]:
        pairs = (
            ("squat", self.squat_kg),
            ("bench", self.bench_kg),
            ("deadlift", self.deadlift_kg),
        )
        return [key for key, kg in pairs if kg is None]


def build_big_three(entries: list[tuple]) -> BigThree:
    """entries: (exercise_id, name, name_en, estimated_kg)；同一 lift 取最大 e1RM。"""
    best: dict[str, tuple[int, float]] = {}
    for exercise_id, _name, name_en, estimated in entries:
        key = lift_key(name_en)
        if key is None or estimated is None or estimated <= 0:
            continue
        current = best.get(key)
        if current is None or estimated > current[1]:
            best[key] = (exercise_id, float(estimated))
    squat = best.get("squat")
    bench = best.get("bench")
    deadlift = best.get("deadlift")
    return BigThree(
        squat_kg=squat[1] if squat else None,
        bench_kg=bench[1] if bench else None,
        deadlift_kg=deadlift[1] if deadlift else None,
        squat_exercise_id=squat[0] if squat else None,
        bench_exercise_id=bench[0] if bench else None,
        deadlift_exercise_id=deadlift[0] if deadlift else None,
    )


@dataclass(frozen=True)
class PushPull:
    window_days: int
    push_volume_kg: float
    pull_volume_kg: float
    push_hard_sets: int
    pull_hard_sets: int
    ratio: Optional[float]  # 推容量 / 拉容量
    verdict: str  # unknown / balanced / push_dominant / pull_dominant


def build_push_pull(
    rows: list[tuple], window_days: int = PUSH_PULL_WINDOW_DAYS
) -> PushPull:
    """rows: (started_at, reps, weight_kg, rpe, muscle_name)，调用方按窗口过滤。"""
    push_volume = 0.0
    pull_volume = 0.0
    push_sets = 0
    pull_sets = 0
    for _started_at, reps, weight_kg, rpe, muscle_name in rows:
        if muscle_name in PUSH_MUSCLES:
            push_volume += set_volume(weight_kg, reps)
            if is_hard_set(rpe):
                push_sets += 1
        elif muscle_name in PULL_MUSCLES:
            pull_volume += set_volume(weight_kg, reps)
            if is_hard_set(rpe):
                pull_sets += 1

    ratio: Optional[float] = None
    verdict = "unknown"
    if pull_volume > 0:
        ratio = round(push_volume / pull_volume, 2)
        if ratio > PUSH_PULL_BALANCED_HIGH:
            verdict = "push_dominant"
        elif ratio < PUSH_PULL_BALANCED_LOW:
            verdict = "pull_dominant"
        else:
            verdict = "balanced"
    return PushPull(
        window_days=window_days,
        push_volume_kg=round(push_volume, 1),
        pull_volume_kg=round(pull_volume, 1),
        push_hard_sets=push_sets,
        pull_hard_sets=pull_sets,
        ratio=ratio,
        verdict=verdict,
    )


def _lift_payload(
    exercise_id: Optional[int], kg: Optional[float], bodyweight_kg: Optional[float]
) -> dict:
    return {
        "exercise_id": exercise_id,
        "estimated_1rm_kg": round(kg, 1) if kg is not None else None,
        "ratio": relative_strength(kg, bodyweight_kg),
    }


def build_strength_standards(
    entries: list[tuple],
    load_rows: list[tuple],
    *,
    has_profile: bool,
    bodyweight_kg: Optional[float],
    gender: Optional[str],
) -> dict:
    """返回可直接喂给 StrengthStandardsResponse(**data) 的 dict。"""
    bw = bodyweight_kg if bodyweight_kg and bodyweight_kg > 0 else None

    lifts = []
    for exercise_id, name, name_en, estimated in entries:
        key = lift_key(name_en)
        lifts.append(
            {
                "exercise_id": int(exercise_id),
                "name": name,
                "name_en": name_en,
                "estimated_1rm_kg": round(float(estimated), 1),
                "ratio": relative_strength(estimated, bw),
                "is_big_three": key is not None,
                "lift": key,
            }
        )
    # 倍体重比降序；无比值的排最后
    lifts.sort(
        key=lambda item: (item["ratio"] is None, -(item["ratio"] or 0.0), item["name"])
    )

    big = build_big_three(entries)
    total = big.total_kg
    push_pull = build_push_pull(load_rows)

    return {
        "has_profile": has_profile,
        "gender": gender if has_profile else None,
        "bodyweight_kg": bw,
        "relative_strength": lifts,
        "big_three": {
            "squat": _lift_payload(big.squat_exercise_id, big.squat_kg, bw),
            "bench": _lift_payload(big.bench_exercise_id, big.bench_kg, bw),
            "deadlift": _lift_payload(big.deadlift_exercise_id, big.deadlift_kg, bw),
            "total_kg": total,
            "complete": big.complete,
            "missing": big.missing,
        },
        "dots": dots_score(total, bw, gender),
        "wilks": wilks_score(total, bw, gender),
        "push_pull": {
            "window_days": push_pull.window_days,
            "push_volume_kg": push_pull.push_volume_kg,
            "pull_volume_kg": push_pull.pull_volume_kg,
            "push_hard_sets": push_pull.push_hard_sets,
            "pull_hard_sets": push_pull.pull_hard_sets,
            "ratio": push_pull.ratio,
            "verdict": push_pull.verdict,
        },
    }
