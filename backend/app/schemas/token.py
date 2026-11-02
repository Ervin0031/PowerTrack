"""Token related Pydantic Schemas - Complete JWT Auth"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict

# ========== Refresh Token Schemas ==========


class RefreshTokenBase(BaseModel):
    """refreshtokenbase Schema"""

    device_name: Optional[str] = Field(None, max_length=200)
    device_type: Optional[str] = Field(None, max_length=50)


class RefreshTokenCreate(RefreshTokenBase):
    """refreshtokenCreate Schema"""

    user_id: int
    token: str
    expires_at: datetime
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None


class RefreshTokenResponse(RefreshTokenBase):
    """refreshtokenresponse Schema"""

    id: int
    user_id: int
    expires_at: datetime
    is_revoked: bool
    created_at: datetime
    last_used_at: Optional[datetime] = None
    ip_address: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class RefreshTokenRequest(BaseModel):
    """refreshtokenrequest Schema"""

    refresh_token: str = Field(
        ..., description="Generate token schemas (app/schemas/token.py)"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {"refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}
        }
    )


class RefreshTokenRevoke(BaseModel):
    """Revoke refresh token Schema"""

    token: Optional[str] = Field(
        None, description="Generate token schemas (app/schemas/token.py)"
    )


# ========== Verification Code Schemas ==========


class VerificationCodeBase(BaseModel):
    """Verification code base Schema"""

    code_type: str = Field(
        ..., description="Generate token schemas (app/schemas/token.py)"
    )


class VerificationCodeCreate(VerificationCodeBase):
    """Verification code create Schema"""

    user_id: int
    code: str
    expires_at: datetime
    max_attempts: int = 5


class VerificationCodeResponse(VerificationCodeBase):
    """Verification code response Schema"""

    id: int
    user_id: int
    expires_at: datetime
    is_used: bool
    attempts: int
    max_attempts: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class VerificationCodeVerify(BaseModel):
    """Verification code verify Schema"""

    code: str = Field(..., min_length=4, max_length=10)
    code_type: str = Field(
        ..., description="Generate token schemas (app/schemas/token.py)"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {"code": "123456", "code_type": "email_verification"}
        }
    )
