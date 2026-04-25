from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any, Iterable
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

CIS_COUNTRIES: dict[str, str] = {
    "AZ": "Азербайджан",
    "AM": "Армения",
    "BY": "Беларусь",
    "KZ": "Казахстан",
    "KG": "Кыргызстан",
    "MD": "Молдова",
    "RU": "Россия",
    "TJ": "Таджикистан",
    "TM": "Туркменистан",
    "UZ": "Узбекистан",
    "UA": "Украина",
}

CIS_COUNTRY_ALIASES: dict[str, tuple[str, str]] = {
    "azerbaijan": ("AZ", "Азербайджан"),
    "az": ("AZ", "Азербайджан"),
    "азербайджан": ("AZ", "Азербайджан"),
    "азербайджанская республика": ("AZ", "Азербайджан"),
    "armenia": ("AM", "Армения"),
    "am": ("AM", "Армения"),
    "армения": ("AM", "Армения"),
    "республика армения": ("AM", "Армения"),
    "belarus": ("BY", "Беларусь"),
    "by": ("BY", "Беларусь"),
    "беларусь": ("BY", "Беларусь"),
    "белоруссия": ("BY", "Беларусь"),
    "беларуси": ("BY", "Беларусь"),
    "республика беларусь": ("BY", "Беларусь"),
    "kazakhstan": ("KZ", "Казахстан"),
    "kz": ("KZ", "Казахстан"),
    "казахстан": ("KZ", "Казахстан"),
    "республика казахстан": ("KZ", "Казахстан"),
    "kyrgyzstan": ("KG", "Кыргызстан"),
    "kg": ("KG", "Кыргызстан"),
    "киргизия": ("KG", "Кыргызстан"),
    "кыргызстан": ("KG", "Кыргызстан"),
    "кыргызская республика": ("KG", "Кыргызстан"),
    "moldova": ("MD", "Молдова"),
    "md": ("MD", "Молдова"),
    "молдова": ("MD", "Молдова"),
    "молдавия": ("MD", "Молдова"),
    "республика молдова": ("MD", "Молдова"),
    "russia": ("RU", "Россия"),
    "russian federation": ("RU", "Россия"),
    "ru": ("RU", "Россия"),
    "россия": ("RU", "Россия"),
    "российская федерация": ("RU", "Россия"),
    "рф": ("RU", "Россия"),
    "tajikistan": ("TJ", "Таджикистан"),
    "tj": ("TJ", "Таджикистан"),
    "таджикистан": ("TJ", "Таджикистан"),
    "республика таджикистан": ("TJ", "Таджикистан"),
    "turkmenistan": ("TM", "Туркменистан"),
    "tm": ("TM", "Туркменистан"),
    "туркменистан": ("TM", "Туркменистан"),
    "uzbekistan": ("UZ", "Узбекистан"),
    "uz": ("UZ", "Узбекистан"),
    "узбекистан": ("UZ", "Узбекистан"),
    "республика узбекистан": ("UZ", "Узбекистан"),
    "ukraine": ("UA", "Украина"),
    "ua": ("UA", "Украина"),
    "украина": ("UA", "Украина"),
}

NON_CIS_COUNTRY_ALIASES: dict[str, tuple[str, str]] = {
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
    "georgia": ("GE", "Грузия"),
    "грузия": ("GE", "Грузия"),
    "ge": ("GE", "Грузия"),
}

COUNTRY_ALIASES: dict[str, tuple[str, str]] = {
    **CIS_COUNTRY_ALIASES,
    **NON_CIS_COUNTRY_ALIASES,
}
FORWARD_GEOCODE_SUGGESTION_LIMIT = 3

NORMALIZE_RE = re.compile(r"[^\w\s]+", re.UNICODE)
forward_cache: TTLCacheStore[ForwardGeocodeResponse] = TTLCacheStore()
reverse_cache: TTLCacheStore[ReverseGeocodeResponse] = TTLCacheStore()


@dataclass(frozen=True)
class CountryContext:
    code: str | None
    display_name: str | None
    source: str


@dataclass(frozen=True)
class LocationContext:
    city: str | None
    country: CountryContext | None


