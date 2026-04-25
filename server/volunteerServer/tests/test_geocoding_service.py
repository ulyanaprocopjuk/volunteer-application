import unittest

from fastapi import HTTPException

from app.schemas import GeocodingSuggestionResponse
from app.services.geocoding_service import (
    CountryContext,
    GeocodingService,
    forward_cache,
    reverse_cache,
)


def make_item(
    item_id: str,
    *,
    country: str = "Беларусь",
    city: str = "Минск",
    precision: str = "exact",
) -> GeocodingSuggestionResponse:
    return GeocodingSuggestionResponse(
        id=item_id,
        title=f"{city} location",
        subtitle=city,
        fullAddress=f"{city}, {country}",
        latitude=53.9,
        longitude=27.56,
        precision=precision,
        country=country,
        city=city,
    )


class GeocodingServiceTests(unittest.TestCase):
    def setUp(self):
        forward_cache.clear()
        reverse_cache.clear()
        self.service = GeocodingService()

    def test_detects_explicit_country_from_query(self):
        result = self.service._detect_explicit_country("Main street 1, Kazakhstan")
        self.assertIsNotNone(result)
        self.assertEqual(result.code, "KZ")
        self.assertEqual(result.source, "query")

    def test_builds_country_biased_candidate_queries(self):
        context = CountryContext(code="BY", display_name="Беларусь", source="profile")
        result = self.service._build_forward_candidate_queries("улица Ленина 5", context, False, user_city="Минск")
        self.assertEqual(result[0], "улица Ленина 5, Минск, Беларусь")
        self.assertEqual(result[1], "улица Ленина 5, Беларусь")
        self.assertIn("улица Ленина 5, Россия", result)

    def test_rejects_explicit_non_cis_country(self):
        with self.assertRaises(HTTPException) as exc:
            self.service.forward_geocode(None, None, "Main street 1, Poland")

        self.assertEqual(exc.exception.status_code, 400)

    def test_forward_filters_non_cis_items_and_limits_to_three(self):
        def fake_forward(query: str) -> list[GeocodingSuggestionResponse]:
            if query == "Ленина":
                return [make_item("pl-raw", country="Польша", city="Варшава")]
            return [
                make_item("by-1"),
                make_item("by-2"),
                make_item("ru-1", country="Россия", city="Москва"),
                make_item("pl-1", country="Польша", city="Варшава"),
            ]

        self.service._call_yandex_forward = fake_forward

        response = self.service.forward_geocode(None, None, "Ленина")

        self.assertEqual(len(response.items), 3)
        self.assertEqual([item.country for item in response.items], ["Беларусь", "Беларусь", "Россия"])

    def test_query_city_scores_above_profile_city(self):
        context = CountryContext(code="BY", display_name="Беларусь", source="profile")
        explicit_city_score = self.service._score_forward_item(
            make_item("grodno", city="Гродно"),
            context,
            "Гродно Ленина 5",
            "Минск",
        )
        profile_city_score = self.service._score_forward_item(
            make_item("minsk", city="Минск"),
            context,
            "Гродно Ленина 5",
            "Минск",
        )

        self.assertGreater(explicit_city_score, profile_city_score)

    def test_reverse_rejects_coordinates_outside_cis(self):
        self.service._call_yandex_reverse = lambda latitude, longitude: [
            make_item("pl-reverse", country="Польша", city="Варшава")
        ]

        with self.assertRaises(HTTPException) as exc:
            self.service.reverse_geocode(latitude=52.23, longitude=21.01)

        self.assertEqual(exc.exception.status_code, 400)


if __name__ == "__main__":
    unittest.main()
