from __future__ import annotations

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models import Notification, User


class NotificationService:
    def create(self, db: Session, user_id: int, message: str, sender_name: str = "РђРґРјРёРЅРёСЃС‚СЂР°С†РёСЏ") -> Notification:
        notification = Notification(user_id=user_id, message=message, sender_name=sender_name)
        db.add(notification)
        return notification

    def list_for_user(self, db: Session, user: User) -> list[Notification]:
        return list(
            db.scalars(
                select(Notification)
                .where(Notification.user_id == user.id)
                .order_by(Notification.created_at.desc())
            ).all()
        )

    def clear_for_user(self, db: Session, user: User) -> None:
        db.execute(delete(Notification).where(Notification.user_id == user.id))
        db.commit()


notification_service = NotificationService()
