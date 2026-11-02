#!/usr/bin/env python3
"""为存量动作图片回填列表缩略图(生成 512px JPEG 上传 RustFS,写回 thumb_key)。

只处理 image_key 非空且 thumb_key 为空的记录,可重复执行。
需在能访问数据库与 RustFS 的环境运行(如部署服务器)。

用法:
    cd backend
    uv run python scripts/backfill_exercise_thumbnails.py [--dry-run] [--limit 10]
"""

from __future__ import annotations

import argparse
import asyncio
import sys

import httpx
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlmodel import select

from app.core.config.settings import settings
from app.models.exercise import Exercise
from app.services.storage import storage_service


async def main() -> int:
    parser = argparse.ArgumentParser(description="回填动作图片缩略图")
    parser.add_argument(
        "--dry-run", action="store_true", help="只列出待处理记录,不生成/上传"
    )
    parser.add_argument("--limit", type=int, default=0, help="最多处理条数,0 表示全部")
    args = parser.parse_args()

    engine = create_async_engine(settings.database.DATABASE_URL, echo=False)
    session_factory = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    async with session_factory() as db:
        stmt = (
            select(Exercise)
            .where(Exercise.image_key.is_not(None), Exercise.thumb_key.is_(None))
            .order_by(Exercise.id)
        )
        if args.limit:
            stmt = stmt.limit(args.limit)
        rows = list((await db.execute(stmt)).scalars().all())

        print(f"待回填: {len(rows)} 条")
        if args.dry_run:
            for ex in rows:
                print(f"  #{ex.id} {ex.name}  {ex.image_key}")
            await engine.dispose()
            return 0

        stats = {"ok": 0, "failed": 0}
        with httpx.Client(timeout=120.0) as client:
            for ex in rows:
                try:
                    resp = client.get(storage_service.presigned_url(ex.image_key))
                    resp.raise_for_status()
                    ex.thumb_key = storage_service.create_thumbnail(resp.content)
                    db.add(ex)
                    await db.commit()
                    stats["ok"] += 1
                    print(f"OK    #{ex.id} {ex.name} → {ex.thumb_key}")
                except Exception as exc:  # noqa: BLE001
                    await db.rollback()
                    stats["failed"] += 1
                    print(f"FAIL  #{ex.id} {ex.name}: {exc}", file=sys.stderr)

    await engine.dispose()
    print(f"完成: 成功 {stats['ok']}, 失败 {stats['failed']}")
    return 1 if stats["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
