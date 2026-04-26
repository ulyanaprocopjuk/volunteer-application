import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

DEFAULT_ADMIN_USERNAME = os.getenv("DEFAULT_ADMIN_USERNAME", "admin")
DEFAULT_ADMIN_PASSWORD = os.getenv("DEFAULT_ADMIN_PASSWORD", "Admin12345!")

BASE_DIR = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "uploads"
AVATAR_DIR = UPLOAD_DIR / "avatars"
EVENT_PHOTO_DIR = UPLOAD_DIR / "event_photos"

ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg://app_user:StrongPass_123!@127.0.0.1:5432/app_db",
)

SECRET_KEY = os.getenv(
    "SECRET_KEY",
    "change-this-secret-key-to-a-long-random-string-123456",
)
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "30"))

YANDEX_GEOCODER_API_KEY = os.getenv("YANDEX_GEOCODER_API_KEY", "")
YANDEX_GEOCODER_URL = os.getenv("YANDEX_GEOCODER_URL", "https://geocode-maps.yandex.ru/v1/")
YANDEX_GEOCODER_LANG = os.getenv("YANDEX_GEOCODER_LANG", "ru_RU")
YANDEX_GEOCODER_TIMEOUT_SECONDS = float(os.getenv("YANDEX_GEOCODER_TIMEOUT_SECONDS", "5"))
YANDEX_GEOCODER_RESULTS_LIMIT = int(os.getenv("YANDEX_GEOCODER_RESULTS_LIMIT", "5"))

GEOCODE_RATE_LIMIT_PER_MINUTE = int(os.getenv("GEOCODE_RATE_LIMIT_PER_MINUTE", "60"))
FORWARD_GEOCODE_CACHE_TTL_SECONDS = int(os.getenv("FORWARD_GEOCODE_CACHE_TTL_SECONDS", str(24 * 60 * 60)))
REVERSE_GEOCODE_CACHE_TTL_SECONDS = int(os.getenv("REVERSE_GEOCODE_CACHE_TTL_SECONDS", str(24 * 60 * 60)))
GEOCODE_NEGATIVE_CACHE_TTL_SECONDS = int(os.getenv("GEOCODE_NEGATIVE_CACHE_TTL_SECONDS", "60"))
REVERSE_GEOCODE_COORDINATE_PRECISION = int(os.getenv("REVERSE_GEOCODE_COORDINATE_PRECISION", "5"))

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_ADMIN_IDS = [
    int(value.strip())
    for value in os.getenv("TELEGRAM_ADMIN_IDS", "").split(",")
    if value.strip().isdigit()
]
TELEGRAM_POLL_INTERVAL_SECONDS = float(os.getenv("TELEGRAM_POLL_INTERVAL_SECONDS", "1"))
