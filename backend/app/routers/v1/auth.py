"""authentication routes - Complete JWT Auth"""

from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.user import (
    UserCreate,
    UserResponse,
    UserLogin,
    Token,
    EmailVerificationRequest,
    ResendVerificationRequest,
    PasswordResetRequest,
    PasswordResetConfirm,
    PasswordChange,
)
from app.schemas.token import RefreshTokenRequest, RefreshTokenResponse
from app.services.auth import auth_service
from app.crud.user import user_crud
from app.crud.token import refresh_token_crud

router = APIRouter(prefix="/auth", tags=["Authentication"])


# ========== registerandlogin ==========


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="用户注册",
    description=(
        "无需认证。注册成功后会发送邮箱验证码，需先验证邮箱才能登录。\n\n"
        "请求格式（JSON Body）：\n"
        "- `username`: string 必填，3-50 字符\n"
        "- `email`: string 必填，邮箱格式\n"
        "- `password`: string 必填，6-100 字符\n\n"
        '```json\n{"username": "johndoe", "email": "john@example.com", '
        '"password": "strongpassword123"}\n```\n\n'
        "返回格式（201）：UserResponse\n"
        '```json\n{"id": 1, "username": "johndoe", "email": '
        '"john@example.com", '
        '"is_active": true, "is_verified": false, "is_superuser": false, '
        '"created_at": "2026-01-01T08:00:00Z", "updated_at": '
        '"2026-01-01T08:00:00Z", "last_login_at": null}\n```\n\n'
        "错误码：400 用户名或邮箱已存在。"
    ),
    response_description="注册成功，返回新建用户信息（is_verified=false）。",
)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    """Register new user

    After registration, an email verification email will be sent. Users need to verify their email before they can login.

    Args:
        user_data: userregisterdata
        db: Database session

    Returns:
        Createuserinformation

    Raises:
        HTTPException: Username or emailalreadyexists
    """
    try:
        user = await auth_service.register_user(db, user_data, send_verification=True)
        return user
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post(
    "/login",
    response_model=Token,
    summary="用户登录",
    description=(
        "无需认证。`email` 与 `username` 二选一即可，优先使用 email；必须已验证邮箱。\n\n"
        "请求格式（JSON Body）：\n"
        "- `email`: string 可选，与 username 二选一\n"
        "- `username`: string 可选，与 email 二选一\n"
        "- `password`: string 必填，≥6 字符\n\n"
        '```json\n{"email": "user@example.com", "password": '
        '"strongpassword123"}\n```\n\n'
        "返回格式（200）：Token\n"
        '```json\n{"access_token": "eyJhbGciOi...", "refresh_token": '
        '"eyJhbGciOi...", "token_type": "bearer"}\n```\n\n'
        "错误码：401 用户名/密码错误或邮箱未验证。"
    ),
    response_description="登录成功，返回访问令牌与刷新令牌。",
)
async def login(
    user_login: UserLogin, request: Request, db: AsyncSession = Depends(get_db)
):
    """User login

    After successful login, return access token and refresh token.
    User must have verified their email to login.

    Args:
        user_login: logincredentials
        request: requestobject
        db: Database session

    Returns:
        accesstokenandrefreshtoken

    Raises:
        HTTPException: authentication failed or email not verified
    """
    # Get device information
    user_agent = request.headers.get("User-Agent", "Unknown")
    ip_address = request.client.host if request.client else None

    # Prefer to use email, otherwise use username
    login_identifier = user_login.email or user_login.username

    token = await auth_service.login_user(
        db,
        login_identifier,
        user_login.password,
        device_name=user_agent[:100] if user_agent else None,
        device_type="web",
        ip_address=ip_address,
        user_agent=user_agent,
    )

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password, or email not verified",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return token


@router.post(
    "/logout",
    summary="登出（撤销单个刷新令牌）",
    description=(
        "无需认证。注销指定设备，需携带该设备的 refresh_token。\n\n"
        "请求格式（JSON Body）：\n"
        "- `refresh_token`: string 必填\n\n"
        '```json\n{"refresh_token": "eyJhbGciOi..."}\n```\n\n'
        '返回格式（200）：\n`{"message": "Successfully logged out"}`\n\n'
        "错误码：400 refresh_token 无效。"
    ),
    response_description="登出成功。",
)
async def logout(
    refresh_token_request: RefreshTokenRequest, db: AsyncSession = Depends(get_db)
):
    """userlogout

    Revoke specified refresh token.

    Args:
        refresh_token_request: refreshtokenrequest
        db: Database session

    Returns:
        successmessage
    """
    success = await auth_service.logout_user(db, refresh_token_request.refresh_token)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid refresh token"
        )

    return {"message": "Successfully logged out"}


