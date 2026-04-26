from __future__ import annotations

from datetime import UTC, datetime

from fastapi import BackgroundTasks, HTTPException, status
from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.orm import Session

from app.models import Event, Profile, User
from app.schemas import CreateEventRequest, CurrentCountryEventResponse, EventResponse
from app.services.geocoding_service import COUNTRY_ALIASES
from app.services.location_display import build_location_display
from app.services.notification_service import notification_service
from app.services.telegram_admin_bot import telegram_admin_bot


class EventService:
    def create_event(
        self,
        db: Session,
        payload: CreateEventRequest,
        user: User,
        background_tasks: BackgroundTasks | None = None,
    ) -> EventResponse:
        if not user.is_active:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is blocked")

        event = Event(
            creator_id=user.id,
            title=payload.title,
            description=payload.description,
            country=payload.country,
            city=payload.city,
            location_name=payload.location_name,
            photo_url=payload.photo_url,
            latitude=payload.latitude,
            longitude=payload.longitude,
            starts_at=payload.starts_at,
            ends_at=payload.ends_at,
            volunteers_needed=payload.volunteers_needed,
            status="pending",
        )

        db.add(event)
        db.flush()

        notification_service.create(
            db,
            user.id,
            "Событие отправлено для подтверждения, ожидайте.",
        )

        db.commit()
        db.refresh(event)

        if background_tasks is not None:
            background_tasks.add_task(
                telegram_admin_bot.notify_admins_about_event_id,
                event.id,
            )

        response = EventResponse.model_validate(event)
        response.organizer_name = self._organizer_name(user)
        response.message = "Событие отправлено для подтверждения, ожидайте."
        return response

    def get_event(self, db: Session, event_id: str) -> Event | None:
        return db.get(Event, event_id)

    def get_event_response(self, db: Session, event_id: str) -> EventResponse | None:
        self._mark_completed_events(db)
        event = self.get_event(db, event_id)
        if event is None:
            return None
        return self._response(event)

    def list_my_events(
        self,
        db: Session,
        user: User,
        event_filter: str | None = None,
    ) -> list[EventResponse]:
        now = datetime.now(UTC)
        self._mark_completed_events(db, now=now)
        comparison_time = self._database_comparison_time(db, now)
        event_end = func.coalesce(Event.ends_at, Event.starts_at)

        query = (
            select(Event)
            .where(Event.creator_id == user.id)
            .order_by(Event.created_at.desc())
        )

        normalized_filter = (event_filter or "").strip().lower()

        if normalized_filter == "active":
            query = query.where(
                func.lower(Event.status).in_(("approved", "active")),
                event_end >= comparison_time,
            )
        elif normalized_filter == "history":
            query = query.where(
                func.lower(Event.status).in_(("rejected", "completed"))
            )

        events = db.scalars(query).all()

        return [self._response(event) for event in events]

    def list_events(
        self,
        db: Session,
        *,
        country: str | None = None,
        city: str | None = None,
    ) -> list[CurrentCountryEventResponse]:
        now = datetime.now(UTC)
        self._mark_completed_events(db, now=now)
        comparison_time = self._database_comparison_time(db, now)
        event_end = func.coalesce(Event.ends_at, Event.starts_at)

        query = (
            select(Event)
            .where(
                func.lower(Event.status).in_(("approved", "active")),
                event_end >= comparison_time,
            )
            .order_by(Event.starts_at.asc(), Event.created_at.desc())
        )

        if country:
            country_variants = self._country_variants(country)
            query = query.where(or_(*[Event.country.ilike(value) for value in country_variants]))

        if city:
            query = query.where(Event.city.ilike(city.strip()))

        events = db.scalars(query).all()

        return [
            CurrentCountryEventResponse(
                id=event.id,
                title=event.title,
                latitude=float(event.latitude),
                longitude=float(event.longitude),
                address=self._build_address(event),
            )
            for event in events
        ]

    def list_events_for_current_user_country(
        self,
        db: Session,
        user: User,
    ) -> list[CurrentCountryEventResponse]:
        profile = db.scalar(select(Profile).where(Profile.user_id == user.id))

        if profile is None:
            return []

        return self.list_events(db, country=profile.country)

    @staticmethod
    def _build_address(event: Event) -> str:
        return build_location_display(event.location_name, event.city, event.country)

    def _response(self, event: Event) -> EventResponse:
        response = EventResponse.model_validate(event)
        response.organizer_name = self._organizer_name(event.creator)
        return response

    def _mark_completed_events(self, db: Session, now: datetime | None = None) -> None:
        current_time = now or datetime.now(UTC)
        comparison_time = self._database_comparison_time(db, current_time)
        event_end = func.coalesce(Event.ends_at, Event.starts_at)

        result = db.execute(
            update(Event)
            .where(
                func.lower(Event.status).in_(("approved", "active")),
                event_end < comparison_time,
            )
            .values(
                status="completed",
                updated_at=comparison_time,
            )
        )

        if result.rowcount:
            db.commit()

    @staticmethod
    def _database_comparison_time(db: Session, value: datetime) -> datetime:
        if db.bind is not None and db.bind.dialect.name == "sqlite":
            return value.replace(tzinfo=None)
        return value

    @staticmethod
    def _organizer_name(user: User | None) -> str | None:
        if user is None or user.profile is None:
            return None

        profile = user.profile
        organization_name = (profile.organization_name or "").strip()
        if organization_name:
            return organization_name

        full_name = " ".join(
            part.strip()
            for part in [profile.first_name or "", profile.last_name or ""]
            if part and part.strip()
        )
        return full_name or None

    @staticmethod
    def _country_variants(country: str) -> list[str]:
        normalized = " ".join(country.lower().split())
        mapped = COUNTRY_ALIASES.get(normalized)

        variants = {country.strip()}

        if mapped:
            variants.add(mapped[0])
            variants.add(mapped[1])

        return list(variants)


event_service = EventService()
