from datetime import datetime, timezone
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer, OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import User, UserRole
from app.security import extract_user_id_from_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")
optional_bearer = HTTPBearer(auto_error=False)


def _resolve_user_from_token(token: str, db: Session) -> User | None:
    try:
        user_id = extract_user_id_from_token(token)
    except ValueError:
        return None

    user = db.get(User, user_id)
    if user is None or not user.is_active:
        return None

    if user.is_banned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ваш аккаунт заблокирован",
        )

    if user.frozen_until is not None:
        now = datetime.now(timezone.utc)
        frozen_until = user.frozen_until
        if frozen_until.tzinfo is None:
            frozen_until = frozen_until.replace(tzinfo=timezone.utc)
        if frozen_until > now:
            until_str = frozen_until.strftime("%d.%m.%Y %H:%M UTC")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Ваш аккаунт временно заморожен до {until_str}",
            )

    return user



def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    auth_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )

    user = _resolve_user_from_token(token, db)
    if user is None:
        raise auth_error

    return user



def get_optional_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(optional_bearer)],
    db: Annotated[Session, Depends(get_db)],
) -> User | None:
    if credentials is None:
        return None
    return _resolve_user_from_token(credentials.credentials, db)



def get_current_admin(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    if current_user.role != UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return current_user
