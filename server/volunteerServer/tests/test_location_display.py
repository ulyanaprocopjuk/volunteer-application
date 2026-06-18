import unittest

from app.services.location_display import build_location_display


class LocationDisplayTests(unittest.TestCase):
    def test_does_not_append_city_country_to_full_address(self):
        self.assertEqual(
            build_location_display(
                "Беларусь, Минская область, Борисов, улица Галицкого",
                "Минск",
                "Беларусь",
            ),
            "Беларусь, Минская область, Борисов, улица Галицкого",
        )

    def test_appends_city_country_to_place_name(self):
        self.assertEqual(
            build_location_display("Парк Челюскинцев", "Минск", "Беларусь"),
            "Парк Челюскинцев, Минск, Беларусь",
        )


if __name__ == "__main__":
    unittest.main()
