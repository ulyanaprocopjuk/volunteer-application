import unittest

from sqlalchemy import create_engine, inspect, select, text
from sqlalchemy.orm import Session

from app.db import Base
from app.db_schema import DIRECTION_NAMES, SKILL_NAMES, ensure_database_schema
from app.models import Direction, Skill


class LookupTablesSchemaTests(unittest.TestCase):
    def test_creates_lookup_and_association_tables_with_seed_data(self):
        engine = create_engine("sqlite:///:memory:")

        Base.metadata.create_all(bind=engine)
        ensure_database_schema(engine)

        inspector = inspect(engine)
        table_names = set(inspector.get_table_names())

        self.assertIn("directions", table_names)
        self.assertIn("skills", table_names)
        self.assertIn("volunteer_skills", table_names)
        self.assertIn("events_direction", table_names)
        self.assertNotIn(
            "skills",
            {column["name"] for column in inspector.get_columns("profiles")},
        )

        self.assertEqual(
            {column["name"] for column in inspector.get_columns("volunteer_skills")},
            {"volunteer_id", "skill_id"},
        )
        self.assertEqual(
            {column["name"] for column in inspector.get_columns("events_direction")},
            {"event_id", "direction_id"},
        )

        with Session(engine) as session:
            directions = session.scalars(select(Direction.name).order_by(Direction.id)).all()
            skills = session.scalars(select(Skill.name).order_by(Skill.id)).all()

        self.assertEqual(directions, DIRECTION_NAMES)
        self.assertEqual(skills, SKILL_NAMES)

    def test_removes_legacy_profile_skills_column_after_backfill(self):
        engine = create_engine("sqlite:///:memory:")

        Base.metadata.create_all(bind=engine)
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE profiles ADD COLUMN skills TEXT NOT NULL DEFAULT '[]'"))
            connection.execute(
                text(
                    "INSERT INTO users (id, username, password_hash, role, is_active, created_at) "
                    "VALUES (1, 'volunteer', 'hash', 'user', 1, CURRENT_TIMESTAMP)"
                )
            )
            connection.execute(
                text(
                    "INSERT INTO profiles "
                    "(id, user_id, type, phone, email, city, country, skills, created_at, updated_at) "
                    "VALUES "
                    "(1, 1, 'volunteer', '+375291111111', 'v@example.com', 'Минск', 'Беларусь', "
                    "'[\"Первая помощь\", \"Дизайн\"]', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                )
            )

        ensure_database_schema(engine)

        inspector = inspect(engine)
        self.assertNotIn(
            "skills",
            {column["name"] for column in inspector.get_columns("profiles")},
        )

        with engine.connect() as connection:
            rows = connection.execute(
                text(
                    "SELECT s.name "
                    "FROM volunteer_skills vs "
                    "JOIN skills s ON s.id = vs.skill_id "
                    "WHERE vs.volunteer_id = 1 "
                    "ORDER BY s.name"
                )
            ).all()

        self.assertEqual([row.name for row in rows], ["Дизайн", "Первая помощь"])


if __name__ == "__main__":
    unittest.main()
