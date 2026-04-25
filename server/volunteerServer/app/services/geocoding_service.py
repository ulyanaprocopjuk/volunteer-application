from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import urlopen
from uuid import uuid5, NAMESPACE_URL

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import (
    FORWARD_GEOCODE_CACHE_TTL_SECONDS,
    GEOCODE_NEGATIVE_CACHE_TTL_SECONDS,
    REVERSE_GEOCODE_CACHE_TTL_SECONDS,
    REVERSE_GEOCODE_COORDINATE_PRECISION,
    YANDEX_GEOCODER_API_KEY,
    YANDEX_GEOCODER_LANG,
    YANDEX_GEOCODER_RESULTS_LIMIT,
    YANDEX_GEOCODER_TIMEOUT_SECONDS,
    YANDEX_GEOCODER_URL,
)
from app.models import Profile, User
from app.schemas import ForwardGeocodeResponse, GeocodingSuggestionResponse, ReverseGeocodeResponse
from app.services.cache import TTLCacheStore
from app.services.observability import logger, metrics

COUNTRY_ALIASES: dict[str, tuple[str, str]] = {
    "belarus": ("BY", "Беларусь"),
    "by": ("BY", "Беларусь"),
    "беларусь": ("BY", "Беларусь"),
    "беларуси": ("BY", "Беларусь"),
    "республика беларусь": ("BY", "Беларусь"),
    "russia": ("RU", "Россия"),
    "ru": ("RU", "Россия"),
    "россия": ("RU", "Россия"),
    "рф": ("RU", "Россия"),
    "казахстан": ("KZ", "Казахстан"),
    "kazakhstan": ("KZ", "Казахстан"),
    "kz": ("KZ", "Казахстан"),
    "uzbekistan": ("UZ", "Узбекистан"),
    "узбекистан": ("UZ", "Узбекистан"),
    "uz": ("UZ", "Узбекистан"),
    "poland": ("PL", "Польша"),
    "польша": ("PL", "Польша"),
    "pl": ("PL", "Польша"),
    "lithuania": ("LT", "Литва"),
    "литва": ("LT", "Литва"),
    "lt": ("LT", "Литва"),
    "latvia": ("LV", "Латвия"),
    "латвия": ("LV", "Латвия"),
    "lv": ("LV", "Латвия"),
    "germany": ("DE", "Германия"),
    "германия": ("DE", "Германия"),
    "de": ("DE", "Германия"),
    "france": ("FR", "Франция"),
    "франция": ("FR", "Франция"),
    "fr": ("FR", "Франция"),
    "italy": ("IT", "Италия"),
    "италия": ("IT", "Италия"),
    "it": ("IT", "Италия"),
    "spain": ("ES", "Испания"),
    "испания": ("ES", "Испания"),
    "es": ("ES", "Испания"),
    "turkey": ("TR", "Турция"),
    "turkiye": ("TR", "Турция"),
    "турция": ("TR", "Турция"),
    "tr": ("TR", "Турция"),
    "united states": ("US", "США"),
    "usa": ("US", "США"),
    "us": ("US", "США"),
    "сша": ("US", "США"),
    "ukraine": ("UA", "Украина"),
    "украина": ("UA", "Украина"),
    "ua": ("UA", "Украина"),
    "georgia": ("GE", "Грузия"),
    "грузия": ("GE", "Грузия"),
    "ge": ("GE", "Грузия"),
}

NORMALIZE_RE = re.compile(r"[^\w\s]+", re.UNICODE)
forward_cache: TTLCacheStore[ForwardGeocodeResponse] = TTLCacheStore()
reverse_cache: TTLCacheStore[ReverseGeocodeResponse] = TTLCacheStore()


@dataclass(frozen=True)
class CountryContext:
    code: str | None
    display_name: str | None
    source: str


