from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status, BackgroundTasks
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db import get_db
from app.models import User
from app.schemas import CreateEventRequest, CurrentCountryEventResponse, EventResponse
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
):
    return event_service.list_event_feed(db, search_query=q)


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
):
    event = event_service.get_event_response(db, event_id)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    return event
