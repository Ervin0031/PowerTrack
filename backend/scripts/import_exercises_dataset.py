#!/usr/bin/env python3
"""把 hasaneyldrm/exercises-dataset 的动作和 GIF 导入动作库。

按英文名对齐已有动作：没有示范图的补 GIF，已有图的保留。
对不上的新建，中文名供搜索，说明用数据集里的中文步骤。

用法：
    cd backend
    uv run python scripts/import_exercises_dataset.py --dataset /tmp/exercises-dataset --dry-run
    uv run python scripts/import_exercises_dataset.py --dataset /tmp/exercises-dataset
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import httpx

DEFAULT_BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")
DEFAULT_USER = os.getenv("ADMIN_USER", "")
DEFAULT_PASS = os.getenv("ADMIN_PASS", "")

# 数据集 target → 已有肌群中文名。值为 None 时按 NEW_MUSCLES 创建。
TARGET_MUSCLE: dict[str, str] = {
    "abs": "腹直肌",
    "pectorals": "胸部",
    "biceps": "肱二头肌",
    "glutes": "臀部",
    "delts": "肩部",
    "triceps": "肱三头肌",
    "upper back": "上背部",
    "lats": "背阔肌",
    "calves": "小腿",
    "quads": "股四头肌",
    "forearms": "前臂",
    "cardiovascular system": "有氧",
    "hamstrings": "腘绳肌",
    "spine": "竖脊肌",
    "traps": "斜方肌",
    "adductors": "内收肌",
    "serratus anterior": "前锯肌",
    "abductors": "外展肌",
    "levator scapulae": "肩胛提肌",
}

NEW_MUSCLES: dict[str, tuple[str, str]] = {
    "有氧": ("Cardiovascular System", "cardio"),
    "前锯肌": ("Serratus Anterior", "upper"),
    "肩胛提肌": ("Levator Scapulae", "upper"),
}

# 辅助肌群英文 → 中文。对不上的跳过，不为此新建肌群。
SECONDARY_MUSCLE: dict[str, str] = {
    "shoulders": "肩部",
    "hamstrings": "腘绳肌",
    "forearms": "前臂",
    "triceps": "肱三头肌",
    "biceps": "肱二头肌",
    "quadriceps": "股四头肌",
    "calves": "小腿",
    "glutes": "臀部",
    "core": "核心整体",
    "chest": "胸部",
    "hip flexors": "髋屈肌",
    "obliques": "腹斜肌",
    "lower back": "下背部",
    "rhomboids": "上背部",
    "trapezius": "斜方肌",
    "upper back": "上背部",
    "traps": "斜方肌",
    "deltoids": "肩部",
    "rear deltoids": "三角肌后束",
    "brachialis": "肱二头肌",
    "back": "背部",
    "latissimus dorsi": "背阔肌",
    "lats": "背阔肌",
    "abdominals": "腹直肌",
    "lower abs": "腹直肌",
    "upper chest": "上胸部",
    "adductors": "内收肌",
    "abductors": "外展肌",
    "inner thighs": "内收肌",
    "soleus": "小腿",
    "spine": "竖脊肌",
    "abs": "腹直肌",
    "pectorals": "胸部",
    "quads": "股四头肌",
    "serratus anterior": "前锯肌",
}

# 数据集 equipment → 中文名。不在已有表里的会创建。
EQUIPMENT_ZH: dict[str, str] = {
    "body weight": "自重",
    "dumbbell": "哑铃",
    "cable": "龙门架",
    "barbell": "杠铃",
    "leverage machine": "杠杆器械",
    "band": "弹力带",
    "smith machine": "史密斯机",
    "kettlebell": "壶铃",
    "weighted": "负重",
    "stability ball": "瑜伽球",
    "ez barbell": "EZ杠铃",
    "assisted": "辅助器械",
    "sled machine": "雪橇机",
    "medicine ball": "药球",
    "rope": "绳索",
    "roller": "泡沫轴",
    "resistance band": "弹力带",
    "bosu ball": "BOSU球",
    "olympic barbell": "杠铃",
    "wheel roller": "健腹轮",
    "upper body ergometer": "上肢功率车",
    "skierg machine": "滑雪机",
    "hammer": "大锤",
    "stationary bike": "固定单车",
    "tire": "轮胎",
    "trap bar": "陷阱杠",
    "elliptical machine": "椭圆机",
    "stepmill machine": "登山机",
}

NEW_EQUIPMENT_EN: dict[str, str] = {
    "杠杆器械": "Leverage Machine",
    "负重": "Weighted",
    "瑜伽球": "Stability Ball",
    "EZ杠铃": "EZ Barbell",
    "辅助器械": "Assisted",
    "雪橇机": "Sled",
    "药球": "Medicine Ball",
    "绳索": "Rope",
    "泡沫轴": "Foam Roller",
    "BOSU球": "BOSU Ball",
    "健腹轮": "Ab Wheel",
    "上肢功率车": "Upper Body Ergometer",
    "滑雪机": "SkiErg",
    "大锤": "Sledgehammer",
    "固定单车": "Stationary Bike",
    "轮胎": "Tire",
    "陷阱杠": "Trap Bar",
    "椭圆机": "Elliptical",
    "登山机": "Stair Climber",
}

# 英文动作名 → 中文，长词优先。
PHRASES: list[tuple[str, str]] = [
    ("stability ball", "瑜伽球"),
    ("exercise ball", "瑜伽球"),
    ("medicine ball", "药球"),
    ("smith machine", "史密斯机"),
    ("ez barbell", "EZ杠铃"),
    ("ez-bar", "EZ杠"),
    ("sz-bar", "EZ杠"),
    ("v-bar", "V把"),
    ("trap bar", "陷阱杠"),
    ("olympic barbell", "杠铃"),
    ("body weight", "自重"),
    ("bodyweight", "自重"),
    ("resistance band", "弹力带"),
    ("bosu ball", "BOSU球"),
    ("close-grip", "窄距"),
    ("close grip", "窄距"),
    ("wide-grip", "宽距"),
    ("wide grip", "宽距"),
    ("reverse-grip", "反握"),
    ("reverse grip", "反握"),
    ("neutral grip", "对握"),
    ("neutral-grip", "对握"),
    ("underhand", "反手"),
    ("overhand", "正手"),
    ("behind the neck", "颈后"),
    ("behind neck", "颈后"),
    ("one arm", "单臂"),
    ("one-arm", "单臂"),
    ("single arm", "单臂"),
    ("single-arm", "单臂"),
    ("single leg", "单腿"),
    ("single-leg", "单腿"),
    ("one leg", "单腿"),
    ("bent over", "俯身"),
    ("bent-over", "俯身"),
    ("lat pulldown", "高位下拉"),
    ("pull-up", "引体向上"),
    ("pull up", "引体向上"),
    ("chin-up", "反手引体向上"),
    ("chin up", "反手引体向上"),
    ("push-up", "俯卧撑"),
    ("push up", "俯卧撑"),
    ("sit-up", "仰卧起坐"),
    ("sit up", "仰卧起坐"),
    ("muscle-up", "双力臂"),
    ("muscle up", "双力臂"),
    ("step-up", "登阶"),
    ("hip thrust", "臀推"),
    ("glute bridge", "臀桥"),
    ("good morning", "早安式"),
    ("face pull", "面拉"),
    ("upright row", "直立划船"),
    ("deadlift", "硬拉"),
    ("romanian", "罗马尼亚"),
    ("bench press", "卧推"),
    ("chest press", "推胸"),
    ("shoulder press", "推举"),
    ("overhead press", "过头推举"),
    ("military press", "实力推"),
    ("lateral raise", "侧平举"),
    ("front raise", "前平举"),
    ("rear delt", "后束"),
    ("calf raise", "提踵"),
    ("leg press", "腿举"),
    ("leg extension", "腿屈伸"),
    ("leg curl", "腿弯举"),
    ("leg raise", "举腿"),
    ("wrist curl", "腕弯举"),
    ("bicep curl", "弯举"),
    ("biceps curl", "弯举"),
    ("hammer curl", "锤式弯举"),
    ("preacher curl", "牧师凳弯举"),
    ("concentration curl", "集中弯举"),
    ("spider curl", "蜘蛛弯举"),
    ("tricep extension", "臂屈伸"),
    ("triceps extension", "臂屈伸"),
    ("triceps pushdown", "三头下压"),
    ("tricep pushdown", "三头下压"),
    ("pushdown", "下压"),
    ("kickback", "后踢"),
    ("pullover", "仰卧屈臂上拉"),
    ("mountain climber", "登山跑"),
    ("russian twist", "俄罗斯转体"),
    ("jumping jack", "开合跳"),
    ("burpee", "波比跳"),
    ("turkish get-up", "土耳其起立"),
    ("get-up", "起立"),
    ("dumbbell", "哑铃"),
    ("barbell", "杠铃"),
    ("kettlebell", "壶铃"),
    ("cable", "绳索"),
    ("band", "弹力带"),
    ("lever", "器械"),
    ("smith", "史密斯"),
    ("sled", "雪橇"),
    ("roller", "泡沫轴"),
    ("rope", "绳索"),
    ("weighted", "负重"),
    ("assisted", "辅助"),
    ("incline", "上斜"),
    ("decline", "下斜"),
    ("seated", "坐姿"),
    ("standing", "站姿"),
    ("lying", "仰卧"),
    ("kneeling", "跪姿"),
    ("prone", "俯卧"),
    ("supine", "仰卧"),
    ("hanging", "悬垂"),
    ("inverted", "倒立"),
    ("alternating", "交替"),
    ("alternate", "交替"),
    ("squat", "深蹲"),
    ("lunge", "弓步"),
    ("press", "推"),
    ("curl", "弯举"),
    ("row", "划船"),
    ("raise", "上举"),
    ("fly", "飞鸟"),
    ("extension", "伸展"),
    ("crunch", "卷腹"),
    ("plank", "平板支撑"),
    ("shrug", "耸肩"),
    ("dip", "臂屈伸"),
    ("dips", "臂屈伸"),
    ("twist", "转体"),
    ("rotation", "旋转"),
    ("stretch", "拉伸"),
    ("bridge", "桥"),
    ("clean", "翻站"),
    ("snatch", "抓举"),
    ("swing", "摇摆"),
    ("carry", "行走"),
    ("jump", "跳"),
    ("pull", "拉"),
    ("push", "推"),
    ("squat", "深蹲"),
    ("hammer", "锤式"),
    ("preacher", "牧师凳"),
    ("concentration", "集中"),
    ("reverse", "反向"),
    ("close", "窄距"),
    ("wide", "宽距"),
    ("narrow", "窄"),
    ("high", "高位"),
    ("low", "低位"),
    ("front", "前"),
    ("rear", "后"),
    ("side", "侧"),
    ("inner", "内侧"),
    ("overhead", "过头"),
    ("floor", "地板"),
    ("wall", "靠墙"),
    ("parallel", "平行"),
    ("full", "完整"),
    ("straight", "直"),
    ("stiff", "直腿"),
    ("sumo", "相扑"),
    ("split", "分腿"),
    ("hack", "哈克"),
    ("military", "实力"),
    ("neutral", "对握"),
    ("palms", "掌心"),
    ("wrist", "腕"),
    ("calf", "小腿"),
    ("chest", "胸部"),
    ("shoulder", "肩"),
    ("biceps", "肱二头肌"),
    ("bicep", "肱二头肌"),
    ("triceps", "肱三头肌"),
    ("tricep", "肱三头肌"),
    ("delt", "三角肌"),
    ("glute", "臀"),
    ("hamstring", "腘绳肌"),
    ("lat", "背阔"),
    ("hip", "髋"),
    ("knee", "膝"),
    ("knees", "双膝"),
    ("leg", "腿"),
    ("legs", "双腿"),
    ("arm", "臂"),
    ("arms", "双臂"),
    ("back", "背部"),
    ("neck", "颈"),
    ("head", "头"),
    ("toe", "脚尖"),
    ("ankle", "踝"),
    ("ankles", "双踝"),
    ("ball", "球"),
    ("bar", "杠"),
    ("bench", "平板"),
    ("machine", "器械"),
    ("single", "单"),
    ("double", "双"),
    ("two", "双"),
    ("one", "单"),
    ("upper", "上"),
    ("lower", "下"),
    ("left", "左"),
    ("right", "右"),
    ("forward", "向前"),
    ("around", "环绕"),
    ("cross", "交叉"),
    ("crossed", "交叉"),
    ("grip", "握"),
    ("hands", "双手"),
    ("hand", "手"),
    ("self", "自助"),
    ("inverse", "反向"),
    ("suspended", "悬挂"),
    ("support", "支撑"),
    ("touch", "触地"),
    ("run", "跑"),
    ("bike", "单车"),
    ("wheel", "轮"),
    ("tire", "轮胎"),
    ("towel", "毛巾"),
    ("vertical", "垂直"),
    ("horizontal", "水平"),
    ("45", "45度"),
    ("90", "90度"),
    ("3/4", "四分之三"),
    ("pulldown", "下拉"),
    ("pull-down", "下拉"),
    ("lateral", "侧向"),
    ("bent", "屈"),
    ("behind", "后"),
    ("twisting", "转体"),
    ("twist", "转体"),
    ("bend", "屈"),
    ("bends", "屈"),
    ("blaster", "固定器"),
    ("arm blaster", "弯举固定器"),
    ("attachment", "配件"),
    ("rollerout", "滚出"),
    ("rollout", "滚出"),
    ("throw", "抛"),
    ("lift", "提"),
    ("lifts", "提"),
    ("revers", "反向"),
    ("adduction", "内收"),
    ("abduction", "外展"),
    ("bosu", "BOSU"),
    ("against", "对抗"),
    ("tap", "点触"),
    ("donkey", "驴式"),
    ("elbow", "肘"),
    ("elbows", "双肘"),
    ("zottman", "佐特曼"),
    ("hyperextension", "超伸"),
    ("hyper extension", "超伸"),
    ("jerk", "挺举"),
    ("circles", "绕环"),
    ("circle", "绕环"),
    ("archer", "射箭式"),
    ("calves", "小腿"),
    ("quads", "股四头"),
    ("internal", "内旋"),
    ("external", "外旋"),
    ("through", "穿过"),
    ("step", "登"),
    ("steps", "登"),
    ("drop", "递减"),
    ("squatting", "蹲"),
    ("raised", "抬起"),
    ("arnold", "阿诺德"),
    ("palm", "掌"),
    ("french", "法式"),
    ("plyo", "增强式"),
    ("pike", "折刀"),
    ("scapula", "肩胛"),
    ("scapular", "肩胛"),
    ("hang", "悬垂"),
    ("pelvic tilt", "骨盆倾斜"),
    ("reach", "够"),
    ("raises", "上举"),
    ("walking", "行走"),
    ("slingers", "摆臂"),
    ("fixed", "固定"),
    ("pallof", "帕洛夫"),
    ("jackknife", "折刀"),
    ("drag", "拖拽"),
    ("zercher", "泽奇"),
    ("skull crusher", "碎颅"),
    ("skullcrusher", "碎颅"),
    ("sitted", "坐姿"),
    ("thruster", "推力深蹲"),
    ("bottoms", "底部"),
    ("bottom", "底部"),
    ("box", "箱子"),
    ("pulley", "滑轮"),
    ("tuck", "收腹"),
    ("chair", "椅子"),
    ("extended", "伸直"),
    ("cage", "框式"),
    ("chin", "反手"),
    ("trainer", "训练器"),
    ("cuban", "古巴"),
    ("goblet", "高脚杯"),
    ("curls", "弯举"),
    ("iron", "铁"),
    ("deltoid", "三角肌"),
    ("pronation", "旋前"),
    ("supination", "旋后"),
    ("tennis", "网球"),
    ("flexion", "屈曲"),
    ("planche", "普朗什"),
    ("half", "半程"),
    ("handstand", "倒立"),
    ("oblique", "腹斜肌"),
    ("inchworm", "寸虫"),
    ("squeeze", "挤压"),
    ("jack", "开合"),
    ("windmill", "风车"),
    ("pistol", "手枪"),
    ("flat", "平板"),
    ("gripless", "无握"),
    ("slam", "砸"),
    ("kick", "踢"),
    ("sissy", "西西"),
    ("spine", "脊柱"),
    ("stationary", "固定"),
    ("three", "三"),
    ("twisted", "转体"),
    ("air", "空中"),
    ("fours", "四点"),
    ("all fours", "四点支撑"),
    ("squad", "深蹲"),
    ("heel", "脚跟"),
    ("touchers", "触地"),
    ("apart", "分开"),
    ("circular", "绕环"),
    ("glutes", "臀"),
    ("motion", "动作"),
    ("clock", "时钟"),
    ("clockwise", "顺时针"),
    ("counterclockwise", "逆时针"),
    ("ez", "EZ"),
    ("y", "Y字"),
    ("t", "T字"),
    ("l", "L字"),
    ("sit", "坐"),
    ("ups", "重复"),
    ("body", "身体"),
    ("up", "向上"),
    ("to", "到"),
    ("in", "在"),
    ("with", "带"),
    ("jm", "JM"),
    ("bars", "双杠"),
    ("bar", "杠"),
]

DROP_WORDS = {
    "on",
    "the",
    "with",
    "a",
    "an",
    "of",
    "to",
    "and",
    "in",
    "for",
    "at",
    "from",
    "into",
    "between",
    "both",
    "using",
    "v",
    "version",
    "male",
    "female",
    "pov",
    "exercise",
    "over",
    "under",
    "up",
    "down",
    "or",
}

ISOLATION_WORDS = (
    "curl",
    "raise",
    "fly",
    "extension",
    "kickback",
    "crunch",
    "shrug",
    "pushdown",
    "pullover",
    "wrist",
    "twist",
    "rotation",
    "stretch",
    "calf raise",
    "leg extension",
    "leg curl",
)
COMPOUND_WORDS = (
    "squat",
    "deadlift",
    "lunge",
    "press",
    "row",
    "pull-up",
    "pull up",
    "pulldown",
    "chin-up",
    "chin up",
    "push-up",
    "push up",
    "clean",
    "snatch",
    "burpee",
    "swing",
    "carry",
    "good morning",
    "hip thrust",
    "step-up",
    "muscle-up",
    "muscle up",
    "jerk",
    "get-up",
    "thruster",
)
ISOLATION_TARGETS = {
    "biceps",
    "triceps",
    "calves",
    "forearms",
    "abs",
    "adductors",
    "abductors",
    "serratus anterior",
    "levator scapulae",
}


def norm_en(value: str) -> str:
    text = value.lower().replace("bicep", "biceps").replace("tricep", "triceps")
    text = text.replace("flye", "fly")
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return " ".join(text.split())


def _join_name(parts: list[str]) -> str:
    pieces: list[str] = []
    for part in parts:
        if (
            pieces
            and re.search(r"[A-Za-z0-9]$", pieces[-1])
            and re.match(r"[A-Za-z0-9]", part)
        ):
            pieces.append(" ")
        pieces.append(part)
    return "".join(pieces).strip()


def translate_name(name: str) -> str:
    text = name.lower().strip()
    text = re.sub(r"\bv\.?\s*\d+\b", " ", text)
    match = re.match(r"^(.*?)\s*\((.*)\)\s*$", text)
    paren = ""
    if match:
        text, paren = match.group(1), match.group(2)

    def apply_phrases(raw: str) -> str:
        for src, dst in sorted(PHRASES, key=lambda item: len(item[0]), reverse=True):
            raw = re.sub(rf"(?i)\b{re.escape(src)}\b", dst, raw)
        return raw

    text = apply_phrases(text)
    if paren:
        paren = apply_phrases(paren)

    parts: list[str] = []
    for token in re.split(r"\s+", text.strip()):
        token = token.strip("-,/")
        if not token or token in DROP_WORDS:
            continue
        parts.append(token)
    zh = _join_name(parts)
    if paren:
        inner = _join_name(
            [
                tok
                for tok in (
                    part.strip("-,/") for part in re.split(r"\s+", paren.strip())
                )
                if tok and tok not in DROP_WORDS
            ]
        )
        if inner:
            zh = f"{zh}（{inner}）"
    zh = re.sub(r"\s+", "", zh)
    return zh[:100] or name[:100]


def chinese_name(record: dict) -> str:
    """中文动作名。译不全时退回「器械+肌群（英文原名）」，保证能搜。"""
    translated = translate_name(record["name"])
    leftover = re.sub(r"BOSU|EZ|JM", "", translated)
    if re.search(r"[A-Za-z]{4,}", leftover):
        muscle = TARGET_MUSCLE[record["target"]]
        equip = EQUIPMENT_ZH[record["equipment"]]
        label = muscle if equip == "自重" else f"{equip}{muscle}"
        translated = f"{label}（{record['name']}）"
    return translated[:100]


def exercise_type(name: str, target: str) -> str:
    lowered = name.lower()
    isolation = any(word in lowered for word in ISOLATION_WORDS)
    compound = any(word in lowered for word in COMPOUND_WORDS)
    if isolation and not compound:
        return "isolation"
    if compound and not isolation:
        return "compound"
    if target in ISOLATION_TARGETS:
        return "isolation"
    return "compound"


def chinese_steps(record: dict) -> str:
    steps = (record.get("instruction_steps") or {}).get("zh") or []
    if not steps:
        text = (record.get("instructions") or {}).get("zh") or ""
        steps = [text] if text else []
    body = "\n".join(step.strip() for step in steps if step and step.strip())
    marker = f"来源 exercises-dataset #{record['id']}"
    return f"{body}\n\n{marker}" if body else marker


class Api:
    def __init__(self, base_url: str, username: str, password: str) -> None:
        self.base = base_url.rstrip("/")
        self.client = httpx.Client(timeout=120.0)
        token = self._login(username, password)
        self.client.headers["Authorization"] = f"Bearer {token}"

    def _login(self, username: str, password: str) -> str:
        response = self.client.post(
            f"{self.base}/api/v1/auth/login",
            json={"username": username, "password": password},
        )
        response.raise_for_status()
        token = response.json().get("access_token")
        if not token:
            raise RuntimeError(f"登录失败: {response.text}")
        return token

    def paged(self, path: str) -> list[dict]:
        items: list[dict] = []
        skip = 0
        while True:
            response = self.client.get(
                f"{self.base}{path}", params={"skip": skip, "limit": 100}
            )
            response.raise_for_status()
            data = response.json()
            batch = data["items"]
            items.extend(batch)
            if skip + len(batch) >= data["total"]:
                return items
            skip += 100

    def post_json(self, path: str, payload: dict) -> dict:
        response = self.client.post(f"{self.base}{path}", json=payload)
        if response.status_code >= 400:
            raise RuntimeError(f"{response.status_code} {response.text}")
        return response.json()

    def create_exercise(self, payload: dict, gif: Path) -> dict:
        with gif.open("rb") as handle:
            response = self.client.post(
                f"{self.base}/api/v1/exercises",
                data={"data": json.dumps(payload, ensure_ascii=False)},
                files={"image": (gif.name, handle, "image/gif")},
            )
        if response.status_code >= 400:
            raise RuntimeError(f"{response.status_code} {response.text}")
        return response.json()

    def upload_image(self, exercise_id: int, gif: Path) -> dict:
        with gif.open("rb") as handle:
            response = self.client.put(
                f"{self.base}/api/v1/exercises/{exercise_id}",
                data={"data": "{}"},
                files={"image": (gif.name, handle, "image/gif")},
            )
        if response.status_code >= 400:
            raise RuntimeError(f"{response.status_code} {response.text}")
        return response.json()


def load_records(dataset: Path) -> list[dict]:
    path = dataset / "data" / "exercises.json"
    records = json.loads(path.read_text())
    missing = [rec["id"] for rec in records if not (dataset / rec["gif_url"]).is_file()]
    if missing:
        raise RuntimeError(f"缺少 GIF: {missing[:5]}")
    return records


def unique_name(base: str, used: set[str], suffix: str) -> str:
    if base not in used and len(base) <= 100:
        return base
    extra = f" {suffix}"
    trimmed = base[: 100 - len(extra)].rstrip()
    candidate = f"{trimmed}{extra}"
    n = 2
    while candidate in used:
        extra = f" {suffix}-{n}"
        trimmed = base[: 100 - len(extra)].rstrip()
        candidate = f"{trimmed}{extra}"
        n += 1
    return candidate


def main() -> int:
    parser = argparse.ArgumentParser(description="导入 exercises-dataset")
    parser.add_argument("--dataset", type=Path, required=True)
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--user", default=DEFAULT_USER)
    parser.add_argument("--password", default=DEFAULT_PASS)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()

    if not args.user or not args.password:
        print(
            "缺少管理员账号：请用 --user/--password 或 ADMIN_USER/ADMIN_PASS 提供",
            file=sys.stderr,
        )
        return 1

    records = load_records(args.dataset)
    if args.limit:
        records = records[: args.limit]
    print(f"数据集 {len(records)} 条  服务器 {args.base_url}")

    api = Api(args.base_url, args.user, args.password)
    exercises = api.paged("/api/v1/exercises")
    muscles = {
        item["name"]: item["id"]
        for item in api.paged("/api/v1/exercises/muscle-groups")
    }
    equipment = {
        item["name"]: item["id"] for item in api.paged("/api/v1/exercises/equipment")
    }
    by_en = {
        norm_en(item["name_en"]): item for item in exercises if item.get("name_en")
    }
    used_zh = {item["name"] for item in exercises}
    used_en_raw = {item["name_en"] for item in exercises if item.get("name_en")}
    used_en = {norm_en(name) for name in used_en_raw}
    imported_ids = set()
    for item in exercises:
        found = re.findall(r"exercises-dataset #(\d+)", item.get("instructions") or "")
        imported_ids.update(found)
    planned_en: set[str] = set()

    creates: list[dict] = []
    fills: list[tuple[dict, Path]] = []
    skipped = 0
    latin_left = 0

    for record in records:
        if record["id"] in imported_ids:
            skipped += 1
            continue
        gif = args.dataset / record["gif_url"]
        key = norm_en(record["name"])
        existing = by_en.get(key)
        if existing:
            if existing.get("image_key") or existing.get("image_url"):
                skipped += 1
            else:
                fills.append((existing, gif))
            continue

        zh = chinese_name(record)
        if re.search(r"[A-Za-z]{3,}", zh):
            latin_left += 1
        name_en = record["name"]
        if len(name_en) > 100:
            name_en = name_en[:100]
        zh = unique_name(zh, used_zh, record["id"])
        name_en_key = norm_en(name_en)
        if (
            name_en in used_en_raw
            or name_en_key in used_en
            or name_en_key in planned_en
        ):
            name_en = unique_name(name_en, used_en_raw, record["id"])
            name_en_key = norm_en(name_en)
        used_zh.add(zh)
        used_en_raw.add(name_en)
        planned_en.add(name_en_key)
        creates.append(
            {
                "record": record,
                "gif": gif,
                "payload": {
                    "name": zh,
                    "name_en": name_en[:100],
                    "exercise_type": exercise_type(record["name"], record["target"]),
                    "primary": TARGET_MUSCLE[record["target"]],
                    "equipment": EQUIPMENT_ZH[record["equipment"]],
                    "secondary": [
                        SECONDARY_MUSCLE[name]
                        for name in record.get("secondary_muscles") or []
                        if name in SECONDARY_MUSCLE
                    ],
                    "instructions": chinese_steps(record),
                },
            }
        )

    print(
        f"新建 {len(creates)}  补图 {len(fills)}  "
        f"跳过 {skipped}  中文名仍含英文 {latin_left}"
    )
    for job in creates[:12]:
        payload = job["payload"]
        print(
            f"  {job['record']['name']} → {payload['name']} / {payload['exercise_type']} / {payload['primary']}"
        )
    if args.dry_run:
        return 0

    for zh_name, (en_name, category) in NEW_MUSCLES.items():
        if zh_name not in muscles and any(
            job["payload"]["primary"] == zh_name for job in creates
        ):
            created = api.post_json(
                "/api/v1/exercises/muscle-groups",
                {"name": zh_name, "name_en": en_name, "category": category},
            )
            muscles[created["name"]] = created["id"]
            print(f"+ 肌群 {created['name']} #{created['id']}")

    needed_equipment = {job["payload"]["equipment"] for job in creates}
    for zh_name, en_name in NEW_EQUIPMENT_EN.items():
        if zh_name in needed_equipment and zh_name not in equipment:
            created = api.post_json(
                "/api/v1/exercises/equipment",
                {"name": zh_name, "name_en": en_name},
            )
            equipment[created["name"]] = created["id"]
            print(f"+ 器械 {created['name']} #{created['id']}")

    stats = {"created": 0, "filled": 0, "failed": 0}
    errors: list[str] = []

    def create_one(job: dict) -> str:
        payload = job["payload"]
        secondary = []
        for name in payload["secondary"]:
            muscle_id = muscles.get(name)
            if muscle_id and muscle_id not in secondary:
                secondary.append(muscle_id)
        body = {
            "name": payload["name"],
            "name_en": payload["name_en"],
            "exercise_type": payload["exercise_type"],
            "primary_muscle_group_id": muscles[payload["primary"]],
            "equipment_id": equipment[payload["equipment"]],
            "instructions": payload["instructions"],
            "is_custom": False,
            "secondary_muscle_ids": [
                mid for mid in secondary if mid != muscles[payload["primary"]]
            ],
        }
        created = api.create_exercise(body, job["gif"])
        return f"#{created['id']} {created['name']}"

    def fill_one(item: tuple[dict, Path]) -> str:
        exercise, gif = item
        api.upload_image(exercise["id"], gif)
        return f"#{exercise['id']} {exercise['name']}"

    jobs = [("create", job) for job in creates] + [("fill", item) for item in fills]
    done = 0
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        futures = {
            (
                pool.submit(create_one, job)
                if kind == "create"
                else pool.submit(fill_one, job)
            ): kind
            for kind, job in jobs
        }
        for future in as_completed(futures):
            kind = futures[future]
            done += 1
            try:
                future.result()
                stats["created" if kind == "create" else "filled"] += 1
            except Exception as exc:  # noqa: BLE001
                stats["failed"] += 1
                errors.append(str(exc))
                print(f"ERROR {exc}", file=sys.stderr)
            if done % 50 == 0 or done == len(jobs):
                print(
                    f"进度 {done}/{len(jobs)}  新建 {stats['created']}  补图 {stats['filled']}  失败 {stats['failed']}"
                )

    if errors:
        Path("/tmp/exercise-import-errors.txt").write_text(
            "\n".join(errors), encoding="utf-8"
        )
    print(
        f"完成: 新建 {stats['created']}, 补图 {stats['filled']}, 失败 {stats['failed']}"
    )
    return 1 if stats["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
