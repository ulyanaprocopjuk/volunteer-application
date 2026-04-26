from contextlib import asynccontextmanager
import asyncio
import logging

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.config import AVATAR_DIR, EVENT_PHOTO_DIR, UPLOAD_DIR
from app.db import Base, SessionLocal, engine
from app.db_schema import ensure_database_schema
from app.routers import (
    auth_router,
    events_router,
    geocoding_router,
    notifications_router,
    profile_router,
    uploads_router,
    users_router,
)
from app.services.auth_service import create_default_admin
from app.services.telegram_admin_bot import telegram_admin_bot

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    AVATAR_DIR.mkdir(parents=True, exist_ok=True)
    EVENT_PHOTO_DIR.mkdir(parents=True, exist_ok=True)
    Base.metadata.create_all(bind=engine)
    ensure_database_schema(engine)

    db = SessionLocal()
    try:
        create_default_admin(db)
    finally:
        db.close()

    bot_task: asyncio.Task | None = None
    if telegram_admin_bot.is_configured:
        bot_task = asyncio.create_task(telegram_admin_bot.run_polling())

    try:
        yield
    finally:
        telegram_admin_bot.stop()
        if bot_task is not None:
            bot_task.cancel()
            try:
                await bot_task
            except asyncio.CancelledError:
                logger.info("Telegram admin bot polling stopped")


app = FastAPI(lifespan=lifespan)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(profile_router)
app.include_router(uploads_router)
app.include_router(events_router)
app.include_router(notifications_router)
app.include_router(geocoding_router)


@app.get("/health")
def health():
    return {"status": "ok"}
