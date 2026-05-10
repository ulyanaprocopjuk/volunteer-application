from __future__ import annotations

from datetime import UTC, datetime, time, timedelta

from fastapi import BackgroundTasks, HTTPException, status
from sqlalchemy import and_, false, func, or_, select, true, update
from sqlalchemy.orm import Session

from app.models import Direction, Event, EventApplication, EventApplicationStatus, EventAttendance, EventGroup, EventGroupMember, EventMessage, EventRating, Profile, ProfileType, User
from app.schemas import (
    AttendanceItemResponse,
    ChatRoomResponse,
    ConfirmAttendanceRequest,
    CreateEventRequest,
    CurrentCountryEventResponse,
    EventParticipantResponse,
    EventResponse,
    GroupingRequest,
    GroupMemberResponse,
    GroupResponse,
    MessageResponse,
    RatableProfileResponse,
    RatingItem,
    SubmitRatingsRequest,
)

LEADERS_CHAT_ID = 9999
_GROUP_EDIT_STATUSES = {"grouping", "active"}
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

        creator_profile = self._profile_for_user(db, user)
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
        if creator_profile.type == ProfileType.volunteer:
            db.add(
                EventApplication(
                    event_id=event.id,
                    volunteer_id=creator_profile.id,
                    status=EventApplicationStatus.accepted,
                )
            )

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

        response = self._response(db, event, user)
        response.message = "Событие отправлено для подтверждения, ожидайте."
        return response

    def approve_event(self, db: Session, event_id: str, admin: User) -> EventResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        normalized_status = (event.status or "").strip().lower()
        if normalized_status not in ("pending", "approved"):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event cannot be approved")

        event.status = "approved"
        event.reviewed_by = admin.id
        event.reviewed_at = datetime.now(UTC)
        db.commit()
        db.refresh(event)

        response = self._response(db, event, admin)
        response.message = "Событие подтверждено"
        return response

    def get_event(self, db: Session, event_id: str) -> Event | None:
        return db.get(Event, event_id)

    def get_event_response(self, db: Session, event_id: str, user: User | None = None) -> EventResponse | None:
        self._mark_completed_events(db)
        event = self.get_event(db, event_id)
        if event is None:
            return None
        return self._response(db, event, user)

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
        profile = db.scalar(select(Profile).where(Profile.user_id == user.id))
        participant_clause = false()
        if profile is not None:
            participant_clause = Event.applications.any(
                and_(
                    EventApplication.volunteer_id == profile.id,
                    EventApplication.status == EventApplicationStatus.accepted,
                )
            )

        query = (
            select(Event)
            .where(or_(Event.creator_id == user.id, participant_clause))
            .order_by(Event.created_at.desc())
        )

        normalized_filter = (event_filter or "").strip().lower()

        if normalized_filter == "active":
            query = query.where(
                func.lower(Event.status).in_(("approved", "active", "attendance", "grouping", "rating")),
                event_end >= comparison_time,
            )
        elif normalized_filter == "history":
            query = query.where(
                func.lower(Event.status).in_(("rejected", "completed", "cancelled"))
            )

        events = db.scalars(query).all()

        return [self._response(db, event, user) for event in events]

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
                self._available_slots_clause(),
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
                self._available_slots_clause(),
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
        return [self._response(db, event) for event in events]

    def apply_to_event(self, db: Session, event_id: str, user: User) -> EventResponse:
        if not user.is_active:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is blocked")

        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        profile = self._profile_for_user(db, user)
        accepted_count = self._accepted_count(db, event.id)
        existing_application = self._application_for_profile(db, event.id, profile.id)

        if event.creator_id == user.id:
            if profile.type == ProfileType.organization:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Organization cannot participate as volunteer",
                )

            if existing_application is None:
                if accepted_count >= event.volunteers_needed:
                    raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Свободных мест больше нет")
                existing_application = EventApplication(
                    event_id=event.id,
                    volunteer_id=profile.id,
                    status=EventApplicationStatus.accepted,
                )
                db.add(existing_application)
            else:
                if (
                    existing_application.status != EventApplicationStatus.accepted
                    and accepted_count >= event.volunteers_needed
                ):
                    raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Свободных мест больше нет")
                existing_application.status = EventApplicationStatus.accepted

            db.commit()
            db.refresh(event)
            response = self._response(db, event, user)
            response.message = "Вы участвуете как волонтёр"
            return response

        if existing_application is not None:
            response = self._response(db, event, user)
            if existing_application.status == EventApplicationStatus.accepted:
                response.message = "Вы уже участвуете"
            elif existing_application.status == EventApplicationStatus.rejected:
                response.message = "Ваша заявка была отклонена"
            else:
                response.message = "Заявка уже отправлена"
            return response

        if accepted_count >= event.volunteers_needed:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Свободных мест больше нет")

        application = EventApplication(
            event_id=event.id,
            volunteer_id=profile.id,
            status=EventApplicationStatus.pending,
        )
        db.add(application)
        db.flush()

        applicant_name = self._profile_display_name(profile)
        event_title = event.title.strip() or "событие"
        notification_service.create(
            db,
            event.creator_id,
            f"{applicant_name} хочет участвовать в событии «{event_title}».",
            sender_name=applicant_name,
            event_id=event.id,
            application_id=application.id,
        )

        db.commit()
        db.refresh(event)
        response = self._response(db, event, user)
        response.message = "Заявка отправлена"
        return response

    def accept_application(self, db: Session, application_id: int, user: User) -> EventResponse:
        return self._review_application(
            db,
            application_id=application_id,
            user=user,
            new_status=EventApplicationStatus.accepted,
        )

    def reject_application(self, db: Session, application_id: int, user: User) -> EventResponse:
        return self._review_application(
            db,
            application_id=application_id,
            user=user,
            new_status=EventApplicationStatus.rejected,
        )

    def cancel_event(self, db: Session, event_id: str, user: User, reason: str) -> EventResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can cancel event")

        normalized_status = (event.status or "").strip().lower()
        if normalized_status not in ("pending", "approved", "active", "attendance", "grouping"):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event cannot be cancelled")

        normalized_reason = reason.strip()
        event.status = "cancelled"

        accepted_applications = db.scalars(
            select(EventApplication).where(
                EventApplication.event_id == event.id,
                EventApplication.status == EventApplicationStatus.accepted,
            )
        ).all()

        event_title = event.title.strip() or "событие"
        for application in accepted_applications:
            if application.volunteer.user_id != user.id:
                notification_service.create(
                    db,
                    application.volunteer.user_id,
                    f"Событие «{event_title}» отменено. Причина: {normalized_reason}",
                    event_id=event.id,
                )

        db.commit()
        db.refresh(event)
        response = self._response(db, event, user)
        response.message = "Событие отменено"
        return response

    def delete_event(self, db: Session, event_id: str, user: User) -> None:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can delete event")

        db.delete(event)
        db.commit()

    def start_event(self, db: Session, event_id: str, user: User) -> EventResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can start event")

        normalized_status = (event.status or "").strip().lower()
        if normalized_status not in ("approved", "active"):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event cannot be started")

        creator_profile = db.scalar(select(Profile).where(Profile.user_id == user.id))
        accepted_applications = db.scalars(
            select(EventApplication).where(
                EventApplication.event_id == event_id,
                EventApplication.status == EventApplicationStatus.accepted,
                EventApplication.volunteer_id != (creator_profile.id if creator_profile else -1),
            )
        ).all()

        event.status = "attendance"
        db.flush()

        existing_attendance_ids = {
            row[0]
            for row in db.execute(
                select(EventAttendance.application_id).where(EventAttendance.event_id == event_id)
            )
        }
        for application in accepted_applications:
            if application.id not in existing_attendance_ids:
                db.add(EventAttendance(event_id=event_id, application_id=application.id, is_present=False))

        db.commit()
        db.refresh(event)

        response = self._response(db, event, user)
        response.message = "Отметьте присутствующих"
        return response

    def finish_event(self, db: Session, event_id: str, user: User) -> EventResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can finish event")

        if (event.status or "").strip().lower() != "active":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only active events can be finished")

        event.status = "rating"

        accepted_applications = db.scalars(
            select(EventApplication).where(
                EventApplication.event_id == event.id,
                EventApplication.status == EventApplicationStatus.accepted,
            )
        ).all()

        event_title = event.title.strip() or "событие"
        for application in accepted_applications:
            if application.volunteer.user_id != user.id:
                notification_service.create(
                    db,
                    application.volunteer.user_id,
                    f"Событие «{event_title}» завершено. Оцените участников.",
                    event_id=event.id,
                )

        db.commit()
        db.refresh(event)
        response = self._response(db, event, user)
        response.message = "Оцените участников события"
        return response

    def get_attendance(self, db: Session, event_id: str, user: User) -> list[AttendanceItemResponse]:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can view attendance")

        normalized_status = (event.status or "").strip().lower()
        if normalized_status not in ("attendance", "grouping"):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event is not in attendance phase")

        attendance_records = db.scalars(
            select(EventAttendance).where(EventAttendance.event_id == event_id)
        ).all()

        return [
            AttendanceItemResponse(
                application_id=record.application_id,
                is_present=record.is_present,
                profile=record.application.volunteer,
            )
            for record in attendance_records
        ]

    def confirm_attendance(
        self,
        db: Session,
        event_id: str,
        user: User,
        present_application_ids: list[int],
    ) -> EventResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can confirm attendance")

        normalized_status = (event.status or "").strip().lower()
        if normalized_status != "attendance":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event is not in attendance phase")

        present_set = set(present_application_ids)
        attendance_records = db.scalars(
            select(EventAttendance).where(EventAttendance.event_id == event_id)
        ).all()

        now = datetime.now(UTC)
        for record in attendance_records:
            record.is_present = record.application_id in present_set
            record.checked_at = now
            if record.application_id not in present_set:
                application = db.get(EventApplication, record.application_id)
                if application is not None:
                    self._adjust_rating(application.volunteer, -50)

        present_count = len(present_set)
        event.present_count = present_count

        if present_count >= 2:
            event.status = "grouping"
            event.group_count = None
            db.commit()
            db.refresh(event)
            response = self._response(db, event, user)
            response.message = "Выберите количество групп"
        else:
            event.status = "active"
            db.commit()
            db.refresh(event)
            response = self._response(db, event, user)
            response.message = "Событие началось"

        return response

    def save_group_count_draft(self, db: Session, event_id: str, user: User, group_count: int) -> EventResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can update grouping")

        if (event.status or "").strip().lower() != "grouping":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event is not in grouping phase")

        event.group_count = group_count
        db.commit()
        db.refresh(event)
        return self._response(db, event, user)

    def confirm_grouping(self, db: Session, event_id: str, user: User, group_count: int) -> EventResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can confirm grouping")

        if (event.status or "").strip().lower() != "grouping":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event is not in grouping phase")

        event.group_count = group_count

        if group_count == 0:
            event.status = "active"
            db.commit()
            db.refresh(event)
            response = self._response(db, event, user)
            response.message = "Событие началось"
            return response

        existing_groups = db.scalars(
            select(EventGroup).where(EventGroup.event_id == event_id)
        ).all()
        existing_numbers = {g.group_number for g in existing_groups}

        for n in range(1, group_count + 1):
            if n not in existing_numbers:
                db.add(EventGroup(event_id=event_id, group_number=n))

        for group in existing_groups:
            if group.group_number > group_count:
                db.delete(group)

        db.commit()
        db.refresh(event)
        response = self._response(db, event, user)
        response.message = "Распределите участников по группам"
        return response

    def get_groups(self, db: Session, event_id: str, user: User) -> list[GroupResponse]:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can view groups")

        if (event.status or "").strip().lower() not in _GROUP_EDIT_STATUSES:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event is not in grouping or active phase")

        groups = db.scalars(
            select(EventGroup).where(EventGroup.event_id == event_id).order_by(EventGroup.group_number)
        ).all()

        return [self._group_response(group) for group in groups]

    def set_group_leader(self, db: Session, event_id: str, group_number: int, profile_id: int, user: User) -> GroupResponse:
        event, group = self._get_grouping_event_and_group(db, event_id, group_number, user)
        self._validate_profile_is_present(db, event_id, profile_id)
        self._remove_profile_from_all_groups(db, event_id, profile_id, exclude_group_id=group.id)
        group.leader_id = profile_id
        db.commit()
        db.refresh(group)
        return self._group_response(group)

    def remove_group_leader(self, db: Session, event_id: str, group_number: int, user: User) -> GroupResponse:
        _, group = self._get_grouping_event_and_group(db, event_id, group_number, user)
        group.leader_id = None
        db.commit()
        db.refresh(group)
        return self._group_response(group)

    def add_group_member(self, db: Session, event_id: str, group_number: int, profile_id: int, user: User) -> GroupResponse:
        event, group = self._get_grouping_event_and_group(db, event_id, group_number, user)
        self._validate_profile_is_present(db, event_id, profile_id)

        if group.leader_id == profile_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Person is already the group leader")

        self._remove_profile_from_all_groups(db, event_id, profile_id, exclude_group_id=group.id)

        existing = db.scalar(
            select(EventGroupMember).where(
                EventGroupMember.group_id == group.id,
                EventGroupMember.profile_id == profile_id,
            )
        )
        if existing is None:
            db.add(EventGroupMember(group_id=group.id, profile_id=profile_id, role="member"))
            db.commit()

        db.refresh(group)
        return self._group_response(group)

    def remove_group_member(self, db: Session, event_id: str, group_number: int, profile_id: int, user: User) -> GroupResponse:
        _, group = self._get_grouping_event_and_group(db, event_id, group_number, user)

        member = db.scalar(
            select(EventGroupMember).where(
                EventGroupMember.group_id == group.id,
                EventGroupMember.profile_id == profile_id,
            )
        )
        if member:
            db.delete(member)
            db.commit()

        db.refresh(group)
        return self._group_response(group)

    def auto_distribute(self, db: Session, event_id: str, user: User) -> list[GroupResponse]:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can auto-distribute")

        if (event.status or "").strip().lower() not in _GROUP_EDIT_STATUSES:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event is not in grouping or active phase")

        groups = db.scalars(
            select(EventGroup).where(EventGroup.event_id == event_id).order_by(EventGroup.group_number)
        ).all()

        if not groups:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No groups exist")

        attendance_records = db.scalars(
            select(EventAttendance).where(
                EventAttendance.event_id == event_id,
                EventAttendance.is_present == true(),
            )
        ).all()

        profiles = sorted(
            [record.application.volunteer for record in attendance_records],
            key=lambda p: (
                (p.first_name or p.organization_name or "").lower(),
                (p.last_name or "").lower(),
            ),
        )

        for group in groups:
            group.leader_id = None
            for member in list(group.members):
                db.delete(member)
        db.flush()

        group_count = len(groups)
        for i, profile in enumerate(profiles):
            group = groups[i % group_count]
            if group.leader_id is None:
                group.leader_id = profile.id
            else:
                db.add(EventGroupMember(group_id=group.id, profile_id=profile.id, role="member"))

        db.commit()
        for group in groups:
            db.refresh(group)

        return [self._group_response(group) for group in groups]

    def add_group(self, db: Session, event_id: str, user: User) -> GroupResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can add groups")

        if (event.status or "").strip().lower() not in _GROUP_EDIT_STATUSES:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event is not in grouping or active phase")

        max_number = db.scalar(
            select(func.max(EventGroup.group_number)).where(EventGroup.event_id == event_id)
        ) or 0

        new_group = EventGroup(event_id=event_id, group_number=max_number + 1)
        db.add(new_group)
        db.commit()
        db.refresh(new_group)
        return self._group_response(new_group)

    def delete_group(self, db: Session, event_id: str, group_number: int, user: User) -> None:
        _, group = self._get_grouping_event_and_group(db, event_id, group_number, user)
        db.delete(group)
        db.commit()

    def confirm_groups(self, db: Session, event_id: str, user: User) -> EventResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can confirm groups")

        if (event.status or "").strip().lower() != "grouping":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event is not in grouping phase")

        groups = db.scalars(
            select(EventGroup).where(EventGroup.event_id == event_id).order_by(EventGroup.group_number)
        ).all()

        for group in groups:
            if group.leader_id is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Группа {group.group_number} не имеет лидера",
                )

        event.status = "active"
        db.commit()
        db.refresh(event)
        response = self._response(db, event, user)
        response.message = "Событие началось"
        return response

    def get_messages(self, db: Session, event_id: str, user: User) -> list[MessageResponse]:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if (event.status or "").strip().lower() != "active":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Chat is only available for active events")

        if not self._can_access_chat(db, event, user):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

        messages = db.scalars(
            select(EventMessage)
            .where(EventMessage.event_id == event_id)
            .order_by(EventMessage.created_at)
        ).all()

        organizer_profile_id = self._organizer_profile_id(db, event)
        return [
            MessageResponse(
                id=m.id,
                event_id=m.event_id,
                sender_profile_id=m.sender_profile_id,
                content=m.content,
                photo_url=m.photo_url,
                created_at=m.created_at,
                is_organizer=m.sender_profile_id == organizer_profile_id,
                profile=m.sender,
            )
            for m in messages
        ]

    def send_message(
        self,
        db: Session,
        event_id: str,
        user: User,
        content: str | None,
        photo_url: str | None,
    ) -> MessageResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if (event.status or "").strip().lower() != "active":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Chat is only available for active events")

        if not self._can_access_chat(db, event, user):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

        profile = db.scalar(select(Profile).where(Profile.user_id == user.id))
        if profile is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Profile required")

        message = EventMessage(
            event_id=event_id,
            sender_profile_id=profile.id,
            content=content,
            photo_url=photo_url,
        )
        db.add(message)
        db.commit()
        db.refresh(message)

        organizer_profile_id = self._organizer_profile_id(db, event)
        return MessageResponse(
            id=message.id,
            event_id=message.event_id,
            sender_profile_id=message.sender_profile_id,
            content=message.content,
            photo_url=message.photo_url,
            created_at=message.created_at,
            is_organizer=message.sender_profile_id == organizer_profile_id,
            profile=message.sender,
        )

    def get_chats(self, db: Session, event_id: str, user: User) -> list[ChatRoomResponse]:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if (event.status or "").strip().lower() != "active":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Chat is only available for active events")

        groups = self._get_event_groups(db, event_id)
        is_organizer = event.creator_id == user.id
        profile = db.scalar(select(Profile).where(Profile.user_id == user.id))

        if not groups or len(groups) == 1:
            if not self._can_access_chat(db, event, user):
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
            return [ChatRoomResponse(id=0, event_id=event_id, type="single", title="Чат события")]

        # Multiple groups
        if is_organizer:
            return [ChatRoomResponse(id=LEADERS_CHAT_ID, event_id=event_id, type="leaders", title="Чат лидеров")]

        if profile is None:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

        user_group = None
        user_is_leader = False
        for group in groups:
            if group.leader_id == profile.id:
                user_group = group
                user_is_leader = True
                break
            if any(m.profile_id == profile.id for m in group.members):
                user_group = group
                break

        if user_group is None:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

        result = [
            ChatRoomResponse(
                id=user_group.group_number,
                event_id=event_id,
                type="group",
                group_number=user_group.group_number,
                title=f"Группа {user_group.group_number}",
            )
        ]
        if user_is_leader:
            result.append(ChatRoomResponse(id=LEADERS_CHAT_ID, event_id=event_id, type="leaders", title="Чат лидеров"))

        return result

    def get_chat_messages(self, db: Session, event_id: str, chat_id: int, user: User) -> list[MessageResponse]:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if (event.status or "").strip().lower() != "active":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Chat is only available for active events")

        self._validate_chat_access(db, event, chat_id, user)

        messages = db.scalars(
            select(EventMessage)
            .where(EventMessage.event_id == event_id, EventMessage.chat_id == chat_id)
            .order_by(EventMessage.created_at)
        ).all()

        groups = self._get_event_groups(db, event_id)
        organizer_profile_id = self._organizer_profile_id(db, event)
        return [self._build_message_response(message, organizer_profile_id, groups, chat_id) for message in messages]

    def send_chat_message(
        self,
        db: Session,
        event_id: str,
        chat_id: int,
        user: User,
        content: str | None,
        photo_url: str | None,
    ) -> MessageResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if (event.status or "").strip().lower() != "active":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Chat is only available for active events")

        self._validate_chat_access(db, event, chat_id, user)

        profile = db.scalar(select(Profile).where(Profile.user_id == user.id))
        if profile is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Profile required")

        message = EventMessage(
            event_id=event_id,
            sender_profile_id=profile.id,
            chat_id=chat_id,
            content=content,
            photo_url=photo_url,
        )
        db.add(message)
        db.commit()
        db.refresh(message)

        groups = self._get_event_groups(db, event_id)
        organizer_profile_id = self._organizer_profile_id(db, event)
        return self._build_message_response(message, organizer_profile_id, groups, chat_id)

    def cancel_application(self, db: Session, event_id: str, user: User) -> EventResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        profile = self._profile_for_user(db, user)
        application = self._application_for_profile(db, event_id, profile.id)

        if application is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Application not found")

        if application.status not in (EventApplicationStatus.pending, EventApplicationStatus.accepted):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only pending or accepted applications can be cancelled",
            )

        was_accepted = application.status == EventApplicationStatus.accepted
        application.status = EventApplicationStatus.cancelled

        if was_accepted:
            now = datetime.now(UTC)
            starts_at = event.starts_at
            if starts_at is not None and starts_at.tzinfo is None:
                starts_at = starts_at.replace(tzinfo=UTC)
            hours_until = (starts_at - now).total_seconds() / 3600 if starts_at else None
            penalty = -30 if (hours_until is not None and hours_until < 6) else -10
            self._adjust_rating(profile, penalty)

        db.commit()
        db.refresh(event)

        response = self._response(db, event, user)
        response.message = "Заявка отменена"
        return response

    def list_event_applications(
        self,
        db: Session,
        event_id: str,
        user: User,
    ) -> list[EventParticipantResponse]:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can view applications")

        applications = db.scalars(
            select(EventApplication)
            .join(Profile, EventApplication.volunteer_id == Profile.id)
            .where(
                EventApplication.event_id == event.id,
                or_(
                    Profile.user_id != user.id,
                    Profile.type == ProfileType.volunteer,
                ),
            )
            .order_by(EventApplication.created_at.desc())
        ).all()

        return [self._application_response(application, event) for application in applications]

    def remove_participant(
        self,
        db: Session,
        application_id: int,
        user: User,
        reason: str,
    ) -> EventResponse:
        application = db.get(EventApplication, application_id)
        if application is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Application not found")

        event = application.event
        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can remove participants")

        if application.volunteer.user_id == user.id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Organizer cannot be removed")

        if application.status != EventApplicationStatus.accepted:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Participant is not accepted")

        normalized_reason = reason.strip()
        application.status = EventApplicationStatus.cancelled
        event_title = event.title.strip() or "событие"
        notification_service.create(
            db,
            application.volunteer.user_id,
            f"Вы удалены из события «{event_title}». Причина: {normalized_reason}",
            event_id=event.id,
            application_id=application.id,
        )

        db.commit()
        db.refresh(event)
        response = self._response(db, event, user)
        response.message = "Участник удалён"
        return response

    def get_ratable_profiles(self, db: Session, event_id: str, user: User) -> list[RatableProfileResponse]:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if (event.status or "").strip().lower() != "rating":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event is not in rating phase")

        profile = self._profile_for_user(db, user)
        is_organizer = event.creator_id == user.id

        if is_organizer:
            # Organizer rates all accepted participants
            applications = db.scalars(
                select(EventApplication).where(
                    EventApplication.event_id == event_id,
                    EventApplication.status == EventApplicationStatus.accepted,
                )
            ).all()
            profiles = [a.volunteer for a in applications if a.volunteer.id != profile.id]
        else:
            # Leader rates members of own group; member has no one to rate
            group_member = db.scalar(
                select(EventGroupMember).where(
                    EventGroupMember.profile_id == profile.id,
                ).join(EventGroup, EventGroupMember.group_id == EventGroup.id).where(
                    EventGroup.event_id == event_id
                )
            )
            if group_member is None:
                return []
            group = db.get(EventGroup, group_member.group_id)
            if group is None or group.leader_id != profile.id:
                return []
            # Leader rates all non-leader members
            member_rows = db.scalars(
                select(EventGroupMember).where(
                    EventGroupMember.group_id == group.id,
                    EventGroupMember.profile_id != profile.id,
                )
            ).all()
            profiles = [db.get(Profile, m.profile_id) for m in member_rows]
            profiles = [p for p in profiles if p is not None]

        # Exclude already rated
        already_rated = {
            row.rated_id
            for row in db.scalars(
                select(EventRating).where(
                    EventRating.event_id == event_id,
                    EventRating.rater_id == profile.id,
                )
            ).all()
        }

        return [
            RatableProfileResponse(
                profile_id=p.id,
                first_name=p.first_name,
                last_name=p.last_name,
                avatar_url=p.avatar_url,
                current_rating=p.rating,
            )
            for p in profiles
            if p.id not in already_rated
        ]

    def submit_ratings(self, db: Session, event_id: str, user: User, ratings: list[RatingItem]) -> EventResponse:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if (event.status or "").strip().lower() != "rating":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event is not in rating phase")

        profile = self._profile_for_user(db, user)
        is_organizer = event.creator_id == user.id

        for item in ratings:
            if item.score % 10 != 0 or not (-50 <= item.score <= 50):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Score must be a multiple of 10 between -50 and 50")
            rated_profile = db.get(Profile, item.profile_id)
            if rated_profile is None:
                continue
            existing = db.scalar(
                select(EventRating).where(
                    EventRating.event_id == event_id,
                    EventRating.rater_id == profile.id,
                    EventRating.rated_id == item.profile_id,
                )
            )
            if existing is not None:
                continue
            rating_record = EventRating(
                event_id=event_id,
                rater_id=profile.id,
                rated_id=item.profile_id,
                score=item.score,
            )
            db.add(rating_record)
            self._adjust_rating(rated_profile, item.score)

        if is_organizer:
            event.status = "completed"
            db.commit()
            db.refresh(event)
            response = self._response(db, event, user)
            response.message = "Оценки сохранены. Событие завершено."
        else:
            db.commit()
            db.refresh(event)
            response = self._response(db, event, user)
            response.message = "Оценки сохранены"

        return response

    @staticmethod
    def _adjust_rating(profile: Profile, delta: int) -> None:
        profile.rating = max(0, profile.rating + delta)

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

    def _response(self, db: Session, event: Event, user: User | None = None) -> EventResponse:
        response = EventResponse.model_validate(event)
        response.direction = self._event_direction_name(event)
        response.organizer_name = self._organizer_name(event.creator)
        response.accepted_count = self._accepted_count(db, event.id)
        response.is_creator = user is not None and event.creator_id == user.id
        response.user_application_status = self._user_application_status(db, event.id, user)
        return response

    def _review_application(
        self,
        db: Session,
        *,
        application_id: int,
        user: User,
        new_status: EventApplicationStatus,
    ) -> EventResponse:
        application = db.get(EventApplication, application_id)
        if application is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Application not found")

        event = application.event
        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can review application")

        if new_status == EventApplicationStatus.accepted:
            accepted_count = self._accepted_count(db, event.id)
            if application.status != EventApplicationStatus.accepted and accepted_count >= event.volunteers_needed:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Свободных мест больше нет")

        application.status = new_status
        applicant_name = self._profile_display_name(application.volunteer)
        event_title = event.title.strip() or "событие"

        if new_status == EventApplicationStatus.accepted:
            user_message = f"Ваша заявка на событие «{event_title}» принята."
            response_message = "Заявка принята"
        else:
            user_message = f"Ваша заявка на событие «{event_title}» отклонена."
            response_message = "Заявка отклонена"

        notification_service.create(
            db,
            application.volunteer.user_id,
            user_message,
            event_id=event.id,
            application_id=application.id,
        )

        db.commit()
        db.refresh(event)
        response = self._response(db, event, user)
        response.message = f"{response_message}: {applicant_name}"
        return response

    def _validate_chat_access(self, db: Session, event: Event, chat_id: int, user: User) -> None:
        groups = self._get_event_groups(db, event.id)
        is_organizer = event.creator_id == user.id
        profile = db.scalar(select(Profile).where(Profile.user_id == user.id))

        if not groups or len(groups) == 1:
            if chat_id == 0 and self._can_access_chat(db, event, user):
                return
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

        if chat_id == LEADERS_CHAT_ID:
            if is_organizer:
                return
            if profile and any(g.leader_id == profile.id for g in groups):
                return
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

        target_group = next((g for g in groups if g.group_number == chat_id), None)
        if target_group is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat not found")
        if profile and (
            target_group.leader_id == profile.id
            or any(m.profile_id == profile.id for m in target_group.members)
        ):
            return
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    def _get_event_groups(self, db: Session, event_id: str) -> list[EventGroup]:
        return list(db.scalars(
            select(EventGroup).where(EventGroup.event_id == event_id).order_by(EventGroup.group_number)
        ).all())

    @staticmethod
    def _build_message_response(
        message: EventMessage,
        organizer_profile_id: int | None,
        groups: list[EventGroup],
        chat_id: int,
    ) -> MessageResponse:
        is_organizer = message.sender_profile_id == organizer_profile_id
        is_leader = False
        leader_label = None

        if chat_id == LEADERS_CHAT_ID and not is_organizer:
            for group in groups:
                if group.leader_id == message.sender_profile_id:
                    is_leader = True
                    leader_label = f"Лидер {group.group_number}"
                    break

        return MessageResponse(
            id=message.id,
            event_id=message.event_id,
            sender_profile_id=message.sender_profile_id,
            content=message.content,
            photo_url=message.photo_url,
            created_at=message.created_at,
            is_organizer=is_organizer,
            is_leader=is_leader,
            leader_label=leader_label,
            profile=message.sender,
        )

    def _can_access_chat(self, db: Session, event: Event, user: User) -> bool:
        if event.creator_id == user.id:
            return True
        profile = db.scalar(select(Profile).where(Profile.user_id == user.id))
        if profile is None:
            return False
        application = db.scalar(
            select(EventApplication).where(
                EventApplication.event_id == event.id,
                EventApplication.volunteer_id == profile.id,
                EventApplication.status == EventApplicationStatus.accepted,
            )
        )
        return application is not None

    @staticmethod
    def _organizer_profile_id(db: Session, event: Event) -> int | None:
        profile = db.scalar(select(Profile).where(Profile.user_id == event.creator_id))
        return profile.id if profile else None

    def _get_grouping_event_and_group(
        self, db: Session, event_id: str, group_number: int, user: User
    ) -> tuple[Event, EventGroup]:
        event = self.get_event(db, event_id)
        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        if event.creator_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only organizer can modify groups")
        if (event.status or "").strip().lower() not in _GROUP_EDIT_STATUSES:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Event is not in grouping or active phase")
        group = db.scalar(
            select(EventGroup).where(
                EventGroup.event_id == event_id,
                EventGroup.group_number == group_number,
            )
        )
        if group is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")
        return event, group

    @staticmethod
    def _validate_profile_is_present(db: Session, event_id: str, profile_id: int) -> None:
        attendance = db.scalar(
            select(EventAttendance)
            .join(EventApplication, EventAttendance.application_id == EventApplication.id)
            .where(
                EventAttendance.event_id == event_id,
                EventAttendance.is_present == true(),
                EventApplication.volunteer_id == profile_id,
            )
        )
        if attendance is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Person is not a present attendee")

    @staticmethod
    def _remove_profile_from_all_groups(
        db: Session, event_id: str, profile_id: int, exclude_group_id: int | None = None
    ) -> None:
        groups = db.scalars(select(EventGroup).where(EventGroup.event_id == event_id)).all()
        for group in groups:
            if group.id == exclude_group_id:
                continue
            if group.leader_id == profile_id:
                group.leader_id = None
            member = next((m for m in group.members if m.profile_id == profile_id), None)
            if member:
                db.delete(member)
        db.flush()

    @staticmethod
    def _group_response(group: EventGroup) -> GroupResponse:
        return GroupResponse(
            id=group.id,
            event_id=group.event_id,
            group_number=group.group_number,
            leader_id=group.leader_id,
            leader=group.leader,
            members=[
                GroupMemberResponse(
                    profile_id=member.profile_id,
                    role=member.role,
                    profile=member.profile,
                )
                for member in group.members
            ],
        )

    @staticmethod
    def _accepted_count(db: Session, event_id: str) -> int:
        return db.scalar(
            select(func.count())
            .select_from(EventApplication)
            .join(Profile, EventApplication.volunteer_id == Profile.id)
            .where(
                EventApplication.event_id == event_id,
                EventApplication.status == EventApplicationStatus.accepted,
                Profile.type == ProfileType.volunteer,
            )
        ) or 0

    @staticmethod
    def _available_slots_clause():
        accepted_count = (
            select(func.count(EventApplication.id))
            .where(
                EventApplication.event_id == Event.id,
                EventApplication.status == EventApplicationStatus.accepted,
                EventApplication.volunteer.has(Profile.type == ProfileType.volunteer),
            )
            .correlate(Event)
            .scalar_subquery()
        )
        return accepted_count < Event.volunteers_needed

    @staticmethod
    def _application_response(application: EventApplication, event: Event) -> EventParticipantResponse:
        return EventParticipantResponse(
            application_id=application.id,
            event_id=event.id,
            event_title=event.title,
            status=application.status.value,
            is_creator=application.volunteer.user_id == event.creator_id,
            profile=application.volunteer,
        )

    @staticmethod
    def _application_for_profile(db: Session, event_id: str, profile_id: int) -> EventApplication | None:
        return db.scalar(
            select(EventApplication).where(
                EventApplication.event_id == event_id,
                EventApplication.volunteer_id == profile_id,
            )
        )

    def _user_application_status(self, db: Session, event_id: str, user: User | None) -> str | None:
        if user is None or user.profile is None:
            return None

        application = self._application_for_profile(db, event_id, user.profile.id)
        if application is None:
            return None

        return application.status.value

    @staticmethod
    def _profile_for_user(db: Session, user: User) -> Profile:
        profile = db.scalar(select(Profile).where(Profile.user_id == user.id))
        if profile is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Profile is required")
        return profile

    @staticmethod
    def _profile_display_name(profile: Profile) -> str:
        organization_name = (profile.organization_name or "").strip()
        if organization_name:
            return organization_name

        full_name = " ".join(
            part.strip()
            for part in [profile.first_name or "", profile.last_name or ""]
            if part.strip()
        )
        return full_name or "Волонтёр"

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
                func.lower(Event.status).in_(("approved", "active", "attendance", "grouping")),
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
