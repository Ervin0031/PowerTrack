"""usermodeldefinition"""

from datetime import datetime, timezone
from typing import Optional

from pydantic import NaiveDatetime
from sqlmodel import Field, SQLModel
from sqlmodel.main import SQLModelConfig


def _now_naive() -> datetime:
    """Timezone-naive UTC now, for PostgreSQL TIMESTAMP WITHOUT TIME ZONE compat."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class User(SQLModel, table=True):
    """usermodel - Complete JWT Auth

    Contains complete authentication features:
    - EmailValidate
    - Passwordreset
    - Multi-device login support (via RefreshToken table)
    """

    __tablename__ = "users"

    # basefield
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(unique=True, index=True, max_length=50)
    email: str = Field(unique=True, index=True, max_length=100)
    hashed_password: str = Field(max_length=255)

    # Statusfield
    is_active: bool = Field(default=True)
    is_superuser: bool = Field(default=False)
    is_verified: bool = Field(
        default=False, description="Generate user model (app/models/user.py)"
    )

    # Timestamps
    created_at: NaiveDatetime = Field(default_factory=_now_naive)
    updated_at: NaiveDatetime = Field(default_factory=_now_naive)
    last_login_at: Optional[NaiveDatetime] = Field(default=None)

    model_config = SQLModelConfig(
        json_schema_extra={
            "example": {
                "username": "johndoe",
                "email": "john@example.com",
                "is_active": True,
                "is_verified": True,
                "is_superuser": False,
            }
        }
    )
