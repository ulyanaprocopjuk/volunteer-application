from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from .profile import ProfileResponse


class CreateEventRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    direction: str = Field(min_length=1, max_length=100)
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

    @field_validator("title", "direction", "description", "country", "city", "location_name")
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
    direction: str | None = None
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
    accepted_count: int = Field(default=0, alias="accepted_count")
    user_application_status: str | None = Field(default=None, alias="user_application_status")
    is_creator: bool = Field(default=False, alias="is_creator")
    status: str | None = None
    message: str | None = None
    organizer_name: str | None = Field(default=None, alias="organizerName")
    created_at: datetime | None = Field(default=None, alias="created_at")
    present_count: int | None = Field(default=None)
    group_count: int | None = Field(default=None)

    @field_validator("status")
    @classmethod
    def status_to_russian(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return {
            "pending": "Ожидает подтверждения",
            "approved": "Подтверждено",
            "active": "Активно",
            "attendance": "attendance",
            "rejected": "Отклонено",
            "cancelled": "Отменено",
            "completed": "Завершено",
        }.get(value.lower(), value)


class EventParticipantResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    application_id: int = Field(alias="application_id")
    event_id: str = Field(alias="event_id")
    event_title: str = Field(alias="event_title")
    status: str
    is_creator: bool = Field(default=False, alias="is_creator")
    profile: ProfileResponse


class RemoveEventParticipantRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=500)

    @field_validator("reason")
    @classmethod
    def strip_reason(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("reason is required")
        return value


class CancelEventRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=500)

    @field_validator("reason")
    @classmethod
    def strip_reason(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("reason is required")
        return value


class GroupingRequest(BaseModel):
    group_count: int = Field(ge=0, le=5, alias="groupCount")

    model_config = ConfigDict(populate_by_name=True)


class AttendanceItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    application_id: int = Field(alias="application_id")
    is_present: bool = Field(alias="is_present")
    profile: ProfileResponse


class ConfirmAttendanceRequest(BaseModel):
    present_application_ids: list[int] = Field(alias="presentApplicationIDs")

    model_config = ConfigDict(populate_by_name=True)


class GroupMemberResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    profile_id: int
    role: str
    profile: ProfileResponse


class GroupResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: int
    event_id: str
    group_number: int
    leader_id: int | None = None
    leader: ProfileResponse | None = None
    members: list[GroupMemberResponse] = []


class GroupLeaderRequest(BaseModel):
    profile_id: int = Field(alias="profileID")

    model_config = ConfigDict(populate_by_name=True)


class GroupMemberRequest(BaseModel):
    profile_id: int = Field(alias="profileID")

    model_config = ConfigDict(populate_by_name=True)


class MessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: int
    event_id: str
    sender_profile_id: int
    content: Optional[str] = None
    photo_url: Optional[str] = None
    created_at: datetime
    is_organizer: bool = False
    is_leader: bool = False
    leader_label: Optional[str] = None
    profile: ProfileResponse


class SendMessageRequest(BaseModel):
    content: Optional[str] = Field(default=None, max_length=2000)
    photo_url: Optional[str] = Field(default=None, alias="photoURL")

    model_config = ConfigDict(populate_by_name=True)

    @model_validator(mode="after")
    def validate_content_or_photo(self):
        if not self.content and not self.photo_url:
            raise ValueError("Message must have content or a photo")
        return self


class ChatRoomResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: int
    event_id: str
    type: str
    group_number: Optional[int] = None
    title: str


class CurrentCountryEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    latitude: float
    longitude: float
    address: str
