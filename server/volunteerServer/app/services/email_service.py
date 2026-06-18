from __future__ import annotations

import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.config import (
    SMTP_FROM_EMAIL,
    SMTP_FROM_NAME,
    SMTP_HOST,
    SMTP_PASSWORD,
    SMTP_PORT,
    SMTP_USERNAME,
)

logger = logging.getLogger(__name__)


def _send_email(to_email: str, subject: str, html_body: str) -> None:
    if not SMTP_USERNAME or not SMTP_PASSWORD:
        logger.warning("SMTP not configured — skipping email to %s: %s", to_email, subject)
        return

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{SMTP_FROM_NAME} <{SMTP_FROM_EMAIL or SMTP_USERNAME}>"
    msg["To"] = to_email
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as server:
            server.ehlo()
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.sendmail(SMTP_FROM_EMAIL or SMTP_USERNAME, [to_email], msg.as_string())
    except Exception:
        logger.exception("Failed to send email to %s", to_email)


def send_verification_code(to_email: str, code: str) -> None:
    subject = "Подтвердите почту"
    html_body = f"""
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
        <h2 style="color: #2c4366;">Подтверждение почты</h2>
        <p>Ваш код подтверждения:</p>
        <div style="font-size: 36px; font-weight: bold; letter-spacing: 8px;
                    background: #f4f6fb; padding: 20px; border-radius: 12px;
                    text-align: center; color: #2c4366;">
            {code}
        </div>
        <p style="color: #666; margin-top: 16px;">Код действует 15 минут.</p>
    </div>
    """
    _send_email(to_email, subject, html_body)


def send_password_reset_code(to_email: str, code: str) -> None:
    subject = "Сброс пароля"
    html_body = f"""
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
        <h2 style="color: #2c4366;">Сброс пароля</h2>
        <p>Ваш код для сброса пароля:</p>
        <div style="font-size: 36px; font-weight: bold; letter-spacing: 8px;
                    background: #f4f6fb; padding: 20px; border-radius: 12px;
                    text-align: center; color: #2c4366;">
            {code}
        </div>
        <p style="color: #666; margin-top: 16px;">Код действует 60 минут.</p>
        <p style="color: #666; font-size: 13px;">
            Если вы не запрашивали сброс пароля — просто проигнорируйте это письмо.
        </p>
    </div>
    """
    _send_email(to_email, subject, html_body)
