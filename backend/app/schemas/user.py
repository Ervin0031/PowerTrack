"""userrelated Pydantic Schemas - Complete JWT Auth"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field, ConfigDict, model_validator

# ========== base Schema ==========


class UserBase(BaseModel):
    """userbase Schema"""

    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr


class UserCreate(UserBase):
    """userCreate Schema"""

    password: str = Field(..., min_length=6, max_length=100)

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "username": "johndoe",
                "email": "john@example.com",
                "password": "strongpassword123",
            }
        }
    )


class UserUpdate(BaseModel):
    """userupdate Schema"""

    username: Optional[str] = Field(None, min_length=3, max_length=50)
    email: Optional[EmailStr] = None
    password: Optional[str] = Field(None, min_length=6, max_length=100)
    is_active: Optional[bool] = None


class UserResponse(UserBase):
    """userresponse Schema"""

    id: int
    is_active: bool
    is_verified: bool
    is_superuser: bool
    created_at: datetime
    updated_at: datetime
    last_login_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


# ========== authenticationrelated Schema ==========


class UserLogin(BaseModel):
    """User login Schema"""

    username: Optional[str] = Field(
        None, description="Generate user schemas (app/schemas/user.py)"
    )
    email: Optional[EmailStr] = Field(
        None, description="Generate user schemas (app/schemas/user.py)"
    )
    password: str = Field(..., min_length=6)

    @model_validator(mode="after")
    def check_username_or_email(self):
        """Validate that at least username or email is provided"""
        if not self.username and not self.email:
            raise ValueError("Must provide username or email")
        return self

    model_config = ConfigDict(
        json_schema_extra={
            "example": {"email": "user@example.com", "password": "strongpassword123"}
        }
    )


class Token(BaseModel):
    """tokenresponse Schema"""

    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "token_type": "bearer",
            }
        }
    )


class TokenData(BaseModel):
    """tokendata Schema"""

    username: Optional[str] = None
    user_id: Optional[int] = None


class RefreshTokenRequest(BaseModel):
    """refreshtokenrequest Schema"""

    refresh_token: str = Field(
        ..., description="Generate user schemas (app/schemas/user.py)"
    )


# ========== EmailValidaterelated Schema ==========


class EmailVerificationRequest(BaseModel):
    """EmailValidaterequest Schema"""

    email: EmailStr
    code: str = Field(..., min_length=4, max_length=10)

    model_config = ConfigDict(
        json_schema_extra={"example": {"email": "john@example.com", "code": "123456"}}
    )


class ResendVerificationRequest(BaseModel):
    """Resend verification code request Schema"""

    email: EmailStr


# ========== Passwordresetrelated Schema ==========


class PasswordResetRequest(BaseModel):
    """Passwordresetrequest Schema"""

    email: EmailStr

    model_config = ConfigDict(
        json_schema_extra={"example": {"email": "john@example.com"}}
    )


class PasswordResetConfirm(BaseModel):
    """Passwordresetconfirm Schema"""

    email: EmailStr
    code: str = Field(..., min_length=4, max_length=10)
    new_password: str = Field(..., min_length=6, max_length=100)

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "john@example.com",
                "code": "123456",
                "new_password": "newstrongpassword123",
            }
        }
    )


class PasswordChange(BaseModel):
    """Passwordmodify Schema"""

    old_password: str = Field(..., min_length=6)
    new_password: str = Field(..., min_length=6, max_length=100)

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "old_password": "oldpassword123",
                "new_password": "newstrongpassword123",
            }
        }
    )


# ========== 社交（公开用户 / 关注）Schema ==========


class UserPublicResponse(BaseModel):
    """公开用户信息（不含邮箱等隐私字段）"""

    id: int
    username: str
    is_following: bool = Field(default=False, description="当前登录用户是否已关注 TA")


class UserListResponse(BaseModel):
    items: list[UserPublicResponse] = Field(default_factory=list)
    total: int = 0


class FollowStateResponse(BaseModel):
    """关注操作后的状态"""

    user_id: int
    following: bool
    followers_count: int = 0
