import unittest
from datetime import datetime, timezone

from pydantic import ValidationError

from app.schemas.events import CreateEventRequest


class EventSchemaTests(unittest.TestCase):
    def test_accepts_valid_payload(self):
        payload = CreateEventRequest.model_validate(
            {
                "title": "Cleanup",
                "direction": "Экология",
                "description": "Park cleanup",
                "country": "Беларусь",
                "city": "Минск",
                "locationName": "Парк Челюскинцев",
                "latitude": 53.92,
                "longitude": 27.63,
                "startsAt": datetime(2026, 4, 23, 10, 0, tzinfo=timezone.utc).isoformat(),
                "endsAt": datetime(2026, 4, 23, 12, 0, tzinfo=timezone.utc).isoformat(),
                "volunteersNeeded": 10,
            }
        )
        self.assertEqual(payload.location_name, "Парк Челюскинцев")

    def test_rejects_invalid_date_range(self):
        with self.assertRaises(ValidationError):
            CreateEventRequest.model_validate(
                {
                    "title": "Cleanup",
                    "direction": "Экология",
                    "description": "Park cleanup",
                    "country": "Беларусь",
                    "city": "Минск",
                    "locationName": "Парк Челюскинцев",
                    "latitude": 53.92,
                    "longitude": 27.63,
                    "startsAt": datetime(2026, 4, 23, 12, 0, tzinfo=timezone.utc).isoformat(),
                    "endsAt": datetime(2026, 4, 23, 10, 0, tzinfo=timezone.utc).isoformat(),
                    "volunteersNeeded": 10,
                }
            )


if __name__ == "__main__":
    unittest.main()