class GeocodingService:
    def forward_geocode(self, db: Session, user: User | None, query: str) -> ForwardGeocodeResponse:
        query = self._normalize_user_query(query)
        if not query:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Query must not be empty")

        explicit_country = self._detect_explicit_country(query)
        if explicit_country is not None and not self._is_cis_country_context(explicit_country):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Search is available only for CIS countries",
            )

        user_location = self._resolve_user_location(db, user)
        country_context = explicit_country or user_location.country or CountryContext(None, None, "cis")
        cache_key = (
            f"forward:{self._cache_normalize(query)}:"
            f"{country_context.code or '-'}:"
            f"{self._cache_normalize(user_location.city or '-')}"
        )
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

        ranked_items: list[GeocodingSuggestionResponse] = []
        seen_ids: set[str] = set()
        candidate_query_stages: list[list[str]] = []

        if explicit_country is None:
            raw_items = self._filter_relevant_forward_items(
                self._filter_cis_items(self._call_yandex_forward(query)),
                query,
            )
            metrics.inc("geocode.forward.provider_calls")
            query_city_items = self._query_city_items(raw_items, query)
            if query_city_items:
                self._append_unique_items(
                    ranked_items,
                    seen_ids,
                    self._rank_forward_items(query_city_items, country_context, query, user_location.city),
                )
                candidate_query_stages.append(self._build_cis_country_candidate_queries(query))
            else:
                candidate_query_stages = self._build_forward_candidate_query_stages(
                    query,
                    country_context,
                    has_explicit_country=False,
                    user_city=user_location.city,
                )
        else:
            candidate_query_stages = self._build_forward_candidate_query_stages(
                query,
                country_context,
                has_explicit_country=True,
            )

        for candidate_queries in candidate_query_stages:
            if len(ranked_items) >= FORWARD_GEOCODE_SUGGESTION_LIMIT:
                break
            stage_items: list[GeocodingSuggestionResponse] = []
            for candidate_query in candidate_queries:
                items = self._call_yandex_forward(candidate_query)
                metrics.inc("geocode.forward.provider_calls")
                stage_items.extend(self._filter_cis_items(items))

            stage_items = self._filter_relevant_forward_items(stage_items, query)
            self._append_unique_items(
                ranked_items,
                seen_ids,
                self._rank_forward_items(stage_items, country_context, query, user_location.city),
            )

        response = ForwardGeocodeResponse(
            query=query,
            country=country_context.code,
            items=ranked_items[:FORWARD_GEOCODE_SUGGESTION_LIMIT],
        )

        ttl = FORWARD_GEOCODE_CACHE_TTL_SECONDS if response.items else GEOCODE_NEGATIVE_CACHE_TTL_SECONDS
        forward_cache.set(cache_key, response, ttl)
        if response.items:
            metrics.inc("geocode.forward.success")
            logger.info("geocode forward success", extra={"query": query, "count": len(response.items)})
            return response

        metrics.inc("geocode.forward.not_found")
        logger.info("geocode forward not found", extra={"query": query, "country": country_context.code})
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Location not found in CIS countries")

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

        item = items[0]
        if not self._is_cis_country_name(item.country):
            metrics.inc("geocode.reverse.outside_cis")
            logger.info(
                "geocode reverse outside cis",
                extra={"latitude": latitude, "longitude": longitude, "country": item.country},
            )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Location must be in a CIS country",
            )

        response = ReverseGeocodeResponse(latitude=latitude, longitude=longitude, item=item)
        reverse_cache.set(cache_key, response, REVERSE_GEOCODE_CACHE_TTL_SECONDS)
        metrics.inc("geocode.reverse.success")
        logger.info("geocode reverse success", extra={"latitude": latitude, "longitude": longitude})
        return response

    def metrics_snapshot(self) -> dict[str, int]:
        return metrics.snapshot()

    def _resolve_user_location(self, db: Session, user: User | None) -> LocationContext:
        if user is None:
            return LocationContext(city=None, country=None)

        profile = db.scalar(select(Profile).where(Profile.user_id == user.id))
        if profile is None:
            return LocationContext(city=None, country=None)

        country = self._country_context_from_value(profile.country, "profile") if profile.country else None
        if country is not None and not self._is_cis_country_context(country):
            return LocationContext(city=None, country=None)

        city = profile.city.strip() if profile.city and profile.city.strip() else None
        return LocationContext(city=city, country=country)

    def _resolve_user_country(self, db: Session, user: User | None) -> CountryContext | None:
        return self._resolve_user_location(db, user).country

    def _build_forward_candidate_queries(
        self,
        query: str,
        country_context: CountryContext,
        has_explicit_country: bool,
        user_city: str | None = None,
    ) -> list[str]:
        candidates: list[str] = []
        if has_explicit_country:
            candidates.append(query)
            if country_context.display_name:
                candidates.append(f"{query}, {country_context.display_name}")
            return self._dedupe_candidates(candidates)

        if user_city and country_context.display_name and not self._query_mentions_text(query, user_city):
            candidates.append(f"{query}, {user_city}, {country_context.display_name}")

        if country_context.display_name:
            candidates.append(f"{query}, {country_context.display_name}")

        candidates.extend(self._build_cis_country_candidate_queries(query))
        return self._dedupe_candidates(candidates)

    def _build_forward_candidate_query_stages(
        self,
        query: str,
        country_context: CountryContext,
        has_explicit_country: bool,
        user_city: str | None = None,
    ) -> list[list[str]]:
        if has_explicit_country:
            return [
                self._dedupe_candidates(
                    [
                        query,
                        f"{query}, {country_context.display_name}" if country_context.display_name else "",
                    ]
                )
            ]

        stages: list[list[str]] = []

        if user_city and country_context.display_name and not self._query_mentions_text(query, user_city):
            stages.append([f"{query}, {user_city}, {country_context.display_name}"])

        if country_context.display_name:
            stages.append([f"{query}, {country_context.display_name}"])

        stages.append(self._build_cis_country_candidate_queries(query))
        return [self._dedupe_candidates(stage) for stage in stages if stage]

    def _build_cis_country_candidate_queries(self, query: str) -> list[str]:
        return self._dedupe_candidates(f"{query}, {country}" for country in CIS_COUNTRIES.values())

    @staticmethod
    def _dedupe_candidates(candidates: Iterable[str]) -> list[str]:
        return list(dict.fromkeys(candidate.strip() for candidate in candidates if candidate.strip()))

    def _score_forward_item(
        self,
        item: GeocodingSuggestionResponse,
        country_context: CountryContext,
        query: str,
        user_city: str | None = None,
    ) -> tuple[int, int, int, int, int]:
        precision_rank = {
            "exact": 5,
            "number": 4,
            "near": 3,
            "range": 2,
            "street": 1,
        }.get(item.precision, 0)
        country_match = (
            1
            if country_context.display_name and self._same_country(item.country, country_context.display_name)
            else 0
        )
        query_city_match = 1 if self._query_mentions_text(query, item.city) else 0
        profile_city_match = (
            1
            if user_city and self._cache_normalize(item.city) == self._cache_normalize(user_city)
            else 0
        )
        subtitle_non_empty = 1 if item.subtitle else 0
        return query_city_match, profile_city_match, country_match, precision_rank, subtitle_non_empty

    def _rank_forward_items(
        self,
        items: Iterable[GeocodingSuggestionResponse],
        country_context: CountryContext,
        query: str,
        user_city: str | None = None,
    ) -> list[GeocodingSuggestionResponse]:
        return sorted(
            items,
            key=lambda item: self._score_forward_item(item, country_context, query, user_city),
            reverse=True,
        )

    def _call_yandex_forward(self, query: str) -> list[GeocodingSuggestionResponse]:
        payload = self._call_yandex({
            "geocode": query,
            "results": str(max(YANDEX_GEOCODER_RESULTS_LIMIT, FORWARD_GEOCODE_SUGGESTION_LIMIT)),
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

    def _append_unique_items(
        self,
        target: list[GeocodingSuggestionResponse],
        seen_ids: set[str],
        items: Iterable[GeocodingSuggestionResponse],
    ) -> None:
        for item in items:
            if item.id in seen_ids:
                continue
            seen_ids.add(item.id)
            target.append(item)

    def _filter_cis_items(self, items: Iterable[GeocodingSuggestionResponse]) -> list[GeocodingSuggestionResponse]:
        return [item for item in items if self._is_cis_country_name(item.country)]

    def _filter_relevant_forward_items(
        self,
        items: Iterable[GeocodingSuggestionResponse],
        query: str,
    ) -> list[GeocodingSuggestionResponse]:
        return [item for item in items if self._item_matches_query(item, query)]

    def _query_city_items(
        self,
        items: Iterable[GeocodingSuggestionResponse],
        query: str,
    ) -> list[GeocodingSuggestionResponse]:
        return [item for item in items if self._query_mentions_text(query, item.city)]

    def _country_context_from_value(self, value: str, source: str) -> CountryContext:
        normalized = self._cache_normalize(value)
        mapped = COUNTRY_ALIASES.get(normalized)
        if mapped:
            return CountryContext(code=mapped[0], display_name=mapped[1], source=source)
        return CountryContext(code=None, display_name=value.strip(), source=source)

    def _is_cis_country_context(self, country: CountryContext) -> bool:
        return bool(country.code in CIS_COUNTRIES or self._is_cis_country_name(country.display_name or ""))

    def _is_cis_country_name(self, value: str) -> bool:
        normalized = self._cache_normalize(value)
        mapped = CIS_COUNTRY_ALIASES.get(normalized)
        return bool(mapped and mapped[0] in CIS_COUNTRIES)

    def _same_country(self, left: str, right: str) -> bool:
        left_context = self._country_context_from_value(left, "left")
        right_context = self._country_context_from_value(right, "right")
        if left_context.code and right_context.code:
            return left_context.code == right_context.code
        return self._cache_normalize(left) == self._cache_normalize(right)

    def _query_mentions_text(self, query: str, value: str) -> bool:
        normalized_value = self._cache_normalize(value)
        if not normalized_value:
            return False
        normalized_query = f" {self._cache_normalize(query)} "
        return f" {normalized_value} " in normalized_query

    def _item_matches_query(self, item: GeocodingSuggestionResponse, query: str) -> bool:
        tokens = self._cache_normalize(query).split()
        if not tokens:
            return True

        haystack = self._cache_normalize(
            " ".join(
                [
                    item.title,
                    item.subtitle,
                    item.fullAddress,
                    item.city,
                    item.country,
                ]
            )
        )
        words = haystack.split()

        for token in tokens:
            if len(token) <= 2:
                if not any(word.startswith(token) for word in words):
                    return False
                continue

            if token not in haystack and not any(word.startswith(token) for word in words):
                return False

        return True

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
