#!/usr/bin/env python3
"""批量把本地训练图片上传到动作库。

按文件名匹配已有动作；匹配不到则自动创建动作后再上传图片。

用法：
    cd backend
    ADMIN_USER=root ADMIN_PASS='...' \\
        uv run python scripts/upload_exercise_images.py --dir /path/to/images

    # 只预览匹配结果，不实际上传
    uv run python scripts/upload_exercise_images.py --dir /path/to/images --dry-run

    # 已有图片也强制覆盖
    uv run python scripts/upload_exercise_images.py --dir /path/to/images --force

环境变量：
    BASE_URL   默认 http://localhost:8000
    ADMIN_USER 必填（或使用 --user）
    ADMIN_PASS 必填（或使用 --password）
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import re
import sys
from pathlib import Path

import httpx

DEFAULT_BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")
DEFAULT_USER = os.getenv("ADMIN_USER", "")
DEFAULT_PASS = os.getenv("ADMIN_PASS", "")
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}

# 图片文件名（不含扩展名）→ 服务器上优先匹配的动作名
# 短名容易歧义，这里写死常见对应关系
NAME_ALIASES: dict[str, str] = {
    "三头下压": "龙门架三头下压",
    "上斜卧推": "上斜杠铃卧推",
    "保加利亚蹲": "保加利亚分腿蹲",
    "俯身划船": "杠铃划船",
    "卧推": "杠铃卧推",
    "卧推2": "杠铃卧推",
    "哑铃推肩": "哑铃推举",
    "器械坐姿划船": "坐姿划船",
    "推举": "杠铃过头推举",
    "深蹲": "杠铃深蹲",
    "硬拉": "杠铃硬拉",
    "窄距卧推": "窄距杠铃卧推",
    "绳索划船": "龙门架划船",
    "绳索夹胸": "龙门架飞鸟",
    "耸肩": "杠铃耸肩",
    "腿举机": "腿举机腿举",
    "面拉": "龙门架面拉",
}

# 创建缺失动作时用的元数据（按中文名解析肌群/器械）
# primary / secondary 填肌群中文名；equipment 填器械中文名
CREATE_META: dict[str, dict] = {
    "前蹲": {
        "name_en": "Front Squat",
        "exercise_type": "compound",
        "primary": "股四头肌",
        "secondary": ["臀部", "核心整体"],
        "equipment": "杠铃",
    },
    "罗马尼亚硬拉": {
        "name_en": "Romanian Deadlift",
        "exercise_type": "compound",
        "primary": "腘绳肌",
        "secondary": ["臀部", "下背部"],
        "equipment": "杠铃",
    },
    "推胸机": {
        "name_en": "Chest Press Machine",
        "exercise_type": "compound",
        "primary": "胸部",
        "secondary": ["肱三头肌", "三角肌前束"],
        "equipment": "推胸机",
        "create_equipment": ("推胸机", "Chest Press Machine"),
    },
    "肩推机": {
        "name_en": "Shoulder Press Machine",
        "exercise_type": "compound",
        "primary": "肩部",
        "secondary": ["肱三头肌"],
        "equipment": "肩推机",
        "create_equipment": ("肩推机", "Shoulder Press Machine"),
    },
    "蝴蝶机夹胸": {
        "name_en": "Pec Deck Fly",
        "exercise_type": "isolation",
        "primary": "胸部",
        "secondary": [],
        "equipment": "蝴蝶机",
        "create_equipment": ("蝴蝶机", "Pec Deck Machine"),
    },
    "臀腿": {
        "name_en": "Glute Ham Raise",
        "exercise_type": "compound",
        "primary": "臀部",
        "secondary": ["腘绳肌"],
        "equipment": "罗马椅",
    },
}


class ApiClient:
    def __init__(self, base_url: str, username: str, password: str) -> None:
        self.base = base_url.rstrip("/")
        self.client = httpx.Client(timeout=120.0)
        self.token = self._login(username, password)
        self.client.headers["Authorization"] = f"Bearer {self.token}"

    def _login(self, username: str, password: str) -> str:
        r = self.client.post(
            f"{self.base}/api/v1/auth/login",
            json={"username": username, "password": password},
        )
        r.raise_for_status()
        data = r.json()
        token = data.get("access_token")
        if not token:
            raise RuntimeError(f"登录失败: {data}")
        return token

    def _paged(self, path: str) -> list[dict]:
        items: list[dict] = []
        skip = 0
        while True:
            r = self.client.get(
                f"{self.base}{path}", params={"skip": skip, "limit": 100}
            )
            r.raise_for_status()
            data = r.json()
            batch = data["items"]
            items.extend(batch)
            if skip + len(batch) >= data["total"]:
                break
            skip += 100
        return items

    def list_exercises(self) -> list[dict]:
        return self._paged("/api/v1/exercises")

    def list_muscle_groups(self) -> list[dict]:
        return self._paged("/api/v1/exercises/muscle-groups")

    def list_equipment(self) -> list[dict]:
        return self._paged("/api/v1/exercises/equipment")

    def create_equipment(self, name: str, name_en: str) -> dict:
        r = self.client.post(
            f"{self.base}/api/v1/exercises/equipment",
            json={"name": name, "name_en": name_en},
        )
        r.raise_for_status()
        return r.json()

    def create_exercise(self, payload: dict, image_path: Path) -> dict:
        mime = mimetypes.guess_type(image_path.name)[0] or "image/jpeg"
        with image_path.open("rb") as f:
            r = self.client.post(
                f"{self.base}/api/v1/exercises",
                data={"data": json.dumps(payload, ensure_ascii=False)},
                files={"image": (image_path.name, f, mime)},
            )
        if r.status_code >= 400:
            raise RuntimeError(f"创建失败 {r.status_code}: {r.text}")
        return r.json()

    def update_exercise_image(self, ex_id: int, image_path: Path) -> dict:
        mime = mimetypes.guess_type(image_path.name)[0] or "image/jpeg"
        with image_path.open("rb") as f:
            r = self.client.put(
                f"{self.base}/api/v1/exercises/{ex_id}",
                data={"data": json.dumps({})},
                files={"image": (image_path.name, f, mime)},
            )
        if r.status_code >= 400:
            raise RuntimeError(f"更新失败 {r.status_code}: {r.text}")
        return r.json()


def normalize_stem(stem: str) -> str:
    """去掉末尾数字后缀，如 卧推2 → 卧推。"""
    return re.sub(r"\d+$", "", stem).strip()


def score_match(stem: str, exercise_name: str) -> int | None:
    """分数越小越好；None 表示不匹配。"""
    if stem == exercise_name:
        return 0
    if exercise_name.endswith(stem):
        return len(exercise_name) - len(stem)
    if stem in exercise_name:
        return 100 + len(exercise_name) - len(stem)
    return None


def find_exercise(stem: str, exercises: list[dict]) -> dict | None:
    """按优先级匹配：别名 → 精确名 →（非 CREATE_META 时）模糊包含。"""
    alias = NAME_ALIASES.get(stem) or NAME_ALIASES.get(normalize_stem(stem))
    if alias:
        for ex in exercises:
            if ex["name"] == alias:
                return ex

    for candidate in (stem, normalize_stem(stem)):
        for ex in exercises:
            if ex["name"] == candidate:
                return ex

    # CREATE_META 里写死要新建的动作，不要被「哑铃罗马尼亚硬拉」这类包含匹配抢走
    if stem in CREATE_META or normalize_stem(stem) in CREATE_META:
        return None

    best: tuple[int, dict] | None = None
    for ex in exercises:
        s = score_match(stem, ex["name"])
        if s is None:
            s = score_match(normalize_stem(stem), ex["name"])
        if s is None:
            continue
        if best is None or s < best[0]:
            best = (s, ex)
    return best[1] if best else None


def resolve_ids(
    meta: dict,
    muscles: dict[str, int],
    equipment: dict[str, int],
) -> dict:
    primary = meta["primary"]
    if primary not in muscles:
        raise KeyError(f"找不到肌群: {primary}")
    eq_name = meta.get("equipment")
    eq_id = equipment.get(eq_name) if eq_name else None
    if eq_name and eq_id is None:
        raise KeyError(f"找不到器械: {eq_name}")
    secondary = []
    for name in meta.get("secondary", []):
        if name not in muscles:
            raise KeyError(f"找不到辅助肌群: {name}")
        secondary.append(muscles[name])
    return {
        "name": meta.get("name") or meta["create_name"],
        "name_en": meta.get("name_en"),
        "exercise_type": meta.get("exercise_type", "compound"),
        "primary_muscle_group_id": muscles[primary],
        "equipment_id": eq_id,
        "secondary_muscle_ids": secondary,
        "is_custom": False,
    }


def ensure_create_meta(stem: str) -> dict:
    if stem in CREATE_META:
        meta = dict(CREATE_META[stem])
        meta["create_name"] = stem
        meta["name"] = stem
        return meta
    # 兜底：未知动作也创建，默认归到「核心整体 / 自重」
    return {
        "create_name": stem,
        "name": stem,
        "name_en": stem,
        "exercise_type": "compound",
        "primary": "核心整体",
        "secondary": [],
        "equipment": "自重",
    }


def collect_images(directory: Path) -> list[Path]:
    files = [
        p
        for p in sorted(directory.iterdir())
        if p.is_file() and p.suffix.lower() in IMAGE_EXTS and not p.name.startswith(".")
    ]
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description="批量上传训练动作示范图片")
    parser.add_argument("--dir", required=True, help="本地图片目录")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--user", default=DEFAULT_USER)
    parser.add_argument("--password", default=DEFAULT_PASS)
    parser.add_argument("--dry-run", action="store_true", help="只打印匹配结果")
    parser.add_argument("--force", action="store_true", help="覆盖已有图片")
    parser.add_argument(
        "--skip-existing", action="store_true", default=True, help=argparse.SUPPRESS
    )
    args = parser.parse_args()

    if not args.user or not args.password:
        print(
            "缺少管理员账号：请用 --user/--password 或 ADMIN_USER/ADMIN_PASS 提供",
            file=sys.stderr,
        )
        return 1

    image_dir = Path(args.dir).expanduser()
    if not image_dir.is_dir():
        print(f"目录不存在: {image_dir}", file=sys.stderr)
        return 1

    images = collect_images(image_dir)
    if not images:
        print(f"目录里没有图片: {image_dir}")
        return 1

    print(f"服务器: {args.base_url}")
    print(f"图片数: {len(images)}")
    print(
        f"模式: {'dry-run' if args.dry_run else 'upload'}{' + force' if args.force else ''}"
    )
    print("-" * 60)

    api = ApiClient(args.base_url, args.user, args.password)
    exercises = api.list_exercises()
    muscles = {m["name"]: m["id"] for m in api.list_muscle_groups()}
    equipment = {e["name"]: e["id"] for e in api.list_equipment()}

    stats = {"updated": 0, "created": 0, "skipped": 0, "failed": 0}

    for path in images:
        stem = path.stem
        size_mb = path.stat().st_size / (1024 * 1024)
        matched = find_exercise(stem, exercises)

        if matched:
            has_img = bool(matched.get("image_url") or matched.get("image_key"))
            if has_img and not args.force:
                print(
                    f"SKIP  {stem:12} → #{matched['id']} {matched['name']} (已有图片)"
                )
                stats["skipped"] += 1
                continue
            action = "UPDATE" if has_img else "UPLOAD"
            print(
                f"{action:6} {stem:12} → #{matched['id']} {matched['name']} ({size_mb:.1f}MB)"
            )
            if args.dry_run:
                continue
            try:
                api.update_exercise_image(matched["id"], path)
                # 刷新本地缓存里的图片标记，避免同名第二张图重复上传
                matched["image_url"] = "uploaded"
                stats["updated"] += 1
            except Exception as exc:  # noqa: BLE001
                print(f"  ERROR: {exc}", file=sys.stderr)
                stats["failed"] += 1
            continue

        # 没有匹配 → 创建
        meta = ensure_create_meta(stem)
        print(f"CREATE {stem:12} → 新建「{meta['name']}」 ({size_mb:.1f}MB)")
        if args.dry_run:
            continue
        try:
            create_eq = meta.get("create_equipment")
            if create_eq and create_eq[0] not in equipment:
                eq = api.create_equipment(create_eq[0], create_eq[1])
                equipment[eq["name"]] = eq["id"]
                print(f"  + equipment #{eq['id']} {eq['name']}")
            payload = resolve_ids(meta, muscles, equipment)
            created = api.create_exercise(payload, path)
            exercises.append(created)
            print(f"  + exercise #{created['id']} {created['name']}")
            stats["created"] += 1
        except Exception as exc:  # noqa: BLE001
            print(f"  ERROR: {exc}", file=sys.stderr)
            stats["failed"] += 1

    print("-" * 60)
    print(
        f"完成: 上传/更新 {stats['updated']}, "
        f"新建 {stats['created']}, "
        f"跳过 {stats['skipped']}, "
        f"失败 {stats['failed']}"
    )
    return 1 if stats["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
