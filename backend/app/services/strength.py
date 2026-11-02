"""1RM / 容量 / Deload。与客户端 `domain/strength.dart` 保持一致。"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from statistics import median
from typing import Optional

from app.services.rpe import round_to_plate

EPLEY_REP_MIN = 1
EPLEY_REP_MAX = 10
HARD_SET_RPE = 8.0
# 容量、硬组、估算 1RM 只计工作组和递减组。空值按工作组，兼容还没写 set_kind 的旧记录。
LOAD_SET_KINDS = frozenset({"working", "drop"})
SAMPLE_WINDOW = 8
RECALIBRATE_DAYS = 56
SAMPLE_STORE_MAX = 24

# RPE 10 时各次数对应的 %1RM（Helms / Tuchscherer 风格）。
# 有 RPE 时用「等效次数 = 实际次数 + (10 − RPE)」查表并插值。
_RPE10_PCT = (
    0.0,
    100.0,
    95.5,
    92.2,
    89.2,
    86.3,
    83.7,
    81.1,
    78.6,
    76.2,
    73.9,
    71.9,
    69.9,
)


def epley_1rm(weight_kg: float, reps: int) -> Optional[float]:
    """Epley：重量 × (1 + 次数 / 30)。1 次记实测；2–10 次估算。"""
    if weight_kg <= 0 or reps < EPLEY_REP_MIN or reps > EPLEY_REP_MAX:
        return None
    if reps == 1:
        return weight_kg
    return weight_kg * (1.0 + reps / 30.0)


def _rpe10_percent(reps: float) -> float:
    if reps <= 1:
        return 100.0
    if reps >= 12:
        return _RPE10_PCT[12]
    lo = int(reps)
    hi = lo + 1
    t = reps - lo
    return _RPE10_PCT[lo] * (1.0 - t) + _RPE10_PCT[hi] * t


def percent_1rm(reps: int, rpe: float) -> Optional[float]:
    """由次数 + RPE 反推该组占 1RM 的百分比。"""
    if reps < 1 or reps > 20:
        return None
    if rpe < 6.0 or rpe > 10.0:
        return None
    return _rpe10_percent(reps + (10.0 - rpe))


def estimate_1rm(
    weight_kg: Optional[float],
    reps: Optional[int],
    rpe: Optional[float] = None,
) -> Optional[float]:
    """优先用 RPE 表；否则 1 次记实测、2–10 次走 Epley。次数过高直接丢弃。"""
    if weight_kg is None or weight_kg <= 0 or reps is None or reps < 1:
        return None
    if rpe is not None:
        pct = percent_1rm(reps, rpe)
        if pct is not None and pct >= 40:
            return weight_kg * 100.0 / pct
    return epley_1rm(weight_kg, reps)


@dataclass(frozen=True)
class EstimateSample:
    kg: float
    calculated_at: Optional[datetime] = None


@dataclass(frozen=True)
class BlendResult:
    estimated_kg: Optional[float]
    samples_count: int
    stale: bool


def _as_sample(item: float | EstimateSample) -> EstimateSample:
    if isinstance(item, EstimateSample):
        return item
    return EstimateSample(kg=float(item), calculated_at=None)


def blend_estimates(
    samples: list[float] | list[EstimateSample],
    window: int = SAMPLE_WINDOW,
    *,
    now: Optional[datetime] = None,
    max_age_days: int = RECALIBRATE_DAYS,
) -> BlendResult:
    """先取 56 天内样本，再取近 `window` 条中位数。过期则回退全部并标 stale。"""
    parsed = [_as_sample(x) for x in samples if _as_sample(x).kg > 0]
    if not parsed:
        return BlendResult(None, 0, False)

    clock = now or datetime.now(timezone.utc).replace(tzinfo=None)
    if clock.tzinfo is not None:
        clock = clock.replace(tzinfo=None)
    cutoff = clock - timedelta(days=max_age_days)
    fresh = [
        s
        for s in parsed
        if s.calculated_at is None or s.calculated_at.replace(tzinfo=None) >= cutoff
    ]
    stale = not fresh
    chosen = (parsed if stale else fresh)[-window:]
    return BlendResult(float(median([s.kg for s in chosen])), len(chosen), stale)


def rir_from_rpe(rpe: float) -> float:
    return max(0.0, 10.0 - rpe)


@dataclass(frozen=True)
class IntensityZone:
    low: float
    high: float
    rep_low: int
    rep_high: int
    label: str

    @property
    def mid(self) -> float:
        return (self.low + self.high) / 2.0


def intensity_zone(goal: str) -> IntensityZone:
    if goal == "performance":
        return IntensityZone(0.85, 0.95, 2, 5, "最大力量")
    if goal == "reshape":
        return IntensityZone(0.75, 0.85, 5, 8, "力量与增肌")
    if goal == "muscle_gain":
        return IntensityZone(0.65, 0.75, 8, 12, "增肌")
    return IntensityZone(0.55, 0.65, 12, 20, "肌耐力")


def working_weight(one_rm_kg: float, goal: str) -> Optional[float]:
    if one_rm_kg <= 0:
        return None
    return round_to_plate(one_rm_kg * intensity_zone(goal).mid)


def counts_as_load(set_kind: Optional[str]) -> bool:
    """热身和放松不进入负荷统计。未标记的旧组视为工作组。"""
    if not set_kind:
        return True
    return set_kind in LOAD_SET_KINDS


def set_volume(weight_kg: Optional[float], reps: Optional[int]) -> float:
    if weight_kg is None or reps is None or weight_kg <= 0 or reps <= 0:
        return 0.0
    return weight_kg * reps


def is_hard_set(rpe: Optional[float]) -> bool:
    return rpe is not None and rpe >= HARD_SET_RPE


def week_monday(d: date) -> date:
    return d - timedelta(days=d.weekday())


@dataclass(frozen=True)
class WeekVolume:
    week_start: date
    volume: float
    hard_volume: float
    hard_sets: int
    avg_rpe: Optional[float]


def should_suggest_deload(weeks: list[WeekVolume]) -> tuple[bool, Optional[str]]:
    """连续 5 周有量，或近两周容量下降且 RPE 上升。"""
    trained = [w for w in weeks if w.volume > 0]
    if len(trained) >= 5:
        return True, "已连续训练 5 周，建议安排一周减量"
    if len(trained) >= 2:
        prev, last = trained[-2], trained[-1]
        vol_down = last.volume < prev.volume * 0.9
        rpe_up = (
            prev.avg_rpe is not None
            and last.avg_rpe is not None
            and last.avg_rpe > prev.avg_rpe + 0.3
        )
        if vol_down and rpe_up:
            return True, "容量下降但 RPE 上升，恢复可能不足"
    return False, None


@dataclass
class MuscleLoad:
    name: str
    volume: float
    hard_sets: int


@dataclass
class WeekReport:
    week_start: date
    volume: float
    hard_volume: float
    hard_sets: int
    avg_rpe: Optional[float]
    by_muscle: list[MuscleLoad]


def build_weekly_report(
    rows: list[tuple],
    today: date,
    n_weeks: int = 8,
) -> list[WeekReport]:
    """rows: (started_at, reps, weight_kg, rpe, muscle_name)。"""
    origin = week_monday(today) - timedelta(weeks=n_weeks - 1)
    buckets: dict[date, dict] = {}
    for i in range(n_weeks):
        ws = origin + timedelta(weeks=i)
        buckets[ws] = {
            "volume": 0.0,
            "hard_volume": 0.0,
            "hard_sets": 0,
            "rpe_sum": 0.0,
            "rpe_n": 0,
            "muscles": {},
        }

    for started_at, reps, weight_kg, rpe, muscle_name in rows:
        if started_at is None:
            continue
        day = started_at.date() if hasattr(started_at, "date") else started_at
        ws = week_monday(day)
        bucket = buckets.get(ws)
        if bucket is None:
            continue
        vol = set_volume(weight_kg, reps)
        bucket["volume"] += vol
        hard = is_hard_set(rpe)
        if hard:
            bucket["hard_volume"] += vol
            bucket["hard_sets"] += 1
        if rpe is not None:
            bucket["rpe_sum"] += rpe
            bucket["rpe_n"] += 1
        name = muscle_name or "其他"
        muscle = bucket["muscles"].setdefault(name, {"volume": 0.0, "hard_sets": 0})
        muscle["volume"] += vol
        if hard:
            muscle["hard_sets"] += 1

    reports: list[WeekReport] = []
    for ws in sorted(buckets):
        b = buckets[ws]
        avg = b["rpe_sum"] / b["rpe_n"] if b["rpe_n"] else None
        by_muscle = [
            MuscleLoad(name=n, volume=round(v["volume"], 1), hard_sets=v["hard_sets"])
            for n, v in sorted(
                b["muscles"].items(), key=lambda kv: kv[1]["volume"], reverse=True
            )
        ]
        reports.append(
            WeekReport(
                week_start=ws,
                volume=round(b["volume"], 1),
                hard_volume=round(b["hard_volume"], 1),
                hard_sets=b["hard_sets"],
                avg_rpe=round(avg, 2) if avg is not None else None,
                by_muscle=by_muscle,
            )
        )
    return reports


# ----- 个体化恢复窗口 -----

EFFECTIVE_HARD_SETS = 3
EFFECTIVE_AVG_RPE = 7.5
PERFORMANCE_DROP_THRESHOLD = -0.03
RECOVERY_FACTOR_MIN = 0.6
RECOVERY_FACTOR_MAX = 1.4
RECOVERY_DELTA_MIN = 0.03
RECOVERY_DELTA_MAX = 0.04
RECOVERY_HALF_LIFE_DAYS = 60.0
MIN_MUSCLE_OBSERVATIONS = 5
MIN_GLOBAL_OBSERVATIONS = 20
OBSERVATION_STORE_MAX = 40
OBSERVATION_WEIGHT_FLOOR = 0.05

LARGE_BASELINE_HOURS = 60.0  # 文献大肌群 48–72h 中位
SMALL_BASELINE_HOURS = 36.0  # 文献小肌群 24–48h 中位

_LARGE_MUSCLE_EN = {
    "chest",
    "upper chest",
    "lower chest",
    "back",
    "lats",
    "upper back",
    "lower back",
    "quadriceps",
    "hamstrings",
    "glutes",
    "shoulders",
}
_LARGE_MUSCLE_ZH = {
    "胸部",
    "上胸部",
    "下胸部",
    "背部",
    "背阔肌",
    "上背部",
    "下背部",
    "股四头肌",
    "腘绳肌",
    "臀部",
    "肩部",
}


@dataclass(frozen=True)
class RecoverySet:
    rpe: Optional[float] = None
    weight_kg: Optional[float] = None
    reps: Optional[int] = None


@dataclass(frozen=True)
class RecoveryObservation:
    at: datetime
    interval_hours: float
    baseline_hours: float
    performance_change: float
    delta: float


@dataclass(frozen=True)
class MuscleGroupStatus:
    muscle_group_id: int
    name: str
    name_en: str
    category: str
    last_trained_at: datetime
    hours_since_last: float
    recovery_progress: float
    recovery_window_hours: float
    baseline_window_hours: float
    recovery_factor: float
    global_factor: float
    muscle_factor: float
    recovery_confidence: str
    observations_count: int


def baseline_window_hours(name: str = "", name_en: str = "") -> float:
    """大肌群 60h / 小肌群 36h。按中英文名识别，对不上则按小肌群。"""
    en = (name_en or "").strip().lower()
    zh = (name or "").strip()
    if en in _LARGE_MUSCLE_EN or zh in _LARGE_MUSCLE_ZH:
        return LARGE_BASELINE_HOURS
    return SMALL_BASELINE_HOURS


def is_effective_session(sets: list[RecoverySet]) -> bool:
    """有效刺激：RPE ≥ 8 的组 ≥ 3，且有 RPE 的组平均 ≥ 7.5。"""
    hard = [s for s in sets if is_hard_set(s.rpe)]
    if len(hard) < EFFECTIVE_HARD_SETS:
        return False
    rpes = [s.rpe for s in sets if s.rpe is not None]
    if not rpes:
        return False
    return (sum(rpes) / len(rpes)) >= EFFECTIVE_AVG_RPE


def session_estimated_1rm(sets: list[RecoverySet]) -> Optional[float]:
    """本组 reps ≤ 10 的 1RM 估算中位数。"""
    estimates: list[float] = []
    for s in sets:
        est = estimate_1rm(s.weight_kg, s.reps, s.rpe)
        if est is not None:
            estimates.append(est)
    if not estimates:
        return None
    return float(median(estimates))


def performance_change(current_1rm: float, previous_1rm: float) -> Optional[float]:
    if previous_1rm <= 0:
        return None
    return (current_1rm - previous_1rm) / previous_1rm


def recovery_delta(
    interval_hours: float,
    baseline_hours: float,
    perf_change: float,
) -> float:
    """仅高频（间隔短于基线）时给出 ±0.03~0.04；其它为 0。"""
    if baseline_hours <= 0 or interval_hours >= baseline_hours:
        return 0.0
    ratio = max(0.0, min(1.0, interval_hours / baseline_hours))
    mag = RECOVERY_DELTA_MIN + (RECOVERY_DELTA_MAX - RECOVERY_DELTA_MIN) * (1.0 - ratio)
    if perf_change >= 0:
        return -mag
    if perf_change < PERFORMANCE_DROP_THRESHOLD:
        return mag
    return 0.0


def _as_naive(dt: datetime) -> datetime:
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def observation_weight(observed_at: datetime, now: datetime) -> float:
    age_days = (_as_naive(now) - _as_naive(observed_at)).total_seconds() / 86400.0
    if age_days < 0:
        age_days = 0.0
    return 0.5 ** (age_days / RECOVERY_HALF_LIFE_DAYS)


def clamp_recovery_factor(value: float) -> float:
    return max(RECOVERY_FACTOR_MIN, min(RECOVERY_FACTOR_MAX, value))


def compute_recovery_factor(
    observations: list[RecoveryObservation],
    now: datetime,
    min_count: int,
) -> tuple[float, int]:
    """加权求和偏离 1.0；样本不足则锁在 1.0。返回 (factor, 有效观察数)。"""
    weighted: list[tuple[float, float]] = []
    for obs in observations:
        w = observation_weight(obs.at, now)
        if w < OBSERVATION_WEIGHT_FLOOR:
            continue
        weighted.append((w, obs.delta))
    count = len(weighted)
    if count < min_count:
        return 1.0, count
    factor = 1.0 + sum(w * d for w, d in weighted)
    return clamp_recovery_factor(factor), count


def recovery_confidence(observations_count: int) -> str:
    if observations_count >= MIN_GLOBAL_OBSERVATIONS:
        return "high"
    if observations_count >= MIN_MUSCLE_OBSERVATIONS:
        return "medium"
    return "low"


def recovery_progress(hours_since_last: float, recovery_window_hours: float) -> float:
    if recovery_window_hours <= 0:
        return 1.0
    return hours_since_last / recovery_window_hours


def compute_muscle_group_status(
    *,
    muscle_group_id: int,
    name: str,
    name_en: str,
    category: str,
    last_trained_at: datetime,
    now: datetime,
    muscle_observations: list[RecoveryObservation],
    global_observations: list[RecoveryObservation],
) -> MuscleGroupStatus:
    """恢复进度 = 距上次训练小时 / (基线 × 全局系数 × 单肌群系数)。"""
    baseline = baseline_window_hours(name, name_en)
    muscle_factor, muscle_count = compute_recovery_factor(
        muscle_observations, now, MIN_MUSCLE_OBSERVATIONS
    )
    global_factor, _global_count = compute_recovery_factor(
        global_observations, now, MIN_GLOBAL_OBSERVATIONS
    )
    factor = muscle_factor * global_factor
    window = baseline * factor
    last_at = _as_naive(last_trained_at)
    clock = _as_naive(now)
    hours = max(0.0, (clock - last_at).total_seconds() / 3600.0)
    progress = recovery_progress(hours, window)
    return MuscleGroupStatus(
        muscle_group_id=muscle_group_id,
        name=name,
        name_en=name_en,
        category=category,
        last_trained_at=last_at,
        hours_since_last=round(hours, 2),
        recovery_progress=round(progress, 4),
        recovery_window_hours=round(window, 2),
        baseline_window_hours=baseline,
        recovery_factor=round(factor, 4),
        global_factor=round(global_factor, 4),
        muscle_factor=round(muscle_factor, 4),
        recovery_confidence=recovery_confidence(muscle_count),
        observations_count=muscle_count,
    )