@router.post(
    "/logout-all",
    summary="登出所有设备",
    description=(
        "需认证（ access_token）。撤销当前用户全部刷新令牌。\n\n"
        "请求格式：无请求体，请求头携带 `Authorization: Bearer <access_token>`。\n\n"
        '返回格式（200）：\n`{"message": "Successfully logged out from N devices"}`，N '
        "为被撤销的令牌数。"
    ),
    response_description="全部设备登出成功，返回被撤销数量。",
)
async def logout_all(
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    """Logout all devices

    Revoke all refresh tokens for current user.

    Args:
        current_user: currentuser
        db: Database session

    Returns:
        Revoke tokenquantity
    """
    count = await auth_service.logout_all_devices(db, current_user.id)
    return {"message": f"Successfully logged out from {count} devices"}


# ========== tokenrefresh ==========


@router.post(
    "/refresh",
    response_model=dict,
    summary="刷新访问令牌",
    description=(
        "无需认证。用未过期、未撤销的 refresh_token 换取新的 access_token。\n\n"
        "请求格式（JSON Body）：\n"
        "- `refresh_token`: string 必填\n\n"
        '```json\n{"refresh_token": "eyJhbGciOi..."}\n```\n\n'
        '返回格式（200）：\n`{"access_token": "新的JWT", "token_type": "bearer"}`\n\n'
        "错误码：401 refresh_token 无效或已过期。"
    ),
    response_description="刷新成功，返回新的访问令牌。",
)
async def refresh_token(
    refresh_token_request: RefreshTokenRequest, db: AsyncSession = Depends(get_db)
):
    """refreshaccesstoken

    userefreshtokenGetnewaccesstoken。

    Args:
        refresh_token_request: refreshtokenrequest
        db: Database session

    Returns:
        newaccesstoken

    Raises:
        HTTPException: refresh token invalid or already expired
    """
    access_token = await auth_service.refresh_access_token(
        db, refresh_token_request.refresh_token
    )

    if not access_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return {"access_token": access_token, "token_type": "bearer"}


# ========== EmailValidate ==========


@router.post(
    "/verify-email",
    summary="验证邮箱",
    description=(
        "无需认证。使用注册/重发接口收到的验证码完成邮箱验证。\n\n"
        "请求格式（JSON Body）：\n"
        "- `email`: string 必填\n"
        "- `code`: string 必填，4-10 位验证码\n\n"
        '```json\n{"email": "john@example.com", "code": "123456"}\n```\n\n'
        '返回格式（200）：\n`{"message": "Email verified successfully"}`\n\n'
        "错误码：404 用户不存在；400 验证码无效或已过期。"
    ),
    response_description="邮箱验证成功。",
)
async def verify_email(
    verification: EmailVerificationRequest, db: AsyncSession = Depends(get_db)
):
    """Verify Email

    Use verification code to verify user email.

    Args:
        verification: EmailValidaterequest
        db: Database session

    Returns:
        successmessage

    Raises:
        HTTPException: verification code invalid or already expired
    """
    # finduser
    user = await user_crud.get_by_email(db, verification.email)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    # Verify Email
    success = await auth_service.verify_email(db, user.id, verification.code)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code",
        )

    return {"message": "Email verified successfully"}


@router.post(
    "/resend-verification",
    summary="重发邮箱验证码",
    description=(
        "无需认证。为尚未验证邮箱的用户重发验证码；为防枚举用户，不存在的邮箱也返回成功。\n\n"
        "请求格式（JSON Body）：\n"
        "- `email`: string 必填\n\n"
        '```json\n{"email": "john@example.com"}\n```\n\n'
        '返回格式（200）：\n- 存在且未验证：`{"message": "Verification email sent"}`\n'
        '- 不存在：`{"message": "If the email exists, a verification code has been '
        'sent"}`\n\n'
        "错误码：400 邮箱已验证过。"
    ),
    response_description="验证码已发送（或防枚举的统一成功提示）。",
)
async def resend_verification(
    request: ResendVerificationRequest, db: AsyncSession = Depends(get_db)
):
    """Resend verification email

    Args:
        request: Resend verification request
        db: Database session

    Returns:
        successmessage

    Raises:
        HTTPException: user does not exist or email already verified
    """
    # finduser
    user = await user_crud.get_by_email(db, request.email)
    if not user:
        # For security, return success even if user does not exist
        return {"message": "If the email exists, a verification code has been sent"}

    # CheckwhetheralreadyValidate
    if user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Email already verified"
        )

    # sendValidateemail
    await auth_service.send_verification_email(db, user)

    return {"message": "Verification email sent"}


# ========== Passwordreset ==========


