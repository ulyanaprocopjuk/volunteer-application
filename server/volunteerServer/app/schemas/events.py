from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class CreateEventRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    description: str = Field(min_length=1)
    country: str = Field(min_length=1, max_length=100)
    city: str = Field(min_length=1, max_length=100)
    location_name: str = Field(min_length=1, max_length=255, alias="locationName")
    photo_url: str | None = Field(default=None, max_length=500, alias="photoURL")
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    starts_at: datetime = Field(alias="startsAt")
    ends_at: datetime | None = Field(default=None, alias="endsAt")
    volunteers_needed: int = Field(ge=1, le=100000, alias="volunteersNeeded")

    @field_validator("title", "description", "country", "city", "location_name")
    @classmethod
    def strip_strings(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Value must not be empty")
        return value

    @field_validator("photo_url")
    @classmethod
    def strip_optional_photo_url(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None

    @model_validator(mode="after")
    def validate_dates(self):
        if self.ends_at is not None and self.ends_at < self.starts_at:
            raise ValueError("endsAt must be greater than or equal to startsAt")
        return self


class EventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: str
    title: str
    description: str
    country: str
    city: str
    location_name: str = Field(alias="locationName")
    photo_url: str | None = Field(default=None, alias="photoURL")
    latitude: float
    longitude: float
    starts_at: datetime = Field(alias="startsAt")
    ends_at: datetime | None = Field(default=None, alias="endsAt")
    volunteers_needed: int = Field(alias="volunteersNeeded")
    status: str | None = None
    message: str | None = None
    organizer_name: str | None = Field(default=None, alias="organizerName")
    created_at: datetime | None = Field(default=None, alias="created_at")

    @field_validator("status")
    @classmethod
    def status_to_russian(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return {
            "pending": "Ожидает подтверждения",
            "approved": "Подтверждено",
            "rejected": "Отклонено",
        }.get(value, value)


class CurrentCountryEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    latitude: float
    longitude: float
    address: str
