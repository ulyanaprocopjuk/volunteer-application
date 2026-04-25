from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db import get_db
from app.models import Profile, ProfileType, User
from app.schemas import ProfileResponse, ProfileUpsertRequest

router = APIRouter(prefix="/api/profile", tags=["profile"])


@router.post("", response_model=ProfileResponse)
def upsert_profile(
    payload: ProfileUpsertRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    profile = db.scalar(select(Profile).where(Profile.user_id == current_user.id))
    if profile is None:
        profile = Profile(user_id=current_user.id, type=payload.type)
        db.add(profile)

    profile.type = payload.type
    profile.avatar_url = payload.avatar_url
    profile.phone = payload.phone
    profile.email = str(payload.email)
    profile.city = payload.city
    profile.country = payload.country
    profile.about = payload.about

    if payload.type == ProfileType.volunteer:
        profile.first_name = payload.first_name
        profile.last_name = payload.last_name
        profile.organization_name = None
        profile.skills = payload.skills or []
    else:
        profile.first_name = None
        profile.last_name = None
        profile.organization_name = payload.organization_name
        profile.skills = []

    db.commit()
    db.refresh(profile)
    return profile


@router.get("/me", response_model=ProfileResponse)
def get_my_profile(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    profile = db.scalar(select(Profile).where(Profile.user_id == current_user.id))
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )
    return profile