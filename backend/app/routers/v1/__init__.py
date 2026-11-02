"""API v1 router module — aggregates all v1 routers"""

from .auth import router as auth_router
from .coach import router as coach_router
from .equipment import router as equipment_router
from .exercises import router as exercise_router
from .feed import feed_router, share_router
from .muscle_groups import router as muscle_group_router
from .programs import router as program_router
from .templates import router as template_router
from .users import router as user_router
from .workouts import performance_router, session_router

__all__ = [
    "auth_router",
    "coach_router",
    "equipment_router",
    "exercise_router",
    "feed_router",
    "muscle_group_router",
    "performance_router",
    "program_router",
    "session_router",
    "share_router",
    "template_router",
    "user_router",
]
