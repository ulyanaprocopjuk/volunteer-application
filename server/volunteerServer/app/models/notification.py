from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.notification_text import DEFAULT_NOTIFICATION_SENDER_NAME


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    sender_name: Mapped[str] = mapped_column(String(100), default=DEFAULT_NOTIFICATION_SENDER_NAME, nullable=False)
    event_id: Mapped[str | None] = mapped_column(ForeignKey("events.id", ondelete="SET NULL"), nullable=True)
    application_id: Mapped[int | None] = mapped_column(
        ForeignKey("event_applications.id", ondelete="SET NULL"),
        nullable=True,
    )
    message: Mapped[str] = mapped_column(Text, nullable=False)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    user = relationship("User")
    event = relationship("Event")
    application = relationship("EventApplication")

    @property
    def event_title(self) -> str | None:
        return self.event.title if self.event is not None else None

    @property
    def applicant_name(self) -> str | None:
        if self.application is None or self.application.volunteer is None:
            return None

        profile = self.application.volunteer
        organization_name = (profile.organization_name or "").strip()
        if organization_name:
            return organization_name

        full_name = " ".join(
            part.strip()
            for part in [profile.first_name or "", profile.last_name or ""]
            if part.strip()
        )
        return full_name or "Волонтёр"

    @property
    def application_status(self) -> str | None:
        if self.application is None:
            return None
        return self.application.status.value
