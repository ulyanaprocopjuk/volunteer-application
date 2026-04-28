from __future__ import annotations

from datetime import UTC, datetime, time, timedelta

from fastapi import BackgroundTasks, HTTPException, status
from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.orm import Session

from app.models import Direction, Event, Profile, User
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

        direction = self._direction_by_name(db, payload.direction)

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
        event.directions.append(direction)

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

        response = self._response(event)
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

    def list_event_feed(
        self,
        db: Session,
        *,
        search_query: str | None = None,
        direction: str | None = None,
        when: str | None = None,
        country: str | None = None,
        city: str | None = None,
    ) -> list[EventResponse]:
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

        normalized_query = (search_query or "").strip()
        if normalized_query:
            search_pattern = f"%{normalized_query}%"
            query = query.where(
                or_(
                    Event.title.ilike(search_pattern),
                    Event.description.ilike(search_pattern),
                    Event.country.ilike(search_pattern),
                    Event.city.ilike(search_pattern),
                    Event.location_name.ilike(search_pattern),
                    Event.directions.any(Direction.name.ilike(search_pattern)),
                )
            )

        normalized_direction = (direction or "").strip()
        if normalized_direction:
            query = query.where(
                Event.directions.any(func.lower(Direction.name) == normalized_direction.lower())
            )

        normalized_when = (when or "").strip().lower()
        if normalized_when:
            time_range = self._event_time_range(now, normalized_when)
            if time_range is not None:
                range_start, range_end = time_range
                query = query.where(
                    Event.starts_at < self._database_comparison_time(db, range_end),
                    event_end >= self._database_comparison_time(db, range_start),
                )

        if country:
            country_variants = self._country_variants(country)
            query = query.where(or_(*[Event.country.ilike(value) for value in country_variants]))

        normalized_city = (city or "").strip()
        if normalized_city:
            query = query.where(Event.city.ilike(normalized_city))

        events = db.scalars(query).all()
        return [self._response(event) for event in events]

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
        response.direction = self._event_direction_name(event)
        response.organizer_name = self._organizer_name(event.creator)
        return response

    @staticmethod
    def _event_direction_name(event: Event) -> str | None:
        if not event.directions:
            return None
        return event.directions[0].name

    @staticmethod
    def _direction_by_name(db: Session, direction_name: str) -> Direction:
        normalized_direction = " ".join(direction_name.split())
        direction = db.scalar(
            select(Direction).where(func.lower(Direction.name) == normalized_direction.lower())
        )

        if direction is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid event direction",
            )

        return direction

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
    def _event_time_range(now: datetime, value: str) -> tuple[datetime, datetime] | None:
        day_start = datetime.combine(now.date(), time.min, tzinfo=UTC)

        if value == "today":
            return day_start, day_start + timedelta(days=1)

        if value == "tomorrow":
            tomorrow = day_start + timedelta(days=1)
            return tomorrow, tomorrow + timedelta(days=1)

        if value == "weekend":
            if day_start.weekday() == 6:
                saturday = day_start - timedelta(days=1)
            else:
                days_until_saturday = (5 - day_start.weekday()) % 7
                saturday = day_start + timedelta(days=days_until_saturday)
            return saturday, saturday + timedelta(days=2)

        return None

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
