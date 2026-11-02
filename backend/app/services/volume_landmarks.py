"""肌群周容量地标（MEV / MAV / MRV），Renaissance Periodization 体系。

数值为训练有素者的参考区间（每周 hard set 数，主肌群口径）；
未收录的肌群使用保守默认值并在响应中标记 is_default。
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Landmarks:
    mv: int
    mev: int
    mav_low: int
    mav_high: int
    mrv: int


# 键为 muscle_groups.name（中文）。数值参照 Israetel《Scientific Principles of
# Hypertrophy Training》的地标表，结合本产品 hard set（RPE>=8）口径做了保守化。
MUSCLE_LANDMARKS: dict[str, Landmarks] = {
    "胸部": Landmarks(8, 10, 12, 20, 22),
    "上胸部": Landmarks(4, 6, 8, 14, 16),
    "背部": Landmarks(8, 10, 14, 22, 25),
    "背阔肌": Landmarks(6, 8, 12, 18, 20),
    "上背部": Landmarks(4, 6, 8, 14, 16),
    "肩部": Landmarks(6, 8, 12, 20, 22),
    "三角肌中束": Landmarks(6, 8, 16, 22, 26),
    "三角肌后束": Landmarks(0, 6, 10, 16, 20),
    "肱二头肌": Landmarks(4, 6, 8, 16, 20),
    "肱三头肌": Landmarks(4, 6, 8, 14, 18),
    "股四头肌": Landmarks(6, 8, 12, 18, 20),
    "腘绳肌": Landmarks(4, 6, 8, 14, 16),
    "臀部": Landmarks(0, 4, 8, 16, 18),
    "小腿": Landmarks(4, 6, 8, 16, 20),
    "腹肌": Landmarks(0, 4, 8, 16, 20),
    "竖脊肌": Landmarks(0, 4, 8, 12, 16),
    "前臂": Landmarks(0, 4, 8, 12, 16),
}

DEFAULT_LANDMARKS = Landmarks(4, 6, 8, 14, 16)


def landmarks_for(name: str) -> Landmarks:
    return MUSCLE_LANDMARKS.get(name, DEFAULT_LANDMARKS)


def zone_for(hard_sets: int, lm: Landmarks) -> str:
    """below_mev / mev / mav / above_mrv。"""
    if hard_sets < lm.mev:
        return "below_mev"
    if hard_sets < lm.mav_low:
        return "mev"
    if hard_sets <= lm.mrv:
        return "mav"
    return "above_mrv"


def volume_landmarks(trained: dict[str, int]) -> list[dict]:
    """常量表全部肌群 ∪ 本周练过的其它肌群。

    trained: 肌群中文名 -> 本周 hard_sets。
    """
    names = set(MUSCLE_LANDMARKS) | set(trained)
    items = []
    for name in names:
        lm = landmarks_for(name)
        sets = trained.get(name, 0)
        items.append(
            {
                "name": name,
                "hard_sets": sets,
                "zone": zone_for(sets, lm),
                "mv": lm.mv,
                "mev": lm.mev,
                "mav_low": lm.mav_low,
                "mav_high": lm.mav_high,
                "mrv": lm.mrv,
                "is_default": name not in MUSCLE_LANDMARKS,
            }
        )
    items.sort(key=lambda i: (-i["hard_sets"], i["name"]))
    return items
