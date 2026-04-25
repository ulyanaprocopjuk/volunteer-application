from __future__ import annotations

import asyncio
import certifi
import html
import json
import logging
import ssl
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from time import monotonic
from typing import Any
from zoneinfo import ZoneInfo

from sqlalchemy import select, update
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
EVENT_MODERATION_LOCK_TTL_SECONDS = 15 * 60


class TelegramAPIError(RuntimeError):
    def __init__(self, body: dict[str, Any]) -> None:
        self.body = body
        self.error_code = body.get("error_code")
        self.description = str(body.get("description", body))
        super().__init__(self.description)


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

        # event_id -> (admin_telegram_id, expires_at)
        self._event_locks: dict[str, tuple[int, float]] = {}

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
            await self._safe_answer_callback(callback_id, "Нет доступа")
            return

        try:
            action, event_id = data.split(":", 1)
        except ValueError:
            await self._safe_answer_callback(callback_id, "Некорректная команда")
            return

        if action == "reject":
            if not self._try_lock_event(event_id, user_id):
                await self._safe_answer_callback(callback_id, "Событие уже обрабатывает другой админ")
                return

            if not await self._ensure_event_is_pending(callback_id, event_id, lock_owner=user_id):
                return

            self._pending_reject_reasons[user_id] = event_id
            self._pending_reject_confirmations.pop(user_id, None)

            await self._safe_answer_callback(
                callback_id,
                "Введите причину отклонения сообщением в этот чат",
            )

            await self._safe_send_message(
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
            self._release_event_lock(event_id, user_id)

            await self._safe_answer_callback(callback_id, "Отклонение отменено")
            await self._safe_send_message(user_id, "Отклонение отменено.")
            return

        if action == "approve":
            if not self._try_lock_event(event_id, user_id):
                await self._safe_answer_callback(callback_id, "Событие уже обрабатывает другой админ")
                return

            try:
                await self._approve_event(callback_id, event_id)
            finally:
                self._release_event_lock(event_id, user_id)
            return

        await self._safe_answer_callback(callback_id, "Неизвестная команда")

    async def _approve_event(self, callback_id: str | None, event_id: str) -> None:
        db = SessionLocal()

        try:
            reviewed_at = datetime.now(timezone.utc)
            result = db.execute(
                update(Event)
                .where(Event.id == event_id, Event.status == "pending")
                .values(status="approved", reviewed_at=reviewed_at)
            )

            if result.rowcount != 1:
                db.rollback()
                event = db.get(Event, event_id)
                if event is None:
                    await self._safe_answer_callback(callback_id, "Событие не найдено")
                    return

                await self._handle_already_processed(db, callback_id, event)
                return

            event = db.get(Event, event_id)
            if event is None:
                db.rollback()
                await self._safe_answer_callback(callback_id, "Событие не найдено")
                return

            notification_service.create(
                db,
                event.creator_id,
                "Ваше событие подтверждено.",
            )

            db.commit()

            result_text = "✅ Событие подтверждено"

            self._clear_pending_rejects_for_event(event_id)
            await self._safe_answer_callback(callback_id, result_text)
            await self._remove_buttons_for_event(db, event, suffix=result_text)

        except Exception:
            db.rollback()
            logger.exception("Failed to approve Telegram event")
            await self._safe_answer_callback(callback_id, "Ошибка сервера")

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
            await self._safe_answer_callback(callback_id, "Сначала введите причину отклонения")
            return

        if not self._try_lock_event(event_id, admin_telegram_id):
            await self._safe_answer_callback(callback_id, "Событие уже обрабатывает другой админ")
            return

        reason = confirmation["reason"]

        await self._reject_event(
            event_id=event_id,
            reason=reason,
            admin_telegram_id=admin_telegram_id,
            callback_id=callback_id,
        )

    async def _reject_event(
        self,
        *,
        event_id: str,
        reason: str,
        admin_telegram_id: int,
        callback_id: str | None = None,
        chat_id: int | str | None = None,
    ) -> None:
        db = SessionLocal()

        try:
            reviewed_at = datetime.now(timezone.utc)
            result = db.execute(
                update(Event)
                .where(Event.id == event_id, Event.status == "pending")
                .values(status="rejected", reviewed_at=reviewed_at)
            )

            if result.rowcount != 1:
                db.rollback()
                event = db.get(Event, event_id)
                if event is None:
                    self._release_event_lock(event_id, admin_telegram_id)
                    self._clear_pending_rejects_for_event(event_id)
                    await self._safe_answer_callback(callback_id, "Событие не найдено")
                    if chat_id is not None:
                        await self._safe_send_message(chat_id, "Событие не найдено.")
                    return

                await self._handle_already_processed(db, callback_id, event, chat_id=chat_id)
                return

            event = db.get(Event, event_id)
            if event is None:
                db.rollback()
                self._release_event_lock(event_id, admin_telegram_id)
                self._clear_pending_rejects_for_event(event_id)
                await self._safe_answer_callback(callback_id, "Событие не найдено")
                if chat_id is not None:
                    await self._safe_send_message(chat_id, "Событие не найдено.")
                return

            notification_service.create(
                db,
                event.creator_id,
                f"Ваше событие отклонено. Причина: {reason}",
            )

            db.commit()

            result_text = f"❌ Событие отклонено\n\n<b>Причина:</b> {html.escape(reason)}"

            self._clear_pending_rejects_for_event(event_id)
            self._release_event_lock(event_id, admin_telegram_id)

            await self._safe_answer_callback(callback_id, "Событие отклонено")
            await self._remove_buttons_for_event(db, event, suffix=result_text)
            if chat_id is not None:
                await self._safe_send_message(chat_id, "Событие отклонено.")

        except Exception:
            db.rollback()
            self._release_event_lock(event_id, admin_telegram_id)
            logger.exception("Failed to reject Telegram event")
            await self._safe_answer_callback(callback_id, "Ошибка сервера")
            if chat_id is not None:
                await self._safe_send_message(chat_id, "Ошибка сервера.")

        finally:
            db.close()

    async def _send_reject_confirmation(
        self,
        chat_id: int | str,
        event_id: str,
        reason: str,
    ) -> None:
        reply_markup = {
            "inline_keyboard": [
                [
                    {
                        "text": "✅ Отклонить",
                        "callback_data": f"confirm_reject:{event_id}",
                    },
                    {
                        "text": "↩️ Отмена",
                        "callback_data": f"cancel_reject:{event_id}",
                    },
                ]
            ]
        }
        text = (
            "Подтвердите отклонение события.\n\n"
            f"<b>Причина:</b> {html.escape(reason)}"
        )

        await self._safe_send_message_with_markup(chat_id, text, reply_markup)

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

        suffix_text = suffix or "<b>Заявка уже обработана</b>"
        if "<" not in suffix_text:
            suffix_text = f"<b>{html.escape(suffix_text)}</b>"

        text = f"{base_text}\n\n{suffix_text}"

        for message in messages:
            try:
                await self._safe_api(
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

    async def _handle_message(self, message: dict[str, Any]) -> None:
        chat = message.get("chat", {})
        chat_id = chat.get("id")

        user_id = int(message.get("from", {}).get("id", 0))
        text = message.get("text", "")

        if not chat_id:
            return

        if user_id not in self.admin_ids:
            await self._safe_send_message(chat_id, "Нет доступа")
            return

        if user_id in self._pending_reject_reasons:
            event_id = self._pending_reject_reasons[user_id]
            reason = text.strip()

            if not reason:
                await self._safe_send_message(
                    chat_id,
                    "Причина не может быть пустой. Введите причину отклонения.",
                )
                return

            self._pending_reject_confirmations[user_id] = {
                "event_id": event_id,
                "reason": reason,
            }

            if not self._try_lock_event(event_id, user_id):
                self._pending_reject_reasons.pop(user_id, None)
                self._pending_reject_confirmations.pop(user_id, None)
                await self._safe_send_message(chat_id, "Событие уже обрабатывает другой админ.")
                return

            await self._send_reject_confirmation(chat_id, event_id, reason)

            return

        now = datetime.now(ZoneInfo("Europe/Minsk"))
        time_text = now.strftime("%d.%m.%Y %H:%M:%S")

        if text == "/time":
            response_text = f"Текущее время: {time_text}"
        else:
            response_text = "Неизвестная команда."

        await self._safe_send_message(chat_id, response_text)

    async def _ensure_event_is_pending(
        self,
        callback_id: str | None,
        event_id: str,
        *,
        lock_owner: int | None = None,
    ) -> bool:
        db = SessionLocal()

        try:
            event = db.get(Event, event_id)
            if event is None:
                if lock_owner is not None:
                    self._release_event_lock(event_id, lock_owner)
                await self._safe_answer_callback(callback_id, "Событие не найдено")
                return False

            if event.status != "pending":
                if lock_owner is not None:
                    self._release_event_lock(event_id, lock_owner)
                await self._handle_already_processed(db, callback_id, event)
                return False

            return True

        finally:
            db.close()

    async def _handle_already_processed(
        self,
        db: Session,
        callback_id: str | None,
        event: Event,
        *,
        chat_id: int | str | None = None,
    ) -> None:
        status_text = self._status_ru(event.status)
        await self._safe_answer_callback(callback_id, f"Уже обработано: {status_text}")
        await self._remove_buttons_for_event(db, event, suffix=f"Заявка уже обработана: {status_text}")
        self._clear_pending_rejects_for_event(event.id)
        self._release_event_lock(event.id)

        if chat_id is not None:
            await self._safe_send_message(chat_id, f"Событие уже обработано: {status_text}.")

    def _try_lock_event(self, event_id: str, admin_telegram_id: int) -> bool:
        owner = self._active_lock_owner(event_id)
        if owner is not None and owner != admin_telegram_id:
            return False

        self._event_locks[event_id] = (
            admin_telegram_id,
            monotonic() + EVENT_MODERATION_LOCK_TTL_SECONDS,
        )
        return True

    def _release_event_lock(self, event_id: str, admin_telegram_id: int | None = None) -> None:
        owner = self._active_lock_owner(event_id)
        if owner is None:
            return
        if admin_telegram_id is not None and owner != admin_telegram_id:
            return
        self._event_locks.pop(event_id, None)

    def _active_lock_owner(self, event_id: str) -> int | None:
        lock = self._event_locks.get(event_id)
        if lock is None:
            return None

        owner, expires_at = lock
        if expires_at <= monotonic():
            self._event_locks.pop(event_id, None)
            return None

        return owner

    def _clear_pending_rejects_for_event(self, event_id: str) -> None:
        for admin_id, pending_event_id in list(self._pending_reject_reasons.items()):
            if pending_event_id == event_id:
                self._pending_reject_reasons.pop(admin_id, None)

        for admin_id, confirmation in list(self._pending_reject_confirmations.items()):
            if confirmation.get("event_id") == event_id:
                self._pending_reject_confirmations.pop(admin_id, None)

    async def _safe_answer_callback(self, callback_id: str | None, text: str) -> None:
        try:
            await asyncio.to_thread(self._answer_callback, callback_id, text)
        except Exception:
            logger.exception("Failed to answer Telegram callback")

    async def _safe_send_message(self, chat_id: int | str, text: str) -> None:
        try:
            await asyncio.to_thread(self._send_message, chat_id, text)
        except Exception:
            logger.exception("Failed to send Telegram message to %s", chat_id)

    async def _safe_send_message_with_markup(
        self,
        chat_id: int | str,
        text: str,
        reply_markup: dict[str, Any],
    ) -> None:
        try:
            await asyncio.to_thread(self._send_message, chat_id, text, reply_markup)
        except Exception:
            logger.exception("Failed to send Telegram message to %s", chat_id)

    async def _safe_api(self, method: str, payload: dict[str, Any]) -> dict[str, Any] | None:
        try:
            return await asyncio.to_thread(self._api, method, payload)
        except TelegramAPIError as exc:
            if method == "editMessageText" and "message is not modified" in exc.description.lower():
                return None
            logger.exception("Telegram API call failed: %s", method)
            return None
        except Exception:
            logger.exception("Telegram API call failed: %s", method)
            return None

    def _api(self, method: str, payload: dict[str, Any]) -> dict[str, Any]:
        url = f"https://api.telegram.org/bot{self.token}/{method}"

        data = urllib.parse.urlencode(payload).encode("utf-8")
        request = urllib.request.Request(url, data=data, method="POST")

        context = ssl.create_default_context(cafile=certifi.where())

        try:
            with urllib.request.urlopen(request, timeout=35, context=context) as response:
                body = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            raw_body = exc.read().decode("utf-8", errors="replace")
            try:
                body = json.loads(raw_body)
            except json.JSONDecodeError:
                body = {
                    "ok": False,
                    "error_code": exc.code,
                    "description": raw_body or str(exc),
                }
            raise TelegramAPIError(body) from exc

        if not body.get("ok"):
            raise TelegramAPIError(body)

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

    def _send_message(
        self,
        chat_id: int | str,
        text: str,
        reply_markup: dict[str, Any] | None = None,
    ) -> None:
        payload = {
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "HTML",
        }
        if reply_markup is not None:
            payload["reply_markup"] = json.dumps(reply_markup, ensure_ascii=False)

        self._api("sendMessage", payload)

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
