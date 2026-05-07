from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import APP_BASE_URL, EMAIL_VERIFICATION_RESEND_COOLDOWN_SECONDS
from app.db import get_db
from app.models import EmailVerificationCode, PasswordResetToken, RefreshToken, User, UserRole
from app.schemas import (
    ForgotPasswordRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserResponse,
    VerifyEmailRequest,
)
from app.security import (
    generate_reset_token,
    generate_verification_code,
    hash_code,
    hash_password,
    hash_refresh_token,
    verify_password,
)
from app.services.auth_service import (
    issue_token_pair,
    normalize_username,
    revoke_refresh_token,
)
from app.services.email_service import send_password_reset_link, send_verification_code
from app.services.rate_limit import rate_limiter
from app.api.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])

_EMAIL_VERIFY_EXPIRE_MINUTES = 15
_RESET_TOKEN_EXPIRE_MINUTES = 60


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(
    payload: RegisterRequest,
    db: Annotated[Session, Depends(get_db)],
):
    username = normalize_username(payload.username)
    email = payload.email.lower().strip()

    existing_user = db.scalar(select(User).where(User.username == username))
    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken",
        )

    existing_email = db.scalar(select(User).where(User.email == email))
    if existing_email is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    user = User(
        username=username,
        email=email,
        email_verified=False,
        password_hash=hash_password(payload.password),
        role=UserRole.user,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/send-verification-code")
def send_verification_code_endpoint(
    request: Request,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    background_tasks: BackgroundTasks,
):
    if current_user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already verified",
        )

    if current_user.email is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No email on account",
        )

    rate_key = f"verify_code:{current_user.id}"
    if not rate_limiter.allow(rate_key, max_requests=3, window_seconds=600):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Try again later.",
        )

    last_code = db.scalar(
        select(EmailVerificationCode)
        .where(EmailVerificationCode.user_id == current_user.id)
        .where(EmailVerificationCode.used_at.is_(None))
        .order_by(EmailVerificationCode.created_at.desc())
    )
    now = datetime.now(timezone.utc)
    if last_code is not None:
        elapsed = (now - last_code.created_at.replace(tzinfo=timezone.utc)).total_seconds()
        if elapsed < EMAIL_VERIFICATION_RESEND_COOLDOWN_SECONDS:
            wait = int(EMAIL_VERIFICATION_RESEND_COOLDOWN_SECONDS - elapsed)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Resend available in {wait} seconds.",
            )

    code = generate_verification_code()
    code_hash = hash_code(code)
    expires_at = now + timedelta(minutes=_EMAIL_VERIFY_EXPIRE_MINUTES)

    db.add(EmailVerificationCode(
        user_id=current_user.id,
        code_hash=code_hash,
        expires_at=expires_at,
    ))
    db.commit()

    background_tasks.add_task(send_verification_code, current_user.email, code)
    return {"status": "sent"}


@router.post("/verify-email")
def verify_email(
    payload: VerifyEmailRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    if current_user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already verified",
        )

    code_hash = hash_code(payload.code)
    now = datetime.now(timezone.utc)

    stored = db.scalar(
        select(EmailVerificationCode)
        .where(EmailVerificationCode.user_id == current_user.id)
        .where(EmailVerificationCode.code_hash == code_hash)
        .where(EmailVerificationCode.used_at.is_(None))
        .order_by(EmailVerificationCode.created_at.desc())
    )

    if stored is None or stored.expires_at.replace(tzinfo=timezone.utc) <= now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired code",
        )

    stored.used_at = now
    current_user.email_verified = True
    db.commit()
    return {"status": "verified"}


@router.post("/forgot-password")
def forgot_password(
    payload: ForgotPasswordRequest,
    db: Annotated[Session, Depends(get_db)],
    background_tasks: BackgroundTasks,
):
    email = payload.email

    rate_key = f"forgot_password:{email}"
    if not rate_limiter.allow(rate_key, max_requests=3, window_seconds=3600):
        return {"status": "sent"}

    user = db.scalar(select(User).where(User.email == email))

    if user is not None and user.is_active:
        raw_token = generate_reset_token()
        token_hash = hash_code(raw_token)
        now = datetime.now(timezone.utc)
        expires_at = now + timedelta(minutes=_RESET_TOKEN_EXPIRE_MINUTES)

        db.add(PasswordResetToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=expires_at,
        ))
        db.commit()

        reset_url = f"{APP_BASE_URL}reset-password?token={raw_token}"
        background_tasks.add_task(send_password_reset_link, email, reset_url)

    return {"status": "sent"}


@router.post("/reset-password")
def reset_password(
    payload: ResetPasswordRequest,
    db: Annotated[Session, Depends(get_db)],
):
    token_hash = hash_code(payload.token)
    now = datetime.now(timezone.utc)

    stored = db.scalar(
        select(PasswordResetToken)
        .where(PasswordResetToken.token_hash == token_hash)
        .where(PasswordResetToken.used_at.is_(None))
        .where(PasswordResetToken.revoked_at.is_(None))
    )

    if stored is None or stored.expires_at.replace(tzinfo=timezone.utc) <= now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset link",
        )

    user = db.get(User, stored.user_id)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset link",
        )

    user.password_hash = hash_password(payload.new_password)
    stored.used_at = now

    for token in db.scalars(
        select(RefreshToken)
        .where(RefreshToken.user_id == user.id)
        .where(RefreshToken.revoked_at.is_(None))
    ):
        token.revoked_at = now

    db.commit()
    return {"status": "ok"}


@router.post("/login", response_model=TokenResponse)
def login(
    payload: LoginRequest,
    db: Annotated[Session, Depends(get_db)],
):
    username = normalize_username(payload.username)

    user = db.scalar(select(User).where(User.username == username))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    return issue_token_pair(user, db)


@router.post("/refresh", response_model=TokenResponse)
def refresh_tokens(
    payload: RefreshRequest,
    db: Annotated[Session, Depends(get_db)],
):
    token_hash = hash_refresh_token(payload.refresh_token)

    stored_token = db.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )

    if stored_token is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    if stored_token.revoked_at is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token already revoked",
        )

    if stored_token.expires_at <= datetime.now(timezone.utc):
        stored_token.revoked_at = datetime.now(timezone.utc)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired",
        )

    user = db.get(User, stored_token.user_id)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not available",
        )

    stored_token.revoked_at = datetime.now(timezone.utc)
    db.commit()

    return issue_token_pair(user, db)


@router.post("/logout")
def logout(
    payload: RefreshRequest,
    db: Annotated[Session, Depends(get_db)],
):
    revoke_refresh_token(payload.refresh_token, db)
    return {"status": "ok"}
