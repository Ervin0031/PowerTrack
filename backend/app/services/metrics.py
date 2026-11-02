"""BMR / TDEE / 最大心率 / 目标热量。与客户端 `domain/metrics.dart` 保持一致。"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Optional

GENDER_MALE = "male"
GENDER_FEMALE = "female"
GENDER_UNDISCLOSED = "undisclosed"

GOAL_FAT_LOSS = "fat_loss"
GOAL_MUSCLE_GAIN = "muscle_gain"
GOAL_RESHAPE = "reshape"
GOAL_HEALTH = "health"
GOAL_PERFORMANCE = "performance"

EXP_BEGINNER = "beginner"
EXP_INTERMEDIATE = "intermediate"
EXP_ADVANCED = "advanced"


def age_from_birth_year(birth_year: int, now: Optional[datetime] = None) -> int:
    year = (now or datetime.now(timezone.utc)).year
    return max(8, min(100, year - birth_year))


def bmr_mifflin(weight_kg: float, height_cm: float, age: int, gender: str) -> float:
    """Mifflin-St Jeor。不愿透露时取男女公式平均值。"""
    base = 10 * weight_kg + 6.25 * height_cm - 5 * age
    male = base + 5
    female = base - 161
    if gender == GENDER_MALE:
        return male
    if gender == GENDER_FEMALE:
        return female
    return (male + female) / 2


def activity_factor(weekly_days: Optional[int], experience: str) -> float:
    if weekly_days is not None:
        if weekly_days <= 0:
            return 1.2
        if weekly_days <= 2:
            return 1.375
        if weekly_days <= 4:
            return 1.55
        return 1.725
    if experience == EXP_ADVANCED:
        return 1.55
    if experience == EXP_INTERMEDIATE:
        return 1.375
    return 1.2


def tdee(bmr: float, weekly_days: Optional[int], experience: str) -> float:
    return bmr * activity_factor(weekly_days, experience)


def max_heart_rate(age: int) -> float:
    """Tanaka：208 − 0.7 × 年龄。"""
    return 208 - 0.7 * age


def calorie_target(tdee_kcal: float, goal: str) -> float:
    if goal == GOAL_FAT_LOSS:
        return tdee_kcal - 400
    if goal == GOAL_MUSCLE_GAIN:
        return tdee_kcal + 250
    return tdee_kcal


def suggested_split_name(goal: str, weekly_days: Optional[int]) -> str:
    days = weekly_days or 3
    if goal == GOAL_FAT_LOSS:
        return "全身循环 + 有氧" if days <= 3 else "上/下分化 + 有氧"
    if goal == GOAL_MUSCLE_GAIN:
        return "全身力量" if days <= 3 else "推/拉/腿"
    if goal == GOAL_PERFORMANCE:
        return "力量 + 体能"
    return "全身塑形" if days <= 3 else "分化塑形"


@dataclass(frozen=True)
class ProfileMetrics:
    age: int
    bmr: float
    tdee: float
    calorie_target: float
    max_hr: float
    activity_factor: float
    split_name: str


def compute_metrics(
    *,
    gender: str,
    birth_year: int,
    height_cm: float,
    weight_kg: float,
    goal: str,
    experience: str,
    weekly_days: Optional[int] = None,
    now: Optional[datetime] = None,
) -> ProfileMetrics:
    age = age_from_birth_year(birth_year, now)
    bmr = bmr_mifflin(weight_kg, height_cm, age, gender)
    factor = activity_factor(weekly_days, experience)
    tdee_kcal = bmr * factor
    return ProfileMetrics(
        age=age,
        bmr=round(bmr, 1),
        tdee=round(tdee_kcal, 1),
        calorie_target=round(calorie_target(tdee_kcal, goal), 1),
        max_hr=round(max_heart_rate(age), 1),
        activity_factor=factor,
        split_name=suggested_split_name(goal, weekly_days),
    )


# ----- 体重历史 -----

MA_WINDOW_DAYS = 7


def build_weight_history(
    rows: list[tuple[datetime, float]],
    *,
    today: date,
    days: int = 90,
) -> dict:
    """rows: (recorded_at, weight_kg)。按天归并（同日多条取均值）后算 7 日移动平均。

    移动平均为前向填充：窗口内无记录的天沿用上一次已知体重；首个记录日之前的天不计入。
    输出点只包含有记录的日期（体重流水仅在体重值变化时写入，天然稀疏）。
    """
    since = today - timedelta(days=days - 1)
    daily: dict[date, list[float]] = {}
    for recorded_at, weight_kg in rows:
        day = recorded_at.date() if hasattr(recorded_at, "date") else recorded_at
        if day < since or day > today:
            continue
        daily.setdefault(day, []).append(weight_kg)
    if not daily:
        return {"period_days": days, "points": [], "change_kg": None, "records": 0}

    known = sorted(daily)
    daily_mean = {d: sum(v) / len(v) for d, v in daily.items()}

    points: list[dict] = []
    for i, day in enumerate(known):
        window_start = day - timedelta(days=MA_WINDOW_DAYS - 1)
        filled: list[float] = []
        for offset in range(MA_WINDOW_DAYS):
            w = window_start + timedelta(days=offset)
            covered = [k for k in known[: i + 1] if k <= w]
            if covered:
                filled.append(daily_mean[covered[-1]])
        ma7 = sum(filled) / len(filled) if filled else None
        points.append(
            {
                "date": day.isoformat(),
                "weight_kg": round(daily_mean[day], 2),
                "ma7_kg": round(ma7, 2) if ma7 is not None else None,
            }
        )

    change = None
    if len(known) >= 2:
        change = round(daily_mean[known[-1]] - daily_mean[known[0]], 2)
    return {
        "period_days": days,
        "points": points,
        "change_kg": change,
        "records": sum(len(v) for v in daily.values()),
    }
