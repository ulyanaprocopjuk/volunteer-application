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