@router.post(
    "/forgot-password",
    summary="请求密码重置",
    description=(
        "无需认证。向邮箱发送密码重置验证码；为防枚举用户，无论邮箱是否存在都返回成功。\n\n"
        "请求格式（JSON Body）：\n"
        "- `email`: string 必填\n\n"
        '```json\n{"email": "john@example.com"}\n```\n\n'
        '返回格式（200）：\n`{"message": "If the email exists, a password reset code has '
        'been sent"}`'
    ),
    response_description="重置验证码已发送（统一成功提示）。",
)
async def forgot_password(
    request: PasswordResetRequest, db: AsyncSession = Depends(get_db)
):
    """Request password reset

    Send password reset email to user's email.

    Args:
        request: Passwordresetrequest
        db: Database session

    Returns:
        successmessage
    """
    await auth_service.request_password_reset(db, request.email)

    # For security, always return success message
    return {"message": "If the email exists, a password reset code has been sent"}


@router.post(
    "/reset-password",
    summary="重置密码",
    description=(
        "无需认证。使用邮箱收到的重置验证码设置新密码。\n\n"
        "请求格式（JSON Body）：\n"
        "- `email`: string 必填\n"
        "- `code`: string 必填，4-10 位验证码\n"
        "- `new_password`: string 必填，6-100 字符\n\n"
        '```json\n{"email": "john@example.com", "code": "123456", '
        '"new_password": "newstrongpassword123"}\n```\n\n'
        '返回格式（200）：\n`{"message": "Password reset successfully"}`\n\n'
        "错误码：400 验证码无效或已过期。"
    ),
    response_description="密码重置成功。",
)
async def reset_password(
    reset_data: PasswordResetConfirm, db: AsyncSession = Depends(get_db)
):
    """Reset password

    Use verification code to reset password.

    Args:
        reset_data: Passwordresetconfirmdata
        db: Database session

    Returns:
        successmessage

    Raises:
        HTTPException: verification code invalid or already expired
    """
    success = await auth_service.reset_password(
        db, reset_data.email, reset_data.code, reset_data.new_password
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset code",
        )

    return {"message": "Password reset successfully"}


@router.post(
    "/change-password",
    summary="修改密码（需旧密码）",
    description=(
        "需认证。校验旧密码后修改，并撤销该用户全部刷新令牌（强制重新登录）。\n\n"
        "请求格式（JSON Body）：\n"
        "- `old_password`: string 必填，≥6 字符\n"
        "- `new_password`: string 必填，6-100 字符\n\n"
        '```json\n{"old_password": "oldpassword123", "new_password": '
        '"newstrongpassword123"}\n```\n\n'
        '返回格式（200）：\n`{"message": "Password changed successfully. Please login '
        'again."}`\n\n'
        "错误码：400 旧密码错误；401 未认证。"
    ),
    response_description="密码修改成功，需重新登录。",
)
async def change_password(
    password_data: PasswordChange,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Change password

    User changes their own password (requires old password).

    Args:
        password_data: Passwordmodifydata
        current_user: currentuser
        db: Database session

    Returns:
        successmessage

    Raises:
        HTTPException: oldPassworderror
    """
    # ValidateoldPassword
    user = await user_crud.authenticate(
        db, current_user.username, password_data.old_password
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Incorrect old password"
        )

    # Change password
    await user_crud.change_password(db, current_user.id, password_data.new_password)

    # Revoke all refresh tokens (force re-login)
    await refresh_token_crud.revoke_user_tokens(db, current_user.id)

    return {"message": "Password changed successfully. Please login again."}


# ========== Device management ==========


@router.get(
    "/devices",
    response_model=list[RefreshTokenResponse],
    summary="查询登录设备列表",
    description=(
        "需认证。列出当前用户所有未撤销的登录设备（刷新令牌）。\n\n"
        "请求格式：无参数，请求头携带 `Authorization: Bearer <access_token>`。\n\n"
        "返回格式（200）：RefreshTokenResponse 数组，每项字段：\n"
        "- `id`: int 令牌记录 ID；`user_id`: int 用户 ID\n"
        "- `device_name`: string|null 设备名（取自 User-Agent 前100字符）\n"
        "- `device_type`: string|null（如 web）；`ip_address`: string|null\n"
        "- `expires_at`: datetime 过期时间；`is_revoked`: bool 是否已撤销\n"
        "- `created_at`: datetime 创建时间；`last_used_at`: datetime|null 上次使用时间"
    ),
    response_description="当前用户的活跃登录设备列表。",
)
async def list_devices(
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    """Get all login devices

    List all active login devices for current user.

    Args:
        current_user: currentuser
        db: Database session

    Returns:
        Device list
    """
    tokens = await refresh_token_crud.get_user_tokens(
        db, current_user.id, include_revoked=False
    )
    return tokens
