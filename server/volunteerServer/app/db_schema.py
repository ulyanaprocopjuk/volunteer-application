from __future__ import annotations

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

from app.notification_text import (
    DEFAULT_NOTIFICATION_SENDER_NAME,
    LEGACY_MOJIBAKE_NOTIFICATION_SENDER_NAME,
)


def ensure_database_schema(engine: Engine) -> None:
    """Small compatibility helper for projects without Alembic migrations."""
    inspector = inspect(engine)
    table_names = inspector.get_table_names()
    if "notifications" in table_names:
        with engine.begin() as connection:
            connection.execute(
                text(
                    "UPDATE notifications "
                    "SET sender_name = :correct "
                    "WHERE sender_name = :broken"
                ),
                {
                    "correct": DEFAULT_NOTIFICATION_SENDER_NAME,
                    "broken": LEGACY_MOJIBAKE_NOTIFICATION_SENDER_NAME,
                },
            )
            if engine.dialect.name == "postgresql":
                sender_name_default = DEFAULT_NOTIFICATION_SENDER_NAME.replace("'", "''")
                connection.execute(
                    text(
                        "ALTER TABLE notifications "
                        "ALTER COLUMN sender_name "
                        f"SET DEFAULT '{sender_name_default}'"
                    )
                )

    if "events" not in table_names:
        return

    columns = {column["name"] for column in inspector.get_columns("events")}
    statements: list[str] = []
    dialect = engine.dialect.name

    if "status" not in columns:
        statements.append("ALTER TABLE events ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'approved'")
    if "photo_url" not in columns:
        statements.append("ALTER TABLE events ADD COLUMN photo_url VARCHAR(500) NULL")
    if "reviewed_by" not in columns:
        statements.append("ALTER TABLE events ADD COLUMN reviewed_by INTEGER NULL")
    if "reviewed_at" not in columns:
        column_type = "TIMESTAMP WITH TIME ZONE" if dialect == "postgresql" else "DATETIME"
        statements.append(f"ALTER TABLE events ADD COLUMN reviewed_at {column_type} NULL")

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))
