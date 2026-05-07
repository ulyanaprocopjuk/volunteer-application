from datetime import datetime, timedelta, timezone
import hashlib
import secrets

import jwt
from jwt.exceptions import InvalidTokenError
from pwdlib import PasswordHash

from app.config import (
    ACCESS_TOKEN_EXPIRE_MINUTES,
    JWT_ALGORITHM,
    REFRESH_TOKEN_EXPIRE_DAYS,
    SECRET_KEY,
)
from app.models import User

password_hasher = PasswordHash.recommended()



def hash_password(password: str) -> str:
    return password_hasher.hash(password)



def verify_password(password: str, password_hash: str) -> bool:
    return password_hasher.verify(password, password_hash)



def create_access_token(user: User) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user.id),
        "role": user.role.value,
        "type": "access",
        "exp": expire,
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=JWT_ALGORITHM)



def decode_access_token(token: str) -> dict:
    payload = jwt.decode(token, SECRET_KEY, algorithms=[JWT_ALGORITHM])
    if payload.get("type") != "access":
        raise InvalidTokenError("Invalid token type")
    return payload



def extract_user_id_from_token(token: str) -> int:
    try:
        payload = decode_access_token(token)
        return int(payload["sub"])
    except (InvalidTokenError, KeyError, ValueError) as exc:
        raise ValueError("Invalid token") from exc



def generate_refresh_token() -> str:
    return secrets.token_urlsafe(64)



def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()



def refresh_token_expires_at() -> datetime:
    return datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)


def generate_verification_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def generate_reset_token() -> str:
    return secrets.token_urlsafe(48)
