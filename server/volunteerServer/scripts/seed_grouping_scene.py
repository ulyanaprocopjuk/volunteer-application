#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin
from urllib.request import Request, urlopen


DEFAULT_PASSWORD = "SeedPassword123!"
DEFAULT_BASE_URL = "http://127.0.0.1:8000"
LEADERS_CHAT_ID = 9999


class ApiError(RuntimeError):
    def __init__(self, method: str, path: str, status: int, body: str) -> None:
        self.method = method
        self.path = path
        self.status = status
        self.body = body
        super().__init__(f"{method} {path} failed with {status}: {body}")


@dataclass
class SeedUser:
    username: str
    email: str
    token: str
    profile_id: int


class ApiClient:
    def __init__(self, base_url: str) -> None:
        self.base_url = base_url.rstrip("/") + "/"

    def get(self, path: str, token: str | None = None) -> Any:
        return self.request("GET", path, token=token)

    def post(self, path: str, payload: dict[str, Any] | None = None, token: str | None = None) -> Any:
        return self.request("POST", path, payload=payload, token=token)

    def request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
        token: str | None = None,
    ) -> Any:
        body = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers = {"Accept": "application/json"}
        if body is not None:
            headers["Content-Type"] = "application/json"
        if token:
            headers["Authorization"] = f"Bearer {token}"

        request = Request(
            urljoin(self.base_url, path.lstrip("/")),
            data=body,
            headers=headers,
            method=method,
        )
        try:
            with urlopen(request, timeout=20) as response:
                raw = response.read().decode("utf-8")
                return json.loads(raw) if raw else None
        except HTTPError as exc:
            raise ApiError(method, path, exc.code, exc.read().decode("utf-8")) from exc
        except URLError as exc:
            raise RuntimeError(f"Cannot reach API at {self.base_url}: {exc.reason}") from exc


