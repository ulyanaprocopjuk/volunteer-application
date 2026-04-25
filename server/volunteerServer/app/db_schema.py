from __future__ import annotations

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def ensure_database_schema(engine: Engine) -> None:
    """Small compatibility helper for projects without Alembic migrations."""
    inspector = inspect(engine)
    if "events" not in inspector.get_table_names():
        return

    columns = {column["name"] for column in inspector.get_columns("events")}
    statements: list[str] = []
    dialect = engine.dialect.name

    if "status" not in columns:
        statements.append("ALTER TABLE events ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'approved'")
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
