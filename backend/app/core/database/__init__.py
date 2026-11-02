"""Database module"""

from .connection import db_manager
from .postgresql import postgresql_manager, Base


async def get_db():
    """Get database session (async)"""
    async for session in postgresql_manager.get_db():
        yield session


__all__ = ["db_manager", "postgresql_manager", "Base", "get_db"]
