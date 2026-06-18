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
        print(f"  created user: {username}")
    except ApiError as exc:
        if exc.status != 400:
            raise
        print(f"  user exists, reusing: {username}")

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


def create_approved_event(
    api: ApiClient,
    organizer_token: str,
    admin_token: str,
    payload: dict[str, Any],
) -> dict[str, Any]:
    event = api.post("/api/events", payload, token=organizer_token)
    event_id = event["id"]
    approved = api.post(f"/api/events/{event_id}/approve", token=admin_token)
    print(f"  approved event: {approved['title']} ({event_id})")
    return approved


def accept_participants(
    api: ApiClient,
    *,
    event_id: str,
    organizer_token: str,
    participants: list[SeedUser],
) -> list[dict[str, Any]]:
    for user in participants:
        try:
            api.post(f"/api/events/{event_id}/applications", token=user.token)
        except ApiError as exc:
            if exc.status not in (400, 409):
                raise

    applications = api.get(f"/api/events/{event_id}/applications", token=organizer_token)
    by_profile_id = {item["profile"]["id"]: item for item in applications}

    for user in participants:
        application = by_profile_id.get(user.profile_id)
        if application is None:
            continue
        if application["status"] not in ("accepted",):
            try:
                api.post(
                    f"/api/events/applications/{application['application_id']}/accept",
                    token=organizer_token,
                )
            except ApiError as exc:
                if exc.status not in (400, 409):
                    raise

    applications = api.get(f"/api/events/{event_id}/applications", token=organizer_token)
    accepted_count = sum(1 for item in applications if item["status"] == "accepted")
    print(f"  accepted: {accepted_count} participants")
    return applications


def move_to_grouping(
    api: ApiClient,
    *,
    event_id: str,
    organizer_token: str,
) -> list[dict[str, Any]]:
    # Start event → attendance phase
    try:
        api.post(f"/api/events/{event_id}/start", token=organizer_token)
    except ApiError as exc:
        # Already started (attendance or grouping)
        if exc.status not in (400,):
            raise

    attendance = api.get(f"/api/events/{event_id}/attendance", token=organizer_token)
    present_ids = [item["application_id"] for item in attendance]

    event = api.post(
        f"/api/events/{event_id}/attendance/confirm",
        {"presentApplicationIDs": present_ids},
        token=organizer_token,
    )
    print(f"  attendance confirmed: {len(present_ids)} present, status={event['status']}")
    return attendance