class GeocodingService:
    def forward_geocode(self, db: Session, user: User | None, query: str) -> ForwardGeocodeResponse:
        query = self._normalize_user_query(query)
        if not query:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Query must not be empty")

        explicit_country = self._detect_explicit_country(query)
        user_country = self._resolve_user_country(db, user)
        country_context = explicit_country or user_country or CountryContext(None, None, "none")
        cache_key = f"forward:{self._cache_normalize(query)}:{country_context.code or '-'}"
        cached = forward_cache.get(cache_key)
        if cached is not None:
            metrics.inc("geocode.forward.cache_hit")
            logger.info("geocode forward cache hit", extra={"query": query, "country": country_context.code})
            return cached

        metrics.inc("geocode.forward.cache_miss")
        logger.info(
            "geocode forward cache miss",
            extra={"query": query, "country": country_context.code, "source": country_context.source},
        )

        candidate_queries = self._build_forward_candidate_queries(query, country_context, explicit_country is not None)
        ranked_items: list[GeocodingSuggestionResponse] = []
        seen_ids: set[str] = set()

        for idx, candidate_query in enumerate(candidate_queries):
            items = self._call_yandex_forward(candidate_query)
            metrics.inc("geocode.forward.provider_calls")
            for item in items:
                if item.id in seen_ids:
                    continue
                seen_ids.add(item.id)
                ranked_items.append(item)
            if ranked_items and idx == 0:
                break

        ranked_items.sort(key=lambda item: self._score_forward_item(item, country_context, query), reverse=True)
        response = ForwardGeocodeResponse(query=query, country=country_context.code, items=ranked_items[:YANDEX_GEOCODER_RESULTS_LIMIT])

        ttl = FORWARD_GEOCODE_CACHE_TTL_SECONDS if response.items else GEOCODE_NEGATIVE_CACHE_TTL_SECONDS
        forward_cache.set(cache_key, response, ttl)
        if response.items:
            metrics.inc("geocode.forward.success")
            logger.info("geocode forward success", extra={"query": query, "count": len(response.items)})
            return response

        metrics.inc("geocode.forward.not_found")
        logger.info("geocode forward not found", extra={"query": query, "country": country_context.code})
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Location not found")

    def reverse_geocode(self, latitude: float, longitude: float) -> ReverseGeocodeResponse:
        rounded_lat = round(latitude, REVERSE_GEOCODE_COORDINATE_PRECISION)
        rounded_lon = round(longitude, REVERSE_GEOCODE_COORDINATE_PRECISION)
        cache_key = f"reverse:{rounded_lat}:{rounded_lon}"
        cached = reverse_cache.get(cache_key)
        if cached is not None:
            metrics.inc("geocode.reverse.cache_hit")
            logger.info("geocode reverse cache hit", extra={"latitude": rounded_lat, "longitude": rounded_lon})
            return cached

        metrics.inc("geocode.reverse.cache_miss")
        logger.info("geocode reverse cache miss", extra={"latitude": rounded_lat, "longitude": rounded_lon})
        items = self._call_yandex_reverse(latitude=latitude, longitude=longitude)
        metrics.inc("geocode.reverse.provider_calls")
        if not items:
            response = ReverseGeocodeResponse(
                latitude=latitude,
                longitude=longitude,
                item=GeocodingSuggestionResponse(
                    id=str(uuid5(NAMESPACE_URL, f"not-found:{rounded_lat}:{rounded_lon}")),
                    title="",
                    subtitle="",
                    fullAddress="",
                    latitude=latitude,
                    longitude=longitude,
                    precision="unknown",
                    country="",
                    city="",
                ),
            )
            reverse_cache.set(cache_key, response, GEOCODE_NEGATIVE_CACHE_TTL_SECONDS)
            metrics.inc("geocode.reverse.not_found")
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Location not found")

        response = ReverseGeocodeResponse(latitude=latitude, longitude=longitude, item=items[0])
        reverse_cache.set(cache_key, response, REVERSE_GEOCODE_CACHE_TTL_SECONDS)
        metrics.inc("geocode.reverse.success")
        logger.info("geocode reverse success", extra={"latitude": latitude, "longitude": longitude})
        return response

    def metrics_snapshot(self) -> dict[str, int]:
        return metrics.snapshot()

    def _resolve_user_country(self, db: Session, user: User | None) -> CountryContext | None:
        if user is None:
            return None
        profile = db.scalar(select(Profile).where(Profile.user_id == user.id))
        if profile is None or not profile.country:
            return None
        normalized = self._cache_normalize(profile.country)
        mapped = COUNTRY_ALIASES.get(normalized)
        if mapped:
            return CountryContext(code=mapped[0], display_name=mapped[1], source="profile")
        return CountryContext(code=None, display_name=profile.country.strip(), source="profile")

    def _build_forward_candidate_queries(
        self,
        query: str,
        country_context: CountryContext,
        has_explicit_country: bool,
    ) -> list[str]:
        candidates = [query]
        if country_context.display_name and not has_explicit_country:
            candidates.insert(0, f"{query}, {country_context.display_name}")
        return list(dict.fromkeys(candidate.strip() for candidate in candidates if candidate.strip()))

    def _score_forward_item(self, item: GeocodingSuggestionResponse, country_context: CountryContext, query: str) -> tuple[int, int, int, int]:
        precision_rank = {
            "exact": 5,
            "number": 4,
            "near": 3,
            "range": 2,
            "street": 1,
        }.get(item.precision, 0)
        country_match = 1 if country_context.display_name and self._cache_normalize(item.country) == self._cache_normalize(country_context.display_name) else 0
        query_city_match = 1 if item.city and self._cache_normalize(item.city) in self._cache_normalize(query) else 0
        subtitle_non_empty = 1 if item.subtitle else 0
        return precision_rank, country_match, query_city_match, subtitle_non_empty

    def _call_yandex_forward(self, query: str) -> list[GeocodingSuggestionResponse]:
        payload = self._call_yandex({
            "geocode": query,
            "results": str(YANDEX_GEOCODER_RESULTS_LIMIT),
        })
        return self._parse_geo_objects(payload)

    def _call_yandex_reverse(self, latitude: float, longitude: float) -> list[GeocodingSuggestionResponse]:
        payload = self._call_yandex({
            "geocode": f"{longitude},{latitude}",
            "sco": "longlat",
            "kind": "house",
            "results": "1",
        })
        return self._parse_geo_objects(payload)

    def _call_yandex(self, extra_params: dict[str, str]) -> dict[str, Any]:
        if not YANDEX_GEOCODER_API_KEY:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Geocoding provider is not configured",
            )

        params = {
            "apikey": YANDEX_GEOCODER_API_KEY,
            "format": "json",
            "lang": YANDEX_GEOCODER_LANG,
            **extra_params,
        }
        url = f"{YANDEX_GEOCODER_URL}?{urlencode(params)}"

        try:
            with urlopen(url, timeout=YANDEX_GEOCODER_TIMEOUT_SECONDS) as response:
                return json.load(response)
        except HTTPError as exc:
            metrics.inc("geocode.provider.http_error")
            logger.warning("geocode provider http error", extra={"status": exc.code})
            detail = "Upstream geocoding provider error"
            if exc.code == 429:
                detail = "Geocoding provider rate limit exceeded"
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=detail) from exc
        except URLError as exc:
            metrics.inc("geocode.provider.network_error")
            logger.warning("geocode provider network error")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unable to reach geocoding provider",
            ) from exc

    def _parse_geo_objects(self, payload: dict[str, Any]) -> list[GeocodingSuggestionResponse]:
        collection = payload.get("response", {}).get("GeoObjectCollection", {})
        feature_members = collection.get("featureMember", [])
        items: list[GeocodingSuggestionResponse] = []

        for member in feature_members:
            geo_object = member.get("GeoObject") or {}
            metadata = geo_object.get("metaDataProperty", {}).get("GeocoderMetaData", {})
            address = metadata.get("Address", {})
            components = address.get("Components") or []
            country = self._find_component(components, "country") or address.get("country_code", "")
            city = (
                self._find_component(components, "locality")
                or self._find_component(components, "province")
                or self._find_component(components, "area")
                or ""
            )
            point = (geo_object.get("Point") or {}).get("pos", "")
            longitude, latitude = self._parse_pos(point)
            items.append(
                GeocodingSuggestionResponse(
                    id=str(uuid5(NAMESPACE_URL, f"{longitude}:{latitude}:{address.get('formatted', '')}")),
                    title=geo_object.get("name", "") or metadata.get("text", ""),
                    subtitle=geo_object.get("description", ""),
                    fullAddress=address.get("formatted", metadata.get("text", "")),
                    latitude=latitude,
                    longitude=longitude,
                    precision=metadata.get("precision") or metadata.get("kind") or "unknown",
                    country=country,
                    city=city,
                )
            )

        return items

    @staticmethod
    def _parse_pos(value: str) -> tuple[float, float]:
        lon_str, lat_str = value.split()
        return float(lon_str), float(lat_str)

    @staticmethod
    def _find_component(components: list[dict[str, str]], kind: str) -> str | None:
        for component in components:
            if component.get("kind") == kind and component.get("name"):
                return component["name"]
        return None

    def _detect_explicit_country(self, query: str) -> CountryContext | None:
        normalized_query = f" {self._cache_normalize(query)} "
        for alias, (code, display_name) in sorted(COUNTRY_ALIASES.items(), key=lambda item: len(item[0]), reverse=True):
            alias_token = f" {alias} "
            if alias_token in normalized_query:
                return CountryContext(code=code, display_name=display_name, source="query")
        return None

    @staticmethod
    def _cache_normalize(value: str) -> str:
        cleaned = NORMALIZE_RE.sub(" ", value.lower())
        return " ".join(cleaned.split())

    def _normalize_user_query(self, value: str) -> str:
        return " ".join(value.strip().split())


geocoding_service = GeocodingService()
