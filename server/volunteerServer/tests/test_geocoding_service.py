import unittest

from app.services.geocoding_service import CountryContext, GeocodingService


class GeocodingServiceTests(unittest.TestCase):
    def setUp(self):
        self.service = GeocodingService()

    def test_detects_explicit_country_from_query(self):
        result = self.service._detect_explicit_country("Main street 1, Poland")
        self.assertIsNotNone(result)
        self.assertEqual(result.code, "PL")
        self.assertEqual(result.source, "query")

    def test_builds_country_biased_candidate_queries(self):
        context = CountryContext(code="BY", display_name="Беларусь", source="profile")
        result = self.service._build_forward_candidate_queries("Минск Независимости 95", context, False)
        self.assertEqual(result[0], "Минск Независимости 95, Беларусь")
        self.assertEqual(result[1], "Минск Независимости 95")


if __name__ == "__main__":
    unittest.main()