def create_active_scene(
    api: ApiClient,
    *,
    organizer: SeedUser,
    admin_token: str,
    participants: list[SeedUser],
    group_count: int,
) -> dict[str, Any]:
    """Create a fully active event with groups confirmed — ready for chat testing from iOS."""
    print("\n[active scene] creating event...")
    event = create_approved_event(
        api,
        organizer.token,
        admin_token,
        make_event_payload(
            "Seed: активное событие (чаты)",
            volunteers_needed=len(participants) + 1,
            starts_in_hours=2,
        ),
    )
    event_id = event["id"]

    print("[active scene] accepting participants...")
    accept_participants(
        api,
        event_id=event_id,
        organizer_token=organizer.token,
        participants=participants,
    )

    print("[active scene] moving to grouping...")
    move_to_grouping(api, event_id=event_id, organizer_token=organizer.token)

    print(f"[active scene] confirming {group_count} groups and auto-distributing...")
    api.post(
        f"/api/events/{event_id}/grouping/confirm",
        {"groupCount": group_count},
        token=organizer.token,
    )
    api.post(f"/api/events/{event_id}/groups/auto", token=organizer.token)

    print("[active scene] confirming groups → event goes active...")
    api.post(f"/api/events/{event_id}/groups/confirm", token=organizer.token)

    groups = api.get(f"/api/events/{event_id}/groups", token=organizer.token)

    # Build profile_id → SeedUser map for readable output
    by_profile_id: dict[int, SeedUser] = {u.profile_id: u for u in participants}

    group_info: list[dict[str, Any]] = []
    for group in groups:
        leader_id = group["leader_id"]
        leader_user = by_profile_id.get(leader_id)
        member_users = [
            by_profile_id[m["profile_id"]]
            for m in group["members"]
            if m["profile_id"] in by_profile_id
        ]
        group_info.append({
            "number": group["group_number"],
            "leader": leader_user,
            "members": member_users,
        })

    return {"event_id": event_id, "groups": group_info}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seed grouping + active event scenes through the HTTP API.")
    parser.add_argument("--base-url", default=os.getenv("VOLUNTEER_API_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--prefix", default="seed-grouping")
    parser.add_argument("--password", default=DEFAULT_PASSWORD)
    parser.add_argument("--participants", type=int, default=20)
    parser.add_argument("--group-count", type=int, default=3, help="Number of groups in the active scene")
    parser.add_argument("--skip-active", action="store_true", help="Only create the grouping scene, skip active scene")
    parser.add_argument("--admin-username")
    parser.add_argument("--admin-password")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.participants < 4:
        print("--participants must be at least 4 to reach grouping status", file=sys.stderr)
        return 2
    if args.group_count < 2:
        print("--group-count must be at least 2 (to get multiple chats)", file=sys.stderr)
        return 2

    env = load_dotenv(Path(__file__).resolve().parents[1] / ".env")
    admin_username = args.admin_username or env.get("DEFAULT_ADMIN_USERNAME") or "admin"
    admin_password = args.admin_password or env.get("DEFAULT_ADMIN_PASSWORD") or "Admin12345!"

    api = ApiClient(args.base_url)
    print(f"logging in as admin ({admin_username})...")
    admin_token = login(api, admin_username, admin_password)

    # ── Organizer ──────────────────────────────────────────────────────────────
    print("\n[users] ensuring organizer...")
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

    # ── Participants ───────────────────────────────────────────────────────────
    print(f"\n[users] ensuring {args.participants} participants...")
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

    # ── Scene A: grouping event (organizer assigns groups from iOS) ────────────
    print("\n[scene A] creating grouping event...")
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
    grouping_event_id = grouping_event["id"]
    print("[scene A] accepting participants...")
    accept_participants(
        api,
        event_id=grouping_event_id,
        organizer_token=organizer.token,
        participants=users,
    )
    print("[scene A] moving to grouping phase...")
    move_to_grouping(api, event_id=grouping_event_id, organizer_token=organizer.token)
    final_grouping = api.get(f"/api/events/{grouping_event_id}", token=organizer.token)

    # ── Scene B: active event with groups confirmed (participants see chats) ───
    active_info: dict[str, Any] | None = None
    if not args.skip_active:
        active_info = create_active_scene(
            api,
            organizer=organizer,
            admin_token=admin_token,
            participants=users,
            group_count=args.group_count,
        )

    # ── Summary ────────────────────────────────────────────────────────────────
    pw = args.password
    sep = "─" * 60

    print(f"\n{sep}")
    print("SEED COMPLETE")
    print(sep)
    print(f"password for all seeded accounts: {pw}")
    print()

    print("SCENE A — grouping (organizer assigns groups from iOS)")
    print(f"  event_id : {grouping_event_id}")
    print(f"  status   : {final_grouping['status']}")
    print(f"  login as organizer → assign groups, then confirm")
    print(f"  organizer: {organizer.username} / {pw}")
    print()

    if active_info:
        print("SCENE B — active event (participants see chat banner)")
        print(f"  event_id : {active_info['event_id']}")
        print(f"  status   : active")
        print()
        for g in active_info["groups"]:
            n = g["number"]
            leader = g["leader"]
            members = g["members"]
            leader_line = f"{leader.username} / {pw}" if leader else "(none)"
            member_lines = ", ".join(u.username for u in members) if members else "(none)"
            print(f"  group {n}:")
            print(f"    leader  → {leader_line}")
            print(f"             sees: чат группы {n} + чат лидеров")
            if members:
                print(f"    members → {member_lines}")
                print(f"             see:  чат группы {n} only")
        print()
        print("  organizer sees: чат лидеров only")
        print(f"  organizer: {organizer.username} / {pw}")
        print()
        print("  iOS test scenarios:")
        groups = active_info["groups"]
        if groups:
            g1 = groups[0]
            if g1["leader"]:
                print(f"    → banner + leader chat: log in as {g1['leader'].username}")
            if g1["members"]:
                print(f"    → banner + group chat:  log in as {g1['members'][0].username}")
        print(f"    → organizer view:       log in as {organizer.username}")

    print(sep)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
