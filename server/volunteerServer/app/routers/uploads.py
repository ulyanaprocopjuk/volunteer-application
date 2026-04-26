from shutil import copyfileobj
from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status

from app.api.deps import get_current_user
from app.config import ALLOWED_IMAGE_TYPES, AVATAR_DIR, EVENT_PHOTO_DIR
from app.models import User

router = APIRouter(prefix="/api/uploads", tags=["uploads"])


@router.post("/avatar", status_code=status.HTTP_201_CREATED)
def upload_avatar(
    request: Request,
    file: UploadFile = File(...),
    _: Annotated[User, Depends(get_current_user)] = None,
):
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPG, PNG and WEBP images are allowed",
        )

    extension = ALLOWED_IMAGE_TYPES[file.content_type]
    file_name = f"{uuid4().hex}{extension}"
    file_path = AVATAR_DIR / file_name

    with file_path.open("wb") as buffer:
        copyfileobj(file.file, buffer)

    avatar_url = str(request.base_url).rstrip("/") + f"/uploads/avatars/{file_name}"
    return {"avatar_url": avatar_url}


@router.post("/event-photo", status_code=status.HTTP_201_CREATED)
def upload_event_photo(
    request: Request,
    file: UploadFile = File(...),
    _: Annotated[User, Depends(get_current_user)] = None,
):
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPG, PNG and WEBP images are allowed",
        )

    EVENT_PHOTO_DIR.mkdir(parents=True, exist_ok=True)
    extension = ALLOWED_IMAGE_TYPES[file.content_type]
    file_name = f"{uuid4().hex}{extension}"
    file_path = EVENT_PHOTO_DIR / file_name

    with file_path.open("wb") as buffer:
        copyfileobj(file.file, buffer)

    photo_url = str(request.base_url).rstrip("/") + f"/uploads/event_photos/{file_name}"
    return {"photo_url": photo_url}
