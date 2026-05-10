from __future__ import annotations

import json

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

from app.notification_text import (
    DEFAULT_NOTIFICATION_SENDER_NAME,
    LEGACY_MOJIBAKE_NOTIFICATION_SENDER_NAME,
)

DIRECTION_NAMES = [
    "Животные",
    "Экология",
    "Пожилые люди",
    "Дети и подростки",
    "Люди с инвалидностью",
    "Гуманитарная помощь",
    "Образование",
    "Медицина и здоровье",
    "Культура и мероприятия",
    "Социальная помощь",
]

SKILL_NAMES = [
    "Общение с людьми",
    "Работа в команде",
    "Организация мероприятий",
    "Первая помощь",
    "Ответственность",
    "Стрессоустойчивость",
    "Лидерство",
    "Фото и видео",
    "Ведение соцсетей",
    "Дизайн",
    "Написание текстов",
    "Перевод",
    "Логистика",
    "Работа с документами",
]


def ensure_database_schema(engine: Engine) -> None:
    """Small compatibility helper for projects without Alembic migrations."""
    inspector = inspect(engine)
    table_names = inspector.get_table_names()
    _seed_lookup_table(engine, table_names, "directions", DIRECTION_NAMES)
    _seed_lookup_table(engine, table_names, "skills", SKILL_NAMES)
    _remove_legacy_profile_skills_column(engine, inspector, table_names)
    _ensure_user_email_columns(engine, inspector, table_names)
    _make_profile_email_nullable(engine, inspector, table_names)

    if "notifications" in table_names:
        _ensure_notification_reference_columns(engine, inspector)
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

    if "event_messages" in table_names:
        msg_columns = {col["name"] for col in inspector.get_columns("event_messages")}
        if "chat_id" not in msg_columns:
            with engine.begin() as connection:
                connection.execute(text(
                    "ALTER TABLE event_messages ADD COLUMN chat_id INTEGER NOT NULL DEFAULT 0"
                ))

    if "profiles" in table_names:
        profile_columns = {col["name"] for col in inspector.get_columns("profiles")}
        if "rating" not in profile_columns:
            with engine.begin() as connection:
                connection.execute(text(
                    "ALTER TABLE profiles ADD COLUMN rating INTEGER NOT NULL DEFAULT 100"
                ))
        if "is_verified" not in profile_columns:
            bool_type = "BOOLEAN" if engine.dialect.name == "postgresql" else "INTEGER"
            with engine.begin() as connection:
                connection.execute(text(
                    f"ALTER TABLE profiles ADD COLUMN is_verified {bool_type} NOT NULL DEFAULT FALSE"
                ))

    if "users" in table_names:
        user_columns = {col["name"] for col in inspector.get_columns("users")}
        dialect = engine.dialect.name
        user_stmts: list[str] = []
        if "is_banned" not in user_columns:
            bool_type = "BOOLEAN" if dialect == "postgresql" else "INTEGER"
            user_stmts.append(f"ALTER TABLE users ADD COLUMN is_banned {bool_type} NOT NULL DEFAULT FALSE")
        if "frozen_until" not in user_columns:
            ts_type = "TIMESTAMP WITH TIME ZONE" if dialect == "postgresql" else "DATETIME"
            user_stmts.append(f"ALTER TABLE users ADD COLUMN frozen_until {ts_type} NULL")
        if user_stmts:
            with engine.begin() as connection:
                for stmt in user_stmts:
                    connection.execute(text(stmt))

    if "rating_history" not in table_names:
        dialect = engine.dialect.name
        ts_type = "TIMESTAMP WITH TIME ZONE" if dialect == "postgresql" else "DATETIME"
        with engine.begin() as connection:
            connection.execute(text(f"""
                CREATE TABLE rating_history (
                    id INTEGER PRIMARY KEY {'GENERATED ALWAYS AS IDENTITY' if dialect == 'postgresql' else 'AUTOINCREMENT'},
                    profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
                    delta INTEGER NOT NULL,
                    event_id VARCHAR(36) REFERENCES events(id) ON DELETE SET NULL,
                    event_title VARCHAR(500),
                    created_at {ts_type} NOT NULL
                )
            """))

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
    if "present_count" not in columns:
        statements.append("ALTER TABLE events ADD COLUMN present_count INTEGER NULL")
    if "group_count" not in columns:
        statements.append("ALTER TABLE events ADD COLUMN group_count INTEGER NULL")
    if "rating_points" not in columns:
        statements.append("ALTER TABLE events ADD COLUMN rating_points INTEGER NOT NULL DEFAULT 50")

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


