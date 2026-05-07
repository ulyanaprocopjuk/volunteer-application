from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db import get_db
from app.models import Profile, ProfileType, Skill, User
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
    if payload.email is not None:
        profile.email = str(payload.email)
    profile.city = payload.city
    profile.country = payload.country
    profile.about = payload.about

    if payload.type == ProfileType.volunteer:
        profile.first_name = payload.first_name
        profile.last_name = payload.last_name
        profile.organization_name = None
        profile.skill_refs = _resolve_skill_refs(db, payload.skills or [])
    else:
        profile.first_name = None
        profile.last_name = None
        profile.organization_name = payload.organization_name
        profile.skill_refs = []

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


def _resolve_skill_refs(db: Session, skill_names: list[str]) -> list[Skill]:
    if not skill_names:
        return []

    ordered_names = list(dict.fromkeys(skill_names))
    skills = db.scalars(select(Skill).where(Skill.name.in_(ordered_names))).all()
    skills_by_name = {skill.name: skill for skill in skills}
    return [skills_by_name[name] for name in ordered_names if name in skills_by_name]
