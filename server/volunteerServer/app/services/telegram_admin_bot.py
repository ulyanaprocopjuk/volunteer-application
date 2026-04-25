from __future__ import annotations

import asyncio
import certifi
import html
import json
import logging
import ssl
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from typing import Any
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import (
    TELEGRAM_ADMIN_IDS,
    TELEGRAM_BOT_TOKEN,
    TELEGRAM_POLL_INTERVAL_SECONDS,
)
from app.db import SessionLocal
from app.models import Event, EventAdminMessage, User
from app.services.notification_service import notification_service

logger = logging.getLogger(__name__)


class TelegramAdminBot:
    def __init__(self) -> None:
        self.token = TELEGRAM_BOT_TOKEN
        self.admin_ids = self._parse_admin_ids(TELEGRAM_ADMIN_IDS)
        self._offset = 0
        self._running = False

        # admin_telegram_id -> event_id
        self._pending_reject_reasons: dict[int, str] = {}

        # admin_telegram_id -> {"event_id": str, "reason": str}
        self._pending_reject_confirmations: dict[int, dict[str, str]] = {}

    @staticmethod
    def _parse_admin_ids(value: Any) -> set[int]:
        if not value:
            return set()

        if isinstance(value, int):
            return {value}

        if isinstance(value, str):
            value = value.replace(";", ",").split(",")

        admin_ids: set[int] = set()

        for item in value:
            item_str = str(item).strip()
            if not item_str:
                continue

            try:
                admin_ids.add(int(item_str))
            except ValueError:
                logger.warning("Invalid Telegram admin id skipped: %r", item)

        return admin_ids

    @property
    def is_configured(self) -> bool:
        return bool(self.token and self.admin_ids)

    async def run_polling(self) -> None:
        if not self.is_configured:
            logger.info(
                "Telegram admin bot is disabled: TELEGRAM_BOT_TOKEN or TELEGRAM_ADMIN_IDS is empty"
            )
            return

        self._running = True
        logger.info("Telegram admin bot polling started. Admin IDs: %s", self.admin_ids)

        while self._running:
            try:
                updates = await asyncio.to_thread(
                    self._api,
                    "getUpdates",
                    {
                        "offset": self._offset,
                        "timeout": 25,
                        "allowed_updates": json.dumps(["message", "callback_query"]),
                    },
                )

                for update in updates.get("result", []):
                    self._offset = max(self._offset, int(update["update_id"]) + 1)

                    message = update.get("message")
                    if message:
                        await self._handle_message(message)

                    callback = update.get("callback_query")
                    if callback:
                        await self._handle_callback(callback)

            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception("Telegram admin bot polling error")
                await asyncio.sleep(TELEGRAM_POLL_INTERVAL_SECONDS)

    def stop(self) -> None:
        self._running = False

    async def notify_admins_about_event(self, db: Session, event: Event, creator: User) -> None:
        if not self.is_configured:
            logger.info("Telegram notification skipped: bot is not configured")
            return

        text = self._event_text(event, creator)

        reply_markup = {
            "inline_keyboard": [
                [
                    {
                        "text": "✅ Подтвердить",
                        "callback_data": f"approve:{event.id}",
                    },
                    {
                        "text": "❌ Отклонить",
                        "callback_data": f"reject:{event.id}",
                    },
                ]
            ]
        }

        for admin_id in self.admin_ids:
            try:
                response = await asyncio.to_thread(
                    self._api,
                    "sendMessage",
                    {
                        "chat_id": admin_id,
                        "text": text,
                        "parse_mode": "HTML",
                        "reply_markup": json.dumps(reply_markup, ensure_ascii=False),
                    },
                )

                message_id = response["result"]["message_id"]

                db.add(
                    EventAdminMessage(
                        event_id=event.id,
                        chat_id=admin_id,
                        message_id=message_id,
                    )
                )

            except Exception:
                logger.exception("Failed to send Telegram admin message to %s", admin_id)

        db.commit()

    async def notify_admins_about_event_id(self, event_id: str) -> None:
        db = SessionLocal()

        try:
            event = db.get(Event, event_id)
            if event is None:
                logger.warning("Event not found for Telegram notification: %s", event_id)
                return

            creator = db.get(User, event.creator_id)
            if creator is None:
                logger.warning("Event creator not found for Telegram notification: %s", event.creator_id)
                return

            await self.notify_admins_about_event(db, event, creator)

        finally:
            db.close()

    async def _handle_callback(self, callback: dict[str, Any]) -> None:
        user_id = int(callback.get("from", {}).get("id", 0))
        callback_id = callback.get("id")
        data = callback.get("data", "")

        if user_id not in self.admin_ids:
            await asyncio.to_thread(self._answer_callback, callback_id, "Нет доступа")
            return

        try:
            action, event_id = data.split(":", 1)
        except ValueError:
            await asyncio.to_thread(self._answer_callback, callback_id, "Некорректная команда")
            return

        if action == "reject":
            self._pending_reject_reasons[user_id] = event_id
            self._pending_reject_confirmations.pop(user_id, None)

            await asyncio.to_thread(
                self._answer_callback,
                callback_id,
                "Введите причину отклонения сообщением в этот чат",
            )

            await asyncio.to_thread(
                self._send_message,
                user_id,
                "Напишите причину отклонения события одним сообщением.",
            )
            return

        if action == "confirm_reject":
            await self._confirm_reject(callback_id, user_id, event_id)
            return

        if action == "cancel_reject":
            self._pending_reject_reasons.pop(user_id, None)
            self._pending_reject_confirmations.pop(user_id, None)

            await asyncio.to_thread(self._answer_callback, callback_id, "Отклонение отменено")
            await asyncio.to_thread(self._send_message, user_id, "Отклонение отменено.")
            return

        if action == "approve":
            await self._approve_event(callback_id, event_id)
            return

        await asyncio.to_thread(self._answer_callback, callback_id, "Неизвестная команда")

    async def _approve_event(self, callback_id: str | None, event_id: str) -> None:
        db = SessionLocal()

        try:
            event = db.get(Event, event_id)

            if event is None:
                await asyncio.to_thread(self._answer_callback, callback_id, "Событие не найдено")
                return

            if event.status != "pending":
                await asyncio.to_thread(
                    self._answer_callback,
                    callback_id,
                    f"Уже обработано: {self._status_ru(event.status)}",
                )
                await self._remove_buttons_for_event(db, event, suffix=f"Заявка уже обработана: {self._status_ru(event.status)}")
                return

            event.status = "approved"
            event.reviewed_at = datetime.now(timezone.utc)

            notification_service.create(
                db,
                event.creator_id,
                "Ваше событие подтверждено.",
            )

            db.commit()

            result_text = "✅ Событие подтверждено"

            await asyncio.to_thread(self._answer_callback, callback_id, result_text)
            await self._remove_buttons_for_event(db, event, suffix=result_text)

        except Exception:
            db.rollback()
            logger.exception("Failed to approve Telegram event")
            await asyncio.to_thread(self._answer_callback, callback_id, "Ошибка сервера")

        finally:
            db.close()

    async def _confirm_reject(
        self,
        callback_id: str | None,
        admin_telegram_id: int,
        event_id: str,
    ) -> None:
        confirmation = self._pending_reject_confirmations.get(admin_telegram_id)

        if not confirmation or confirmation.get("event_id") != event_id:
            await asyncio.to_thread(
                self._answer_callback,
                callback_id,
                "Сначала введите причину отклонения",
            )
            return

        reason = confirmation["reason"]

        db = SessionLocal()

        try:
            event = db.get(Event, event_id)

            if event is None:
                await asyncio.to_thread(self._answer_callback, callback_id, "Событие не найдено")
                return

            if event.status != "pending":
                await asyncio.to_thread(
                    self._answer_callback,
                    callback_id,
                    f"Уже обработано: {self._status_ru(event.status)}",
                )
                await self._remove_buttons_for_event(db, event, suffix=f"Заявка уже обработана: {self._status_ru(event.status)}")
                return

            event.status = "rejected"
            event.reviewed_at = datetime.now(timezone.utc)

            notification_service.create(
                db,
                event.creator_id,
                f"Ваше событие отклонено. Причина: {reason}",
            )

            db.commit()

            self._pending_reject_reasons.pop(admin_telegram_id, None)
            self._pending_reject_confirmations.pop(admin_telegram_id, None)

            result_text = f"❌ Событие отклонено\n\n<b>Причина:</b> {html.escape(reason)}"

            await asyncio.to_thread(self._answer_callback, callback_id, "Событие отклонено")
            await self._remove_buttons_for_event(db, event, suffix=result_text)
            await self._send_result_message_to_all_admins(db, event, result_text)

        except Exception:
            db.rollback()
            logger.exception("Failed to reject Telegram event")
            await asyncio.to_thread(self._answer_callback, callback_id, "Ошибка сервера")

        finally:
            db.close()

    async def _remove_buttons_for_event(
        self,
        db: Session,
        event: Event,
        suffix: str | None = None,
    ) -> None:
        messages = db.scalars(
            select(EventAdminMessage).where(EventAdminMessage.event_id == event.id)
        ).all()

        creator = db.get(User, event.creator_id)

        if creator is not None:
            base_text = self._event_text(event, creator)
        else:
            base_text = "Событие"

        text = f"{base_text}\n\n<b>{suffix or 'Заявка уже обработана'}</b>"

        for message in messages:
            try:
                await asyncio.to_thread(
                    self._api,
                    "editMessageText",
                    {
                        "chat_id": message.chat_id,
                        "message_id": message.message_id,
                        "text": text,
                        "parse_mode": "HTML",
                        "reply_markup": json.dumps({"inline_keyboard": []}, ensure_ascii=False),
                    },
                )

            except Exception:
                logger.exception(
                    "Failed to edit Telegram admin message %s",
                    message.message_id,
                )

    async def _send_result_message_to_all_admins(
        self,
        db: Session,
        event: Event,
        result_text: str,
    ) -> None:
        creator = db.get(User, event.creator_id)

        if creator is not None:
            base_text = self._event_text(event, creator)
        else:
            base_text = "Событие"

        text = f"{base_text}\n\n<b>{result_text}</b>"

        for admin_id in self.admin_ids:
            try:
                await asyncio.to_thread(
                    self._send_message,
                    admin_id,
                    text,
                )
            except Exception:
                logger.exception("Failed to send result message to admin %s", admin_id)

    async def _handle_message(self, message: dict[str, Any]) -> None:
        chat = message.get("chat", {})
        chat_id = chat.get("id")

        user_id = int(message.get("from", {}).get("id", 0))
        text = message.get("text", "")

        if not chat_id:
            return

        if user_id not in self.admin_ids:
            await asyncio.to_thread(self._send_message, chat_id, "Нет доступа")
            return

        if user_id in self._pending_reject_reasons:
            event_id = self._pending_reject_reasons[user_id]
            reason = text.strip()

            if not reason:
                await asyncio.to_thread(
                    self._send_message,
                    chat_id,
                    "Причина не может быть пустой. Введите причину отклонения.",
                )
                return

            self._pending_reject_confirmations[user_id] = {
                "event_id": event_id,
                "reason": reason,
            }

            reply_markup = {
                "inline_keyboard": [
                    [
                        {
                            "text": "❌ Отклонить событие",
                            "callback_data": f"confirm_reject:{event_id}",
                        }
                    ],
                    [
                        {
                            "text": "Отмена",
                            "callback_data": f"cancel_reject:{event_id}",
                        }
                    ],
                ]
            }

            db = SessionLocal()

            try:
                event = db.get(Event, event_id)
                creator = db.get(User, event.creator_id) if event else None

                if event is not None and creator is not None:
                    event_text = self._event_text(event, creator)
                else:
                    event_text = "Событие"

                response_text = (
                    f"{event_text}\n\n"
                    f"<b>Причина отклонения:</b>\n{html.escape(reason)}\n\n"
                    f"Нажмите кнопку ниже, чтобы окончательно отклонить событие."
                )

                await asyncio.to_thread(
                    self._api,
                    "sendMessage",
                    {
                        "chat_id": chat_id,
                        "text": response_text,
                        "parse_mode": "HTML",
                        "reply_markup": json.dumps(reply_markup, ensure_ascii=False),
                    },
                )

            finally:
                db.close()

            return

        now = datetime.now(ZoneInfo("Europe/Minsk"))
        time_text = now.strftime("%d.%m.%Y %H:%M:%S")

        if text == "/time":
            response_text = f"Текущее время: {time_text}"
        else:
            response_text = "Неизвестная команда."

        await asyncio.to_thread(self._send_message, chat_id, response_text)

    def _api(self, method: str, payload: dict[str, Any]) -> dict[str, Any]:
        url = f"https://api.telegram.org/bot{self.token}/{method}"

        data = urllib.parse.urlencode(payload).encode("utf-8")
        request = urllib.request.Request(url, data=data, method="POST")

        context = ssl.create_default_context(cafile=certifi.where())

        with urllib.request.urlopen(request, timeout=35, context=context) as response:
            body = json.loads(response.read().decode("utf-8"))

        if not body.get("ok"):
            raise RuntimeError(body)

        return body

    def _answer_callback(self, callback_id: str | None, text: str) -> None:
        if not callback_id:
            return

        self._api(
            "answerCallbackQuery",
            {
                "callback_query_id": callback_id,
                "text": text,
                "show_alert": False,
            },
        )

    def _send_message(self, chat_id: int | str, text: str) -> None:
        self._api(
            "sendMessage",
            {
                "chat_id": chat_id,
                "text": text,
                "parse_mode": "HTML",
            },
        )

    @staticmethod
    def _safe(value: Any) -> str:
        if value is None:
            return ""
        return html.escape(str(value))

    @staticmethod
    def _format_datetime(value: Any) -> str:
        if value is None:
            return "не указано"

        if isinstance(value, str):
            try:
                value = datetime.fromisoformat(value.replace("Z", "+00:00"))
            except ValueError:
                return value[:16].replace("T", " ")

        if isinstance(value, datetime):
            return value.strftime("%Y-%m-%d %H:%M")

        return str(value)

    @staticmethod
    def _status_ru(status: str | None) -> str:
        statuses = {
            "pending": "Ожидает подтверждения",
            "approved": "Подтверждено",
            "rejected": "Отклонено",
        }
        return statuses.get(status or "", status or "")

    @classmethod
    def _event_text(cls, event: Event, creator: User) -> str:
        title = cls._safe(event.title)
        description = cls._safe(event.description)
        location_name = cls._safe(event.location_name)
        city = cls._safe(event.city)
        country = cls._safe(event.country)
        username = cls._safe(creator.username)

        starts_at = cls._format_datetime(event.starts_at)
        ends_at = cls._format_datetime(event.ends_at)

        latitude = cls._safe(event.latitude)
        longitude = cls._safe(event.longitude)

        return (
            "<b>Новое событие на подтверждение</b>\n\n"
            f"Пользователь: {username}\n"
            f"Название: {title}\n"
            f"Описание: {description}\n"
            f"Место: {location_name}, {city}, {country}\n"
            f"Координаты: {latitude}, {longitude}\n"
            f"Начало: {starts_at}\n"
            f"Конец: {ends_at}\n"
            f"Волонтёров нужно: {cls._safe(event.volunteers_needed)}"
        )


telegram_admin_bot = TelegramAdminBot()