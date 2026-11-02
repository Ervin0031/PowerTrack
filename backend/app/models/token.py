"""Token andVerification code modeldefinition"""

from datetime import datetime, timezone
from typing import Optional

from pydantic import NaiveDatetime
from sqlmodel import Field, SQLModel
from sqlmodel.main import SQLModelConfig


def _now_naive() -> datetime:
    """Timezone-naive UTC now, for PostgreSQL TIMESTAMP WITHOUT TIME ZONE compat."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class RefreshToken(SQLModel, table=True):
    """Refresh token model

    Used to manage user refresh tokens, supports:
    - Multi-device login (one token per device)
    - Token revocation
    - Token expiration management
    """

    __tablename__ = "refresh_tokens"

    id: Optional[int] = Field(default=None, primary_key=True)

    # Associated user
    user_id: int = Field(foreign_key="users.id", index=True)

    # Token information
    token: str = Field(unique=True, index=True, max_length=500)
    expires_at: NaiveDatetime = Field(index=True)

    # Device information (optional)
    device_name: Optional[str] = Field(default=None, max_length=100)
    device_type: Optional[str] = Field(
        default=None, max_length=50
    )  # web, mobile, desktop
    ip_address: Optional[str] = Field(
        default=None, max_length=45
    )  # IPv6 max length 45 characters
    user_agent: Optional[str] = Field(default=None, max_length=500)

    # Status
    is_revoked: bool = Field(default=False, index=True)
    revoked_at: Optional[NaiveDatetime] = Field(default=None)

    # Timestamps
    created_at: NaiveDatetime = Field(default_factory=_now_naive)
    last_used_at: Optional[NaiveDatetime] = Field(default=None)

    model_config = SQLModelConfig(
        json_schema_extra={
            "example": {
                "user_id": 1,
                "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "device_name": "iPhone 13",
                "device_type": "mobile",
                "is_revoked": False,
            }
        }
    )

    def is_valid(self) -> bool:
        """Check if token is valid"""
        if self.is_revoked:
            return False
        return _now_naive() < self.expires_at

    def revoke(self) -> None:
        """Revoke token"""
        self.is_revoked = True
        self.revoked_at = _now_naive()


class VerificationCode(SQLModel, table=True):
    """Verification code model

    Used to manage email verification codes and password reset codes, supports:
    - Verification code expiration management
    - Verification code usage limit
    - Verification code type distinction
    """

    __tablename__ = "verification_codes"

    id: Optional[int] = Field(default=None, primary_key=True)

    # Associated user
    user_id: int = Field(foreign_key="users.id", index=True)

    # Verification code information
    code: str = Field(max_length=10, index=True)
    code_type: str = Field(
        max_length=20, index=True
    )  # email_verification, password_reset
    expires_at: NaiveDatetime = Field(index=True)

    # Usage status
    is_used: bool = Field(default=False, index=True)
    used_at: Optional[NaiveDatetime] = Field(default=None)
    attempts: int = Field(default=0)  # Attempt count
    max_attempts: int = Field(default=5)  # Maximum attempts

    # Timestamps
    created_at: NaiveDatetime = Field(default_factory=_now_naive)

    model_config = SQLModelConfig(
        json_schema_extra={
            "example": {
                "user_id": 1,
                "code": "123456",
                "code_type": "email_verification",
                "is_used": False,
                "attempts": 0,
            }
        }
    )

    def is_valid(self) -> bool:
        """Check if verification code is valid"""
        if self.is_used:
            return False
        if self.attempts >= self.max_attempts:
            return False
        return _now_naive() < self.expires_at

    def increment_attempts(self) -> None:
        """Increment attempt count"""
        self.attempts += 1

    def mark_as_used(self) -> None:
        """Mark as used"""
        self.is_used = True
        self.used_at = _now_naive()
