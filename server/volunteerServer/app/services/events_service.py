from __future__ import annotations

from fastapi import BackgroundTasks, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models import Event, Profile, User
from app.schemas import CreateEventRequest, CurrentCountryEventResponse, EventResponse
from app.services.geocoding_service import COUNTRY_ALIASES
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
        response.message = "Событие отправлено для подтверждения, ожидайте."
        return response

    def get_event(self, db: Session, event_id: str) -> Event | None:
        return db.get(Event, event_id)

    def list_my_events(self, db: Session, user: User) -> list[EventResponse]:
        events = db.scalars(
            select(Event)
            .where(Event.creator_id == user.id)
            .order_by(Event.created_at.desc())
        ).all()

        return [EventResponse.model_validate(event) for event in events]

    def list_events(
        self,
        db: Session,
        *,
        country: str | None = None,
        city: str | None = None,
    ) -> list[CurrentCountryEventResponse]:
        query = (
            select(Event)
            .where(Event.status == "approved")
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
        parts = [event.location_name, event.city, event.country]
        return ", ".join(part for part in parts if part)

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