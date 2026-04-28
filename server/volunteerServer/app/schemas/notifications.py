from datetime import datetime

from pydantic import BaseModel, ConfigDict


class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sender_name: str
    event_id: str | None = None
    application_id: int | None = None
    event_title: str | None = None
    applicant_name: str | None = None
    application_status: str | None = None
    message: str
    created_at: datetime
    is_read: bool
