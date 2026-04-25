import unittest

from sqlalchemy import create_engine, text

from app.db_schema import ensure_database_schema
from app.notification_text import (
    DEFAULT_NOTIFICATION_SENDER_NAME,
    LEGACY_MOJIBAKE_NOTIFICATION_SENDER_NAME,
    normalize_notification_sender_name,
)
from app.services.notification_service import NotificationService


class NotificationEncodingTests(unittest.TestCase):
    def test_normalizes_legacy_sender_name(self):
        self.assertEqual(
            normalize_notification_sender_name(LEGACY_MOJIBAKE_NOTIFICATION_SENDER_NAME),
            DEFAULT_NOTIFICATION_SENDER_NAME,
        )

    def test_create_normalizes_sender_name(self):
        notification = NotificationService().create(
            db=FakeSession(),
            user_id=1,
            message="Тест",
            sender_name=LEGACY_MOJIBAKE_NOTIFICATION_SENDER_NAME,
        )

        self.assertEqual(notification.sender_name, DEFAULT_NOTIFICATION_SENDER_NAME)

    def test_schema_helper_repairs_existing_notifications(self):
        engine = create_engine("sqlite:///:memory:")
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE notifications ("
                    "id INTEGER PRIMARY KEY, "
                    "sender_name VARCHAR(100) NOT NULL"
                    ")"
                )
            )
            connection.execute(
                text("INSERT INTO notifications (id, sender_name) VALUES (1, :sender_name)"),
                {"sender_name": LEGACY_MOJIBAKE_NOTIFICATION_SENDER_NAME},
            )

        ensure_database_schema(engine)

        with engine.connect() as connection:
            sender_name = connection.execute(
                text("SELECT sender_name FROM notifications WHERE id = 1")
            ).scalar_one()

        self.assertEqual(sender_name, DEFAULT_NOTIFICATION_SENDER_NAME)


class FakeSession:
    def __init__(self):
        self.items = []

    def add(self, item):
        self.items.append(item)


if __name__ == "__main__":
    unittest.main()
