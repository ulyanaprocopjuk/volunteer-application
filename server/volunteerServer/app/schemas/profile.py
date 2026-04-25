from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator

from app.models import ProfileType


class ProfileUpsertRequest(BaseModel):
    type: ProfileType
    avatar_url: str | None = None
    first_name: str | None = Field(default=None, max_length=100)
    last_name: str | None = Field(default=None, max_length=100)
    organization_name: str | None = Field(default=None, max_length=255)
    phone: str = Field(min_length=3, max_length=50)
    email: EmailStr
    city: str = Field(min_length=1, max_length=100)
    country: str = Field(min_length=1, max_length=100)
    skills: list[str] | None = None
    about: str | None = None

    @field_validator("skills")
    @classmethod
    def validate_skills(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return value
        return [item.strip() for item in value if item.strip()]

    @field_validator(
        "first_name",
        "last_name",
        "organization_name",
        "phone",
        "city",
        "country",
        "about",
    )
    @classmethod
    def strip_strings(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None

    @field_validator("email", mode="after")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).lower()

    @model_validator(mode="after")
    def validate_profile_shape(self):
        if self.type == ProfileType.volunteer:
            if not self.first_name:
                raise ValueError("first_name is required for volunteer profile")
            if not self.last_name:
                raise ValueError("last_name is required for volunteer profile")
            self.organization_name = None
            self.skills = self.skills or []
        else:
            if not self.organization_name:
                raise ValueError("organization_name is required for organization profile")
            self.first_name = None
            self.last_name = None
            self.skills = []

        return self


class ProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    type: ProfileType
    avatar_url: str | None
    first_name: str | None
    last_name: str | None
    organization_name: str | None
    phone: str
    email: EmailStr
    city: str
    country: str
    skills: list[str]
    about: str | None