def load_dotenv(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip().strip('"').strip("'")
        values[key.strip()] = value
    return values


def login(api: ApiClient, username: str, password: str) -> str:
    response = api.post("/auth/login", {"username": username, "password": password})
    return response["access_token"]


def ensure_user(
    api: ApiClient,
    *,
    username: str,
    email: str,
    password: str,
    profile_payload: dict[str, Any],
) -> SeedUser:
    try:
        api.post("/auth/register", {"username": username, "email": email, "password": password})
        print(f"created user: {username}")
    except ApiError as exc:
        if exc.status != 400:
            raise
        print(f"user exists, reusing: {username}")

    token = login(api, username, password)
    profile = api.post("/api/profile", profile_payload, token=token)
    return SeedUser(username=username, email=email, token=token, profile_id=profile["id"])


def make_volunteer_profile(index: int, email: str) -> dict[str, Any]:
    return {
        "type": "volunteer",
        "avatar_url": None,
        "first_name": f"Участник {index:02d}",
        "last_name": "Сидов",
        "phone": f"+37529123{index:04d}",
        "email": email,
        "city": "Минск",
        "country": "Беларусь",
        "skills": ["Общение с людьми", "Работа в команде", "Ответственность"],
        "about": "Тестовый участник для проверки групп и чатов.",
    }


def make_event_payload(title: str, volunteers_needed: int, starts_in_hours: int) -> dict[str, Any]:
    starts_at = datetime.now(UTC) + timedelta(hours=starts_in_hours)
    ends_at = starts_at + timedelta(hours=3)
    return {
        "title": title,
        "direction": "Социальная помощь",
        "description": "Тестовая сцена для проверки заявок, посещаемости, групп и чатов.",
        "country": "Беларусь",
        "city": "Минск",
        "locationName": "Беларусь, Минск, проспект Независимости, 95",
        "photoURL": None,
        "latitude": 53.9333,
        "longitude": 27.65,
        "startsAt": starts_at.isoformat().replace("+00:00", "Z"),
        "endsAt": ends_at.isoformat().replace("+00:00", "Z"),
        "volunteersNeeded": volunteers_needed,
    }


def create_approved_event(api: ApiClient, organizer_token: str, admin_token: str, payload: dict[str, Any]) -> dict[str, Any]:
    event = api.post("/api/events", payload, token=organizer_token)
    event_id = event["id"]
    approved = api.post(f"/api/events/{event_id}/approve", token=admin_token)
    print(f"approved event: {approved['title']} ({event_id})")
    return approved


def accept_participants(
    api: ApiClient,
    *,
    event_id: str,
    organizer_token: str,
    participants: list[SeedUser],
) -> list[dict[str, Any]]:
    for user in participants:
        api.post(f"/api/events/{event_id}/applications", token=user.token)

    applications = api.get(f"/api/events/{event_id}/applications", token=organizer_token)
    by_profile_id = {item["profile"]["id"]: item for item in applications}

    accepted: list[dict[str, Any]] = []
    for user in participants:
        application = by_profile_id[user.profile_id]
        if application["status"] != "accepted":
            api.post(f"/api/events/applications/{application['application_id']}/accept", token=organizer_token)
        accepted.append(application)

    applications = api.get(f"/api/events/{event_id}/applications", token=organizer_token)
    accepted_count = sum(1 for item in applications if item["status"] == "accepted")
    print(f"accepted applications for {event_id}: {accepted_count}")
    return applications


def move_to_grouping(api: ApiClient, *, event_id: str, organizer_token: str) -> list[dict[str, Any]]:
    api.post(f"/api/events/{event_id}/start", token=organizer_token)
    attendance = api.get(f"/api/events/{event_id}/attendance", token=organizer_token)
    present_ids = [item["application_id"] for item in attendance]
    event = api.post(
        f"/api/events/{event_id}/attendance/confirm",
        {"presentApplicationIDs": present_ids},
        token=organizer_token,
    )
    print(f"attendance confirmed for {event_id}: present={len(present_ids)}, status={event['status']}")
    return attendance


def smoke_test_chats(
    api: ApiClient,
    *,
    organizer: SeedUser,
    admin_token: str,
    participants: list[SeedUser],
) -> None:
    chat_participants = participants[:6]
    event = create_approved_event(
        api,
        organizer.token,
        admin_token,
        make_event_payload("Seed: проверка чатов", volunteers_needed=len(chat_participants) + 1, starts_in_hours=2),
    )
    event_id = event["id"]

    accept_participants(
        api,
        event_id=event_id,
        organizer_token=organizer.token,
        participants=chat_participants,
    )
    move_to_grouping(api, event_id=event_id, organizer_token=organizer.token)
    api.post(f"/api/events/{event_id}/grouping/confirm", {"groupCount": 2}, token=organizer.token)
    groups = api.post(f"/api/events/{event_id}/groups/auto", token=organizer.token)
    api.post(f"/api/events/{event_id}/groups/confirm", token=organizer.token)

    groups = api.get(f"/api/events/{event_id}/groups", token=organizer.token)
    leader_profile_id = groups[0]["leader_id"]
    member_profile_id = groups[0]["members"][0]["profile_id"] if groups[0]["members"] else groups[1]["leader_id"]

    leader = next(user for user in chat_participants if user.profile_id == leader_profile_id)
    member = next(user for user in chat_participants if user.profile_id == member_profile_id)

    organizer_chats = api.get(f"/api/events/{event_id}/chats", token=organizer.token)
    leader_chats = api.get(f"/api/events/{event_id}/chats", token=leader.token)
    member_chats = api.get(f"/api/events/{event_id}/chats", token=member.token)

    api.post(
        f"/api/events/{event_id}/chats/{LEADERS_CHAT_ID}/messages",
        {"content": "Организатор: проверка чата лидеров."},
        token=organizer.token,
    )
    api.post(
        f"/api/events/{event_id}/chats/{LEADERS_CHAT_ID}/messages",
        {"content": "Лидер: сообщение получено."},
        token=leader.token,
    )

    group_chat_id = groups[0]["group_number"]
    api.post(
        f"/api/events/{event_id}/chats/{group_chat_id}/messages",
        {"content": "Лидер: проверка группового чата."},
        token=leader.token,
    )
    api.post(
        f"/api/events/{event_id}/chats/{group_chat_id}/messages",
        {"content": "Участник: вижу групповой чат."},
        token=member.token,
    )

    leaders_messages = api.get(f"/api/events/{event_id}/chats/{LEADERS_CHAT_ID}/messages", token=organizer.token)
    group_messages = api.get(f"/api/events/{event_id}/chats/{group_chat_id}/messages", token=member.token)

    print("chat smoke test:")
    print(f"  event_id: {event_id}")
    print(f"  organizer chats: {[chat['title'] for chat in organizer_chats]}")
    print(f"  leader chats: {[chat['title'] for chat in leader_chats]}")
    print(f"  member chats: {[chat['title'] for chat in member_chats]}")
    print(f"  leaders chat messages: {len(leaders_messages)}")
    print(f"  group chat messages: {len(group_messages)}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seed a grouping-ready event scene through the HTTP API.")
    parser.add_argument("--base-url", default=os.getenv("VOLUNTEER_API_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--prefix", default="seed-grouping")
    parser.add_argument("--password", default=DEFAULT_PASSWORD)
    parser.add_argument("--participants", type=int, default=20)
    parser.add_argument("--skip-chat-test", action="store_true")
    parser.add_argument("--admin-username")
    parser.add_argument("--admin-password")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.participants < 4:
        print("--participants must be at least 4 to reach grouping status", file=sys.stderr)
        return 2

    env = load_dotenv(Path(__file__).resolve().parents[1] / ".env")
    admin_username = args.admin_username or env.get("DEFAULT_ADMIN_USERNAME") or "admin"
    admin_password = args.admin_password or env.get("DEFAULT_ADMIN_PASSWORD") or "Admin12345!"

    api = ApiClient(args.base_url)
    admin_token = login(api, admin_username, admin_password)

    organizer_email = f"{args.prefix}.organizer@volunteer-seed.com"
    organizer = ensure_user(
        api,
        username=f"{args.prefix}-organizer",
        email=organizer_email,
        password=args.password,
        profile_payload={
            "type": "volunteer",
            "avatar_url": None,
            "first_name": "Организатор",
            "last_name": "Тестовый",
            "phone": "+375291230000",
            "email": organizer_email,
            "city": "Минск",
            "country": "Беларусь",
            "skills": ["Организация мероприятий", "Лидерство"],
            "about": "Тестовый организатор для проверки групп.",
        },
    )

    users: list[SeedUser] = []
    for index in range(1, args.participants + 1):
        email = f"{args.prefix}.participant{index:02d}@volunteer-seed.com"
        users.append(
            ensure_user(
                api,
                username=f"{args.prefix}-p{index:02d}",
                email=email,
                password=args.password,
                profile_payload=make_volunteer_profile(index, email),
            )
        )

    grouping_event = create_approved_event(
        api,
        organizer.token,
        admin_token,
        make_event_payload(
            "Seed: событие готово к группировке",
            volunteers_needed=args.participants + 1,
            starts_in_hours=1,
        ),
    )
    event_id = grouping_event["id"]
    accept_participants(api, event_id=event_id, organizer_token=organizer.token, participants=users)
    attendance = move_to_grouping(api, event_id=event_id, organizer_token=organizer.token)
    final_event = api.get(f"/api/events/{event_id}", token=organizer.token)

    if not args.skip_chat_test:
        smoke_test_chats(api, organizer=organizer, admin_token=admin_token, participants=users)

    print("")
    print("grouping scene ready:")
    print(f"  event_id: {event_id}")
    print(f"  title: {final_event['title']}")
    print(f"  status: {final_event['status']}")
    print(f"  organizer username: {organizer.username}")
    print(f"  participant usernames: {users[0].username} ... {users[-1].username}")
    print(f"  password for seeded users: {args.password}")
    print(f"  accepted participants excluding organizer: {len(users)}")
    print(f"  present attendance records: {len(attendance)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
