from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import DEFAULT_ADMIN_PASSWORD, DEFAULT_ADMIN_USERNAME
from app.models import RefreshToken, User, UserRole
from app.schemas import TokenResponse
from app.security import (
    create_access_token,
    generate_refresh_token,
    hash_password,
    hash_refresh_token,
    refresh_token_expires_at,
)


def normalize_username(username: str) -> str:
    return username.strip().lower()


def create_default_admin(db: Session) -> None:
    existing_admin = db.scalar(
        select(User).where(User.username == normalize_username(DEFAULT_ADMIN_USERNAME))
    )
    if existing_admin is None:
        admin = User(
            username=normalize_username(DEFAULT_ADMIN_USERNAME),
            password_hash=hash_password(DEFAULT_ADMIN_PASSWORD),
            role=UserRole.admin,
            is_active=True,
        )
        db.add(admin)
        db.commit()


def issue_token_pair(user: User, db: Session) -> TokenResponse:
    access_token = create_access_token(user)
    raw_refresh_token = generate_refresh_token()

    refresh_row = RefreshToken(
        user_id=user.id,
        token_hash=hash_refresh_token(raw_refresh_token),
        expires_at=refresh_token_expires_at(),
    )
    db.add(refresh_row)
    db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh_token,
        token_type="bearer",
        role=user.role,
    )


def revoke_refresh_token(raw_refresh_token: str, db: Session) -> RefreshToken | None:
    token_hash = hash_refresh_token(raw_refresh_token)
    stored_token = db.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )

    if stored_token is not None and stored_token.revoked_at is None:
        stored_token.revoked_at = datetime.now(timezone.utc)
        db.commit()

    return stored_token