"""Create a superuser account.

Usage:
    cd backend
    ADMIN_PASSWORD='your-strong-password' uv run python scripts/create_admin.py

Environment variables:
    ADMIN_USERNAME  default: root
    ADMIN_EMAIL     default: root@powertrack.local
    ADMIN_PASSWORD  required, no default
"""

import asyncio
import os
import sys
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlmodel import select
from app.models.user import User
from app.core.security import get_password_hash
from app.core.config.settings import settings

ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "root")
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "root@powertrack.local")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "")


async def main() -> int:
    if not ADMIN_PASSWORD:
        print(
            "ADMIN_PASSWORD is required. Set it via environment variable.",
            file=sys.stderr,
        )
        return 1

    engine = create_async_engine(settings.database.DATABASE_URL, echo=False)
    session_factory = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    async with session_factory() as db:
        # Check if admin already exists
        result = await db.execute(select(User).where(User.username == ADMIN_USERNAME))
        existing = result.scalar_one_or_none()

        if existing:
            print(
                f"Admin user '{ADMIN_USERNAME}' already exists (id={existing.id}), skipping."
            )
            return 0

        admin = User(
            username=ADMIN_USERNAME,
            email=ADMIN_EMAIL,
            hashed_password=get_password_hash(ADMIN_PASSWORD),
            is_superuser=True,
            is_verified=True,
            is_active=True,
        )
        db.add(admin)
        await db.commit()
        await db.refresh(admin)
        print(
            f"Admin user created: id={admin.id}, username={admin.username}, superuser=True"
        )

    await engine.dispose()
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
