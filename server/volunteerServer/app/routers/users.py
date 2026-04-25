from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_admin, get_current_user
from app.db import get_db
from app.models import User
from app.schemas import UserResponse

router = APIRouter(tags=["users"])


@router.get("/users/me", response_model=UserResponse)
def read_me(
    current_user: Annotated[User, Depends(get_current_user)],
):
    return current_user


@router.get("/admin/users", response_model=list[UserResponse])
def admin_list_users(
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[User, Depends(get_current_admin)],
):
    users = db.scalars(select(User).order_by(User.id)).all()
    return list(users)