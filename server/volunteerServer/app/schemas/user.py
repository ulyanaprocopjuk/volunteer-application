from pydantic import BaseModel, ConfigDict

from app.models import UserRole


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    email: str | None
    email_verified: bool
    role: UserRole
    is_active: bool