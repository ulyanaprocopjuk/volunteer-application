import unittest

from app.services.telegram_admin_bot import TelegramAPIError, TelegramAdminBot


class TelegramAdminBotTests(unittest.TestCase):
    def setUp(self):
        self.bot = TelegramAdminBot()

    def test_event_lock_allows_only_one_admin(self):
        self.assertTrue(self.bot._try_lock_event("event-1", 100))
        self.assertFalse(self.bot._try_lock_event("event-1", 200))
        self.assertTrue(self.bot._try_lock_event("event-1", 100))

        self.bot._release_event_lock("event-1", 100)

        self.assertTrue(self.bot._try_lock_event("event-1", 200))

    def test_expired_event_lock_can_be_taken_by_another_admin(self):
        self.bot._event_locks["event-1"] = (100, 0.0)

        self.assertTrue(self.bot._try_lock_event("event-1", 200))

    def test_clear_pending_rejects_for_event(self):
        self.bot._pending_reject_reasons = {
            100: "event-1",
            200: "event-2",
        }
        self.bot._pending_reject_confirmations = {
            100: {"event_id": "event-1", "reason": "bad"},
            200: {"event_id": "event-2", "reason": "other"},
        }

        self.bot._clear_pending_rejects_for_event("event-1")

        self.assertNotIn(100, self.bot._pending_reject_reasons)
        self.assertNotIn(100, self.bot._pending_reject_confirmations)
        self.assertIn(200, self.bot._pending_reject_reasons)
        self.assertIn(200, self.bot._pending_reject_confirmations)

    def test_telegram_api_error_keeps_description(self):
        error = TelegramAPIError(
            {
                "ok": False,
                "error_code": 400,
                "description": "Bad Request: query is too old",
            }
        )

        self.assertEqual(error.error_code, 400)
        self.assertEqual(error.description, "Bad Request: query is too old")


class TelegramAdminBotAsyncTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.bot = TelegramAdminBot()
        self.bot.admin_ids = {100}

    async def test_reject_reason_waits_for_confirmation(self):
        confirmations = []
        rejects = []

        async def fake_send_confirmation(chat_id, event_id, reason):
            confirmations.append((chat_id, event_id, reason))

        async def fake_reject_event(**kwargs):
            rejects.append(kwargs)

        self.bot._pending_reject_reasons[100] = "event-1"
        self.bot._send_reject_confirmation = fake_send_confirmation
        self.bot._reject_event = fake_reject_event

        await self.bot._handle_message(
            {
                "chat": {"id": 100},
                "from": {"id": 100},
                "text": "Не подходит дата",
            }
        )

        self.assertEqual(confirmations, [(100, "event-1", "Не подходит дата")])
        self.assertEqual(rejects, [])
        self.assertEqual(
            self.bot._pending_reject_confirmations[100],
            {"event_id": "event-1", "reason": "Не подходит дата"},
        )


if __name__ == "__main__":
    unittest.main()
