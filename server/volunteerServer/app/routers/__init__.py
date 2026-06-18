from .auth import router as auth_router
from .events import router as events_router
from .geocoding import router as geocoding_router
from .notifications import router as notifications_router
from .profile import router as profile_router
from .uploads import router as uploads_router
from .users import router as users_router

__all__ = [
    "auth_router",
    "users_router",
    "profile_router",
    "uploads_router",
    "events_router",
    "notifications_router",
    "geocoding_router",
]
