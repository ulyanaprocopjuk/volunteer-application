from __future__ import annotations

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models import Notification, User
from app.notification_text import (
    DEFAULT_NOTIFICATION_SENDER_NAME,
    normalize_notification_sender_name,
)


class NotificationService:
    def create(
        self,
        db: Session,
        user_id: int,
        message: str,
        sender_name: str = DEFAULT_NOTIFICATION_SENDER_NAME,
    ) -> Notification:
        notification = Notification(
            user_id=user_id,
            message=message,
            sender_name=normalize_notification_sender_name(sender_name),
        )
        db.add(notification)
        return notification

    def list_for_user(self, db: Session, user: User) -> list[Notification]:
        notifications = list(
            db.scalars(
                select(Notification)
                .where(Notification.user_id == user.id)
                .order_by(Notification.created_at.desc())
            ).all()
        )
        changed = False
        for notification in notifications:
            normalized_sender_name = normalize_notification_sender_name(notification.sender_name)
            if normalized_sender_name != notification.sender_name:
                notification.sender_name = normalized_sender_name
                changed = True

        if changed:
            db.commit()

        return notifications

    def clear_for_user(self, db: Session, user: User) -> None:
        db.execute(delete(Notification).where(Notification.user_id == user.id))
        db.commit()


notification_service = NotificationService()
