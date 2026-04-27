from __future__ import annotations

from sqlalchemy import ForeignKey, Table, Column

from app.db import Base


volunteer_skills = Table(
    "volunteer_skills",
    Base.metadata,
    Column("volunteer_id", ForeignKey("profiles.id", ondelete="CASCADE"), primary_key=True),
    Column("skill_id", ForeignKey("skills.id", ondelete="CASCADE"), primary_key=True),
)


events_direction = Table(
    "events_direction",
    Base.metadata,
    Column("event_id", ForeignKey("events.id", ondelete="CASCADE"), primary_key=True),
    Column("direction_id", ForeignKey("directions.id", ondelete="CASCADE"), primary_key=True),
)
