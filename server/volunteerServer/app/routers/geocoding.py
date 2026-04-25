from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_admin, get_optional_user
from app.config import GEOCODE_RATE_LIMIT_PER_MINUTE
from app.db import get_db
from app.models import User
from app.schemas import ForwardGeocodeResponse, ReverseGeocodeResponse
from app.services.geocoding_service import geocoding_service
from app.services.observability import logger, metrics
from app.services.rate_limit import rate_limiter

router = APIRouter(prefix="/api/v1/geocode", tags=["geocode"])



def _enforce_rate_limit(request: Request, user: User | None) -> None:
    identity = f"user:{user.id}" if user is not None else f"ip:{request.client.host if request.client else 'unknown'}"
    key = f"geocode:{identity}"
    if not rate_limiter.allow(key, GEOCODE_RATE_LIMIT_PER_MINUTE, 60):
        metrics.inc("geocode.rate_limit.exceeded")
        logger.warning("geocode rate limit exceeded", extra={"identity": identity})
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Geocoding rate limit exceeded",
        )


@router.get("/forward", response_model=ForwardGeocodeResponse)
def forward_geocode(
    request: Request,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User | None, Depends(get_optional_user)],
    q: str = Query(min_length=1),
):
    _enforce_rate_limit(request, current_user)
    return geocoding_service.forward_geocode(db, current_user, q)


@router.get("/reverse", response_model=ReverseGeocodeResponse)
def reverse_geocode(
    request: Request,
    current_user: Annotated[User | None, Depends(get_optional_user)],
    lat: float = Query(alias="lat", ge=-90, le=90),
    lon: float = Query(alias="lon", ge=-180, le=180),
):
    _enforce_rate_limit(request, current_user)
    return geocoding_service.reverse_geocode(latitude=lat, longitude=lon)


@router.get("/metrics")
def geocode_metrics(
    _: Annotated[User, Depends(get_current_admin)],
):
    return geocoding_service.metrics_snapshot()
