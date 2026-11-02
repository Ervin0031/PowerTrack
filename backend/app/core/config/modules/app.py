"""applicationconfigurationmodule"""

from pydantic import Field
from app.core.config.base import EnvBaseSettings


class AppSettings(EnvBaseSettings):
    """Application metadata configuration"""

    APP_NAME: str = Field(default="backend", description="Application name")
    APP_DESCRIPTION: str = Field(
        default="backend is a FastAPI application.",
        description="Application description",
    )
    APP_VERSION: str = Field(default="0.1.0", description="Application version")
