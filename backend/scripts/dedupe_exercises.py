#!/usr/bin/env python3
"""删掉名称相同、且没有动作图片的重复动作。

同一中文名（忽略空白，以及末尾的数据集编号）只留一条：优先留有 image_key / thumb_key 的，
其次留训练记录更多的。没有图片的重复项会把训练组、模板和 1RM 改挂到保留的那条，
再删除。有图片的重复项不动。单独一条、即使没有图片，也不删。

用法：
    cd backend
    uv run python scripts/dedupe_exercises.py
    uv run python scripts/dedupe_exercises.py --apply
"""

from __future__ import annotations

import argparse
import asyncio
import re
import sys
from collections import defaultdict

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config.settings import settings

_IDENT = re.compile(r"^[a-z_][a-z0-9_]*$")


def norm_name(name: str) -> str:
    """同一动作：去掉空白和括号，再去掉导入时加在末尾的数据集编号。"""
    text = re.sub(r"[\s·\-_()（）]+", "", name.casefold())
    return re.sub(r"\d+$", "", text)


def _check_ident(name: str) -> str:
    if not _IDENT.fullmatch(name):
        raise RuntimeError(f"unexpected sql name: {name}")
    return name


async def _foreign_keys(db: AsyncSession) -> list[tuple[str, str]]:
    rows = (
        await db.execute(
            text(
                """
                SELECT tc.table_name, kcu.column_name
                FROM information_schema.table_constraints AS tc
                JOIN information_schema.key_column_usage AS kcu
                  ON tc.constraint_name = kcu.constraint_name
                 AND tc.table_schema = kcu.table_schema
                JOIN information_schema.constraint_column_usage AS ccu
                  ON ccu.constraint_name = tc.constraint_name
                 AND ccu.table_schema = tc.table_schema
                WHERE tc.constraint_type = 'FOREIGN KEY'
                  AND tc.table_schema = 'public'
                  AND ccu.table_name = 'exercises'
                  AND ccu.column_name = 'id'
                ORDER BY tc.table_name, kcu.column_name
                """
            )
        )
    ).all()
    return [(_check_ident(table), _check_ident(column)) for table, column in rows]


async def _primary_key(db: AsyncSession, table: str) -> list[str]:
    rows = (
        await db.execute(
            text(
                """
                SELECT kcu.column_name
                FROM information_schema.table_constraints AS tc
                JOIN information_schema.key_column_usage AS kcu
                  ON tc.constraint_name = kcu.constraint_name
                 AND tc.table_schema = kcu.table_schema
                WHERE tc.table_schema = 'public'
                  AND tc.table_name = :table
                  AND tc.constraint_type = 'PRIMARY KEY'
                ORDER BY kcu.ordinal_position
                """
            ),
            {"table": table},
        )
    ).all()
    return [_check_ident(row[0]) for row in rows]


async def _repoint(
    db: AsyncSession, table: str, column: str, drop_id: int, keep_id: int
) -> None:
    pk = await _primary_key(db, table)
    params = {"drop": drop_id, "keep": keep_id}
    if column in pk and len(pk) > 1:
        others = [name for name in pk if name != column]
        match = " AND ".join(f"d.{name} = k.{name}" for name in others)
        await db.execute(
            text(
                f"""
                DELETE FROM {table} AS d
                USING {table} AS k
                WHERE d.{column} = :drop
                  AND k.{column} = :keep
                  AND {match}
                """
            ),
            params,
        )
    await db.execute(
        text(f"UPDATE {table} SET {column} = :keep WHERE {column} = :drop"),
        params,
    )


async def _drop_template_slots(db: AsyncSession, drop_id: int, keep_id: int) -> None:
    await db.execute(
        text(
            """
            DELETE FROM workout_template_sets
            WHERE template_exercise_id IN (
                SELECT d.id
                FROM workout_template_exercises AS d
                JOIN workout_template_exercises AS k
                  ON k.template_id = d.template_id
                 AND k.exercise_id = :keep
                WHERE d.exercise_id = :drop
            )
            """
        ),
        {"drop": drop_id, "keep": keep_id},
    )
    await db.execute(
        text(
            """
            DELETE FROM workout_template_exercises AS d
            USING workout_template_exercises AS k
            WHERE d.exercise_id = :drop
              AND k.template_id = d.template_id
              AND k.exercise_id = :keep
            """
        ),
        {"drop": drop_id, "keep": keep_id},
    )


async def main() -> int:
    parser = argparse.ArgumentParser(description="删除没有图片的同名重复动作")
    parser.add_argument("--apply", action="store_true", help="真正写入。默认只打印")
    parser.add_argument("--database-url", default="", help="覆盖 DATABASE_URL")
    args = parser.parse_args()

    url = args.database_url or settings.database.DATABASE_URL
    engine = create_async_engine(
        url,
        echo=False,
        connect_args={"timeout": 10, "ssl": False},
    )
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    deleted = 0
    try:
        async with factory() as db:
            exercises = (
                await db.execute(
                    text(
                        """
                        SELECT id, name, image_key, thumb_key
                        FROM exercises
                        ORDER BY id
                        """
                    )
                )
            ).all()
            refs = {
                row[0]: row[1]
                for row in (
                    await db.execute(
                        text(
                            """
                            SELECT exercise_id, COUNT(*)
                            FROM workout_sets
                            GROUP BY exercise_id
                            """
                        )
                    )
                ).all()
            }
            by_name: dict[str, list] = defaultdict(list)
            for row in exercises:
                key = norm_name(row.name or "")
                if key:
                    by_name[key].append(row)

            keys = await _foreign_keys(db)
            plan: list[tuple] = []
            for key, group in sorted(by_name.items()):
                if len(group) < 2:
                    continue

                def rank(row, refs=refs):
                    imaged = 1 if (row.image_key or row.thumb_key) else 0
                    return (imaged, refs.get(row.id, 0), -row.id)

                keeper = max(group, key=rank)
                drops = [
                    row
                    for row in group
                    if row.id != keeper.id and not (row.image_key or row.thumb_key)
                ]
                for row in drops:
                    plan.append((row, keeper, key))

            print(f"同名组 {sum(1 for g in by_name.values() if len(g) > 1)} 个，待删无图重复 {len(plan)} 条")
            shown = plan[:40]
            for row, keeper, key in shown:
                print(
                    f"  删 #{row.id} {row.name}（记录 {refs.get(row.id, 0)}）"
                    f" → 留 #{keeper.id} {keeper.name}"
                    f"{' 有图' if keeper.image_key or keeper.thumb_key else ' 无图'}"
                )
            if len(plan) > len(shown):
                print(f"  … 另有 {len(plan) - len(shown)} 条")
            if not args.apply:
                print("未写入。确认后加 --apply")
                return 0
            for row, keeper, _key in plan:
                await _drop_template_slots(db, row.id, keeper.id)
                for table, column in keys:
                    await _repoint(db, table, column, row.id, keeper.id)
                await db.execute(
                    text("DELETE FROM exercises WHERE id = :id"),
                    {"id": row.id},
                )
                deleted += 1
            await db.commit()
    finally:
        await engine.dispose()
    print(f"已删除 {deleted} 条")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