def _seed_lookup_table(
    engine: Engine,
    table_names: list[str],
    table_name: str,
    names: list[str],
) -> None:
    if table_name not in table_names:
        return

    with engine.begin() as connection:
        existing_names = {
            row[0]
            for row in connection.execute(text(f"SELECT name FROM {table_name}"))
        }

        missing_names = [name for name in names if name not in existing_names]
        if not missing_names:
            return

        connection.execute(
            text(f"INSERT INTO {table_name} (name) VALUES (:name)"),
            [{"name": name} for name in missing_names],
        )


def _ensure_notification_reference_columns(engine: Engine, inspector) -> None:
    columns = {column["name"] for column in inspector.get_columns("notifications")}
    statements: list[str] = []

    if "event_id" not in columns:
        statements.append("ALTER TABLE notifications ADD COLUMN event_id VARCHAR(36) NULL")
    if "application_id" not in columns:
        statements.append("ALTER TABLE notifications ADD COLUMN application_id INTEGER NULL")

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


def _remove_legacy_profile_skills_column(
    engine: Engine,
    inspector,
    table_names: list[str],
) -> None:
    if "profiles" not in table_names:
        return

    profile_columns = {column["name"] for column in inspector.get_columns("profiles")}
    if "skills" not in profile_columns:
        return

    _backfill_volunteer_skills(engine, table_names)

    drop_statement = "ALTER TABLE profiles DROP COLUMN skills"
    if engine.dialect.name == "postgresql":
        drop_statement = "ALTER TABLE profiles DROP COLUMN IF EXISTS skills"

    with engine.begin() as connection:
        connection.execute(text(drop_statement))


def _backfill_volunteer_skills(engine: Engine, table_names: list[str]) -> None:
    if not {"skills", "volunteer_skills"}.issubset(table_names):
        return

    with engine.begin() as connection:
        skill_ids_by_name = {
            row.name: row.id
            for row in connection.execute(text("SELECT id, name FROM skills"))
        }
        existing_pairs = {
            (row.volunteer_id, row.skill_id)
            for row in connection.execute(
                text("SELECT volunteer_id, skill_id FROM volunteer_skills")
            )
        }
        rows = connection.execute(
            text("SELECT id, skills FROM profiles WHERE type = 'volunteer'")
        )

        new_pairs: list[dict[str, int]] = []
        for row in rows:
            for skill_name in _parse_legacy_skills(row.skills):
                skill_id = skill_ids_by_name.get(skill_name)
                if skill_id is None:
                    continue

                pair = (row.id, skill_id)
                if pair in existing_pairs:
                    continue

                existing_pairs.add(pair)
                new_pairs.append({"volunteer_id": row.id, "skill_id": skill_id})

        if new_pairs:
            connection.execute(
                text(
                    "INSERT INTO volunteer_skills (volunteer_id, skill_id) "
                    "VALUES (:volunteer_id, :skill_id)"
                ),
                new_pairs,
            )


def _ensure_user_email_columns(engine: Engine, inspector, table_names: list[str]) -> None:
    if "users" not in table_names:
        return

    columns = {column["name"] for column in inspector.get_columns("users")}
    statements: list[str] = []
    dialect = engine.dialect.name

    if "email" not in columns:
        statements.append("ALTER TABLE users ADD COLUMN email VARCHAR(255) NULL")
    if "email_verified" not in columns:
        bool_type = "BOOLEAN" if dialect == "postgresql" else "INTEGER"
        statements.append(f"ALTER TABLE users ADD COLUMN email_verified {bool_type} NOT NULL DEFAULT FALSE")

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


def _make_profile_email_nullable(engine: Engine, inspector, table_names: list[str]) -> None:
    if "profiles" not in table_names:
        return

    dialect = engine.dialect.name
    if dialect != "postgresql":
        return

    columns = {col["name"]: col for col in inspector.get_columns("profiles")}
    email_col = columns.get("email")
    if email_col is None or email_col.get("nullable", True):
        return

    with engine.begin() as connection:
        connection.execute(text("ALTER TABLE profiles ALTER COLUMN email DROP NOT NULL"))


def _parse_legacy_skills(value) -> list[str]:
    if not value:
        return []

    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            value = [value]

    if not isinstance(value, list):
        return []

    return [str(item).strip() for item in value if str(item).strip()]
