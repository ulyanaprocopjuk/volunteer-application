from __future__ import annotations

import re


NORMALIZE_RE = re.compile(r"[^\w\s]+", re.UNICODE)


def build_location_display(location_name: str | None, city: str | None, country: str | None) -> str:
    location = _clean(location_name)
    city_value = _clean(city)
    country_value = _clean(country)

    if not location:
        return ", ".join(part for part in [city_value, country_value] if part)

    if _looks_like_full_address(location):
        return location

    parts = [location]
    if city_value and not _has_address_part(location, city_value):
        parts.append(city_value)
    if country_value and not _has_address_part(location, country_value):
        parts.append(country_value)

    return ", ".join(parts)


def _clean(value: str | None) -> str:
    return " ".join((value or "").strip().split())


def _looks_like_full_address(value: str) -> bool:
    return len([part for part in value.split(",") if part.strip()]) >= 3


def _has_address_part(address: str, value: str) -> bool:
    normalized_value = _normalize(value)
    if not normalized_value:
        return False

    return any(_normalize(part) == normalized_value for part in address.split(","))


def _normalize(value: str) -> str:
    cleaned = NORMALIZE_RE.sub(" ", value.lower())
    return " ".join(cleaned.split())
