from __future__ import annotations

from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base

if TYPE_CHECKING:
    from .profile import Profile


class EventGroup(Base):
    __tablename__ = "event_groups"
    __table_args__ = (UniqueConstraint("event_id", "group_number"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    event_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("events.id", ondelete="CASCADE"), index=True, nullable=False
    )
    group_number: Mapped[int] = mapped_column(Integer, nullable=False)
    leader_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("profiles.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    members: Mapped[list[EventGroupMember]] = relationship(
        "EventGroupMember", back_populates="group", cascade="all, delete-orphan"
    )
    leader: Mapped[Profile | None] = relationship("Profile", foreign_keys=[leader_id])


class EventGroupMember(Base):
    __tablename__ = "event_group_members"
    __table_args__ = (UniqueConstraint("group_id", "profile_id"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    group_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("event_groups.id", ondelete="CASCADE"), index=True, nullable=False
    )
    profile_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("profiles.id", ondelete="CASCADE"), index=True, nullable=False
    )
    role: Mapped[str] = mapped_column(String(20), default="member", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    group: Mapped[EventGroup] = relationship("EventGroup", back_populates="members")
    profile: Mapped[Profile] = relationship("Profile", foreign_keys=[profile_id])
