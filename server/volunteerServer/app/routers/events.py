from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status, BackgroundTasks
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_optional_user
from app.db import get_db
from app.models import User
from app.schemas import (
    AttendanceItemResponse,
    CancelEventRequest,
    ChatRoomResponse,
    ConfirmAttendanceRequest,
    CreateEventRequest,
    CurrentCountryEventResponse,
    EventParticipantResponse,
    EventResponse,
    GroupingRequest,
    GroupLeaderRequest,
    GroupMemberRequest,
    GroupResponse,
    MessageResponse,
    RemoveEventParticipantRequest,
    SendMessageRequest,
)
from app.services.events_service import event_service

router = APIRouter(prefix="/api/events", tags=["events"])


@router.post("", response_model=EventResponse, status_code=status.HTTP_201_CREATED)
def create_event(
    payload: CreateEventRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    background_tasks: BackgroundTasks,
):
    return event_service.create_event(db, payload, current_user, background_tasks)


@router.post("/{event_id}/cancel", response_model=EventResponse)
def cancel_event(
    event_id: str,
    payload: CancelEventRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.cancel_event(db, event_id, current_user, payload.reason)


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_event(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    event_service.delete_event(db, event_id, current_user)


@router.post("/{event_id}/finish", response_model=EventResponse)
def finish_event(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.finish_event(db, event_id, current_user)


@router.post("/{event_id}/start", response_model=EventResponse)
def start_event(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.start_event(db, event_id, current_user)


@router.get("/{event_id}/attendance", response_model=list[AttendanceItemResponse])
def get_attendance(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.get_attendance(db, event_id, current_user)


@router.post("/{event_id}/attendance/confirm", response_model=EventResponse)
def confirm_attendance(
    event_id: str,
    payload: ConfirmAttendanceRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.confirm_attendance(db, event_id, current_user, payload.present_application_ids)


@router.patch("/{event_id}/grouping", response_model=EventResponse)
def save_group_count_draft(
    event_id: str,
    payload: GroupingRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.save_group_count_draft(db, event_id, current_user, payload.group_count)


@router.post("/{event_id}/grouping/confirm", response_model=EventResponse)
def confirm_grouping(
    event_id: str,
    payload: GroupingRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.confirm_grouping(db, event_id, current_user, payload.group_count)


@router.post("/{event_id}/groups", response_model=GroupResponse, status_code=status.HTTP_201_CREATED)
def add_event_group(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.add_group(db, event_id, current_user)


@router.get("/{event_id}/groups", response_model=list[GroupResponse])
def list_event_groups(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.get_groups(db, event_id, current_user)


@router.post("/{event_id}/groups/auto", response_model=list[GroupResponse])
def auto_distribute_groups(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.auto_distribute(db, event_id, current_user)


@router.post("/{event_id}/groups/confirm", response_model=EventResponse)
def confirm_event_groups(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.confirm_groups(db, event_id, current_user)


@router.put("/{event_id}/groups/{group_number}/leader", response_model=GroupResponse)
def set_group_leader(
    event_id: str,
    group_number: int,
    payload: GroupLeaderRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.set_group_leader(db, event_id, group_number, payload.profile_id, current_user)


@router.delete("/{event_id}/groups/{group_number}/leader", response_model=GroupResponse)
def remove_group_leader(
    event_id: str,
    group_number: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.remove_group_leader(db, event_id, group_number, current_user)


@router.post("/{event_id}/groups/{group_number}/members", response_model=GroupResponse)
def add_group_member(
    event_id: str,
    group_number: int,
    payload: GroupMemberRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.add_group_member(db, event_id, group_number, payload.profile_id, current_user)


@router.delete("/{event_id}/groups/{group_number}", status_code=status.HTTP_204_NO_CONTENT)
def delete_event_group(
    event_id: str,
    group_number: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    event_service.delete_group(db, event_id, group_number, current_user)


@router.delete("/{event_id}/groups/{group_number}/members/{profile_id}", response_model=GroupResponse)
def remove_group_member(
    event_id: str,
    group_number: int,
    profile_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.remove_group_member(db, event_id, group_number, profile_id, current_user)


@router.delete("/{event_id}/applications", response_model=EventResponse)
def cancel_application(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.cancel_application(db, event_id, current_user)


@router.post("/{event_id}/applications", response_model=EventResponse)
def apply_to_event(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.apply_to_event(db, event_id, current_user)


@router.get("/{event_id}/applications", response_model=list[EventParticipantResponse])
def list_event_applications(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.list_event_applications(db, event_id, current_user)


@router.post("/applications/{application_id}/accept", response_model=EventResponse)
def accept_event_application(
    application_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.accept_application(db, application_id, current_user)


@router.post("/applications/{application_id}/reject", response_model=EventResponse)
def reject_event_application(
    application_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.reject_application(db, application_id, current_user)


@router.post("/applications/{application_id}/remove", response_model=EventResponse)
def remove_event_participant(
    application_id: int,
    payload: RemoveEventParticipantRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.remove_participant(db, application_id, current_user, payload.reason)


@router.get("/{event_id}/messages", response_model=list[MessageResponse])
def list_event_messages(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.get_messages(db, event_id, current_user)


@router.post("/{event_id}/messages", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
def send_event_message(
    event_id: str,
    payload: SendMessageRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.send_message(db, event_id, current_user, payload.content, payload.photo_url)


@router.get("/{event_id}/chats", response_model=list[ChatRoomResponse])
def list_event_chats(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.get_chats(db, event_id, current_user)


@router.get("/{event_id}/chats/{chat_id}/messages", response_model=list[MessageResponse])
def list_chat_messages(
    event_id: str,
    chat_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.get_chat_messages(db, event_id, chat_id, current_user)


@router.post("/{event_id}/chats/{chat_id}/messages", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
def send_chat_message(
    event_id: str,
    chat_id: int,
    payload: SendMessageRequest,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.send_chat_message(db, event_id, chat_id, current_user, payload.content, payload.photo_url)


@router.get("/my", response_model=list[EventResponse])
def list_my_events(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    filter: str | None = Query(default=None, pattern="^(active|history)$"),
):
    return event_service.list_my_events(db, current_user, event_filter=filter)


@router.get("/current-country/me", response_model=list[CurrentCountryEventResponse])
def list_current_country_events(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    return event_service.list_events_for_current_user_country(db, current_user)


@router.get("/feed", response_model=list[EventResponse])
def list_event_feed(
    db: Annotated[Session, Depends(get_db)],
    q: str | None = Query(default=None),
    direction: str | None = Query(default=None),
    when: str | None = Query(default=None, pattern="^(today|tomorrow|weekend|any)$"),
    country: str | None = Query(default=None),
    city: str | None = Query(default=None),
):
    return event_service.list_event_feed(
        db,
        search_query=q,
        direction=direction,
        when=None if when == "any" else when,
        country=country,
        city=city,
    )


@router.get("", response_model=list[CurrentCountryEventResponse])
def list_events(
    db: Annotated[Session, Depends(get_db)],
    country: str | None = Query(default=None),
    city: str | None = Query(default=None),
):
    return event_service.list_events(db, country=country, city=city)


@router.get("/{event_id}", response_model=EventResponse)
def get_event(
    event_id: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User | None, Depends(get_optional_user)],
):
    event = event_service.get_event_response(db, event_id, current_user)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    return event
