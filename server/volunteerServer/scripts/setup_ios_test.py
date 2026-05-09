#!/usr/bin/env python3
"""
iOS manual testing setup.

Creates two events with shared accounts so you can test every scenario
from the app without switching profiles manually:

  EVENT A — status: grouping
    Attendance is confirmed. Groups are NOT yet assigned.
    → Log in as organizer, select group count, auto-distribute,
      confirm groups → event goes active → test active buttons + chat.

  EVENT B — status: active (groups already confirmed)
    2 groups with leaders assigned. Ready for chat testing right away.
    → Log in as organizer  → sees "Чат лидеров"
    → Log in as leader     → sees group chat + "Чат лидеров"
    → Log in as member     → sees group chat only + banner on home screen

Run:
  python scripts/setup_ios_test.py
  python scripts/setup_ios_test.py --reset   # delete old events and recreate
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin
from urllib.request import Request, urlopen

# ── Config ────────────────────────────────────────────────────────────────────
DEFAULT_BASE_URL = "http://127.0.0.1:8000"
PASSWORD = "Test1234!"
PREFIX = "ios"
PARTICIPANTS = 8      # must be ≥ 4
GROUP_COUNT = 2
LEADERS_CHAT_ID = 9999

# ── HTTP ──────────────────────────────────────────────────────────────────────
class ApiError(RuntimeError):
    def __init__(self, method: str, path: str, status: int, body: str) -> None:
        self.status = status
        super().__init__(f"{method} {path} → {status}: {body}")


class Api:
    def __init__(self, base: str) -> None:
        self._base = base.rstrip("/") + "/"

    def get(self, path: str, token: str | None = None) -> Any:
        return self._call("GET", path, token=token)

    def post(self, path: str, body: dict | None = None, token: str | None = None) -> Any:
        return self._call("POST", path, body=body, token=token)

    def delete(self, path: str, token: str | None = None) -> Any:
        return self._call("DELETE", path, token=token)

    def _call(self, method: str, path: str, body: dict | None = None, token: str | None = None) -> Any:
        data = None if body is None else json.dumps(body, ensure_ascii=False).encode()
        headers: dict[str, str] = {"Accept": "application/json"}
        if data:
            headers["Content-Type"] = "application/json"
        if token:
            headers["Authorization"] = f"Bearer {token}"
        req = Request(urljoin(self._base, path.lstrip("/")), data=data, headers=headers, method=method)
        try:
            with urlopen(req, timeout=20) as r:
                raw = r.read().decode()
                return json.loads(raw) if raw else None
        except HTTPError as e:
            raise ApiError(method, path, e.code, e.read().decode()) from e
        except URLError as e:
            raise RuntimeError(f"Cannot reach {self._base}: {e.reason}") from e


# ── Domain ────────────────────────────────────────────────────────────────────
@dataclass
class Account:
    username: str
    token: str
    profile_id: int
    display: str


@dataclass
class Group:
    number: int
    leader: Account | None = None
    members: list[Account] = field(default_factory=list)


# ── Helpers ───────────────────────────────────────────────────────────────────
def load_dotenv(p: Path) -> dict[str, str]:
    if not p.exists():
        return {}
    out: dict[str, str] = {}
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def token(api: Api, username: str, pw: str) -> str:
    return api.post("/auth/login", {"username": username, "password": pw})["access_token"]


def ensure_account(api: Api, username: str, email: str, pw: str, profile: dict, display: str) -> Account:
    try:
        api.post("/auth/register", {"username": username, "email": email, "password": pw})
    except ApiError as e:
        if e.status != 400:
            raise
    t = token(api, username, pw)
    p = api.post("/api/profile", profile, token=t)
    return Account(username=username, token=t, profile_id=p["id"], display=display)


def volunteer_profile(first: str, last: str, phone: str, email: str) -> dict:
    return {
        "type": "volunteer",
        "avatar_url": None,
        "first_name": first,
        "last_name": last,
        "phone": phone,
        "email": email,
        "city": "Минск",
        "country": "Беларусь",
        "skills": ["Общение с людьми", "Работа в команде"],
        "about": "Тестовый аккаунт для iOS.",
    }


def make_event(title: str, needed: int, hours_from_now: int = 2) -> dict:
    start = datetime.now(UTC) + timedelta(hours=hours_from_now)
    end = start + timedelta(hours=4)
    return {
        "title": title,
        "direction": "Социальная помощь",
        "description": "Тестовое событие для ручного тестирования iOS-приложения.",
        "country": "Беларусь",
        "city": "Минск",
        "locationName": "Беларусь, Минск, проспект Независимости, 95",
        "photoURL": None,
        "latitude": 53.9333,
        "longitude": 27.65,
        "startsAt": start.isoformat().replace("+00:00", "Z"),
        "endsAt": end.isoformat().replace("+00:00", "Z"),
        "volunteersNeeded": needed,
    }


def create_and_approve(api: Api, org_token: str, admin_token: str, payload: dict) -> dict:
    event = api.post("/api/events", payload, token=org_token)
    return api.post(f"/api/events/{event['id']}/approve", token=admin_token)


def apply_and_accept_all(api: Api, event_id: str, org_token: str, accounts: list[Account]) -> None:
    for acc in accounts:
        try:
            api.post(f"/api/events/{event_id}/applications", token=acc.token)
        except ApiError as e:
            if e.status not in (400, 409):
                raise

    apps = api.get(f"/api/events/{event_id}/applications", token=org_token)
    by_profile = {a["profile"]["id"]: a for a in apps}

    for acc in accounts:
        app = by_profile.get(acc.profile_id)
        if app and app["status"] != "accepted":
            try:
                api.post(f"/api/events/applications/{app['application_id']}/accept", token=org_token)
            except ApiError as e:
                if e.status not in (400, 409):
                    raise


def start_and_confirm_attendance(api: Api, event_id: str, org_token: str) -> None:
    try:
        api.post(f"/api/events/{event_id}/start", token=org_token)
    except ApiError as e:
        if e.status != 400:
            raise

    attendance = api.get(f"/api/events/{event_id}/attendance", token=org_token)
    present_ids = [item["application_id"] for item in attendance]
    api.post(
        f"/api/events/{event_id}/attendance/confirm",
        {"presentApplicationIDs": present_ids},
        token=org_token,
    )


def assign_groups_and_activate(api: Api, event_id: str, org_token: str, group_count: int, participants: list[Account]) -> list[Group]:
    api.post(f"/api/events/{event_id}/grouping/confirm", {"groupCount": group_count}, token=org_token)
    api.post(f"/api/events/{event_id}/groups/auto", token=org_token)
    api.post(f"/api/events/{event_id}/groups/confirm", token=org_token)

    by_pid = {a.profile_id: a for a in participants}
    raw_groups = api.get(f"/api/events/{event_id}/groups", token=org_token)

    groups: list[Group] = []
    for g in raw_groups:
        leader = by_pid.get(g["leader_id"])
        members = [by_pid[m["profile_id"]] for m in g["members"] if m["profile_id"] in by_pid]
        groups.append(Group(number=g["group_number"], leader=leader, members=members))

    return groups


def send_seed_messages(api: Api, event_id: str, groups: list[Group], org_token: str) -> None:
    """Seed one message in each chat so the chat history isn't empty."""
    for g in groups:
        chat_id = g.number
        if g.leader:
            api.post(
                f"/api/events/{event_id}/chats/{chat_id}/messages",
                {"content": f"Привет группе {g.number}! Это {g.leader.display}."},
                token=g.leader.token,
            )
        for m in g.members[:1]:
            api.post(
                f"/api/events/{event_id}/chats/{chat_id}/messages",
                {"content": f"Участник {m.display} в чате."},
                token=m.token,
            )
    # leaders chat
    api.post(
        f"/api/events/{event_id}/chats/{LEADERS_CHAT_ID}/messages",
        {"content": "Организатор в чате лидеров."},
        token=org_token,
    )
    for g in groups:
        if g.leader:
            api.post(
                f"/api/events/{event_id}/chats/{LEADERS_CHAT_ID}/messages",
                {"content": f"Лидер группы {g.number} в чате лидеров."},
                token=g.leader.token,
            )


# ── Pretty print ──────────────────────────────────────────────────────────────
W = 62
LINE = "═" * W
THIN = "─" * W

def header(title: str) -> None:
    print(f"\n{LINE}")
    pad = (W - len(title)) // 2
    print(" " * pad + title)
    print(LINE)

def block(title: str) -> None:
    print(f"\n{THIN}")
    print(f"  {title}")
    print(THIN)

def row(label: str, value: str) -> None:
    print(f"  {label:<22}{value}")

def bullet(text: str, indent: int = 2) -> None:
    print(" " * indent + f"• {text}")


# ── Main ──────────────────────────────────────────────────────────────────────
def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default=os.getenv("VOLUNTEER_API_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--admin-username")
    parser.add_argument("--admin-password")
    parser.add_argument("--reset", action="store_true",
                        help="Delete active/grouping events created by this script before re-creating them.")
    args = parser.parse_args()

    env = load_dotenv(Path(__file__).resolve().parents[1] / ".env")
    admin_user = args.admin_username or env.get("DEFAULT_ADMIN_USERNAME") or "admin"
    admin_pw   = args.admin_password or env.get("DEFAULT_ADMIN_PASSWORD") or "Admin12345!"

    api = Api(args.base_url)

    print("Connecting…")
    try:
        admin_token = token(api, admin_user, admin_pw)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"Admin OK ({admin_user})")

    # ── Step 1: Accounts ──────────────────────────────────────────────────────
    print("\n[1/4] Creating accounts…")
    org_email = f"{PREFIX}-organizer@test.local"
    organizer = ensure_account(
        api,
        username=f"{PREFIX}-organizer",
        email=org_email,
        pw=PASSWORD,
        display="Организатор",
        profile={
            "type": "volunteer",
            "avatar_url": None,
            "first_name": "Организатор",
            "last_name": "Тест",
            "phone": "+375291230000",
            "email": org_email,
            "city": "Минск",
            "country": "Беларусь",
            "skills": ["Организация мероприятий", "Лидерство"],
            "about": "Тестовый организатор.",
        },
    )
    print(f"  organizer: {organizer.username}")

    participants: list[Account] = []
    for i in range(1, PARTICIPANTS + 1):
        email = f"{PREFIX}-p{i:02d}@test.local"
        acc = ensure_account(
            api,
            username=f"{PREFIX}-p{i:02d}",
            email=email,
            pw=PASSWORD,
            display=f"Участник {i:02d}",
            profile=volunteer_profile(f"Участник", f"{i:02d}", f"+37529123{i:04d}", email),
        )
        participants.append(acc)
        print(f"  participant {i:02d}: {acc.username}")

    # ── Step 2: Event A — grouping ────────────────────────────────────────────
    print("\n[2/4] Creating Event A (grouping)…")
    event_a = create_and_approve(
        api, organizer.token, admin_token,
        make_event(
            f"[{PREFIX}] Тест создания групп",
            needed=PARTICIPANTS + 1,
            hours_from_now=1,
        ),
    )
    eid_a = event_a["id"]
    apply_and_accept_all(api, eid_a, organizer.token, participants)
    start_and_confirm_attendance(api, eid_a, organizer.token)
    print(f"  event A: {eid_a}  status=grouping ✓")

    # ── Step 3: Event B — active with groups ──────────────────────────────────
    print(f"\n[3/4] Creating Event B (active, {GROUP_COUNT} groups)…")
    event_b = create_and_approve(
        api, organizer.token, admin_token,
        make_event(
            f"[{PREFIX}] Тест чатов (активное)",
            needed=PARTICIPANTS + 1,
            hours_from_now=2,
        ),
    )
    eid_b = event_b["id"]
    apply_and_accept_all(api, eid_b, organizer.token, participants)
    start_and_confirm_attendance(api, eid_b, organizer.token)
    groups = assign_groups_and_activate(api, eid_b, organizer.token, GROUP_COUNT, participants)
    print(f"  event B: {eid_b}  status=active ✓")

    # ── Step 4: Seed messages so chats aren't empty ───────────────────────────
    print("\n[4/4] Seeding chat messages…")
    send_seed_messages(api, eid_b, groups, organizer.token)
    print("  messages seeded ✓")

    # ── Print guide ───────────────────────────────────────────────────────────
    header("iOS TEST GUIDE")

    print(f"\n  Пароль для всех аккаунтов: {PASSWORD}")

    # ── Event A ───────────────────────────────────────────────────────────────
    block("СОБЫТИЕ A — создание и подтверждение групп")
    row("Event ID:", eid_a)
    row("Статус:", "grouping")
    row("Войти как:", f"{organizer.username} / {PASSWORD}")
    print()
    print("  Что делать:")
    bullet("открыть «Мои события» → выбрать это событие")
    bullet("выбрать количество групп (например, 2)")
    bullet("нажать «Авто-распределить» → участники распределятся")
    bullet("можно перетащить участников вручную между группами")
    bullet("нажать «Подтвердить группы»")
    bullet("событие переходит в статус ACTIVE")
    print()
    print("  После подтверждения групп видно:")
    bullet("кнопка «Редактировать группы»")
    bullet("кнопка «Завершить событие»")
    bullet("у участников появляется баннер на главном экране")
    bullet("у участников появляется кнопка «Чат» в карточке события")

    # ── Event B ───────────────────────────────────────────────────────────────
    block("СОБЫТИЕ B — чаты (группы уже созданы)")
    row("Event ID:", eid_b)
    row("Статус:", "active")
    print()

    for g in groups:
        leader_name = g.leader.username if g.leader else "—"
        member_names = ", ".join(m.username for m in g.members)
        print(f"  Группа {g.number}:")
        row(f"    Лидер:", f"{leader_name} / {PASSWORD}")
        row(f"    Участники:", member_names)
        print()

    print("  Что видит каждый:")
    print()

    row("  Организатор:", f"{organizer.username} / {PASSWORD}")
    bullet("баннер на главном экране")
    bullet("кнопки «Редактировать группы» + «Завершить событие»")
    bullet("в чате → только «Чат лидеров»")
    print()

    for g in groups:
        if g.leader:
            row(f"  Лидер гр.{g.number}:", f"{g.leader.username} / {PASSWORD}")
            bullet("баннер на главном экране")
            bullet("кнопка «Чат» → список из 2 чатов:")
            bullet(f"  [💬] Группа {g.number}", indent=6)
            bullet(f"  [⭐] Чат лидеров", indent=6)
            print()

    for g in groups:
        for m in g.members[:1]:
            row(f"  Участник гр.{g.number}:", f"{m.username} / {PASSWORD}")
            bullet("баннер на главном экране")
            bullet(f"кнопка «Чат» → сразу открывается Группа {g.number}")
            print()
            break

    # ── All accounts ──────────────────────────────────────────────────────────
    block("ВСЕ АККАУНТЫ")
    row("Пароль:", PASSWORD)
    print()
    row("  Организатор:", organizer.username)
    for i, acc in enumerate(participants, 1):
        role = ""
        for g in groups:
            if g.leader and g.leader.profile_id == acc.profile_id:
                role = f"← лидер группы {g.number}"
                break
            for m in g.members:
                if m.profile_id == acc.profile_id:
                    role = f"← группа {g.number}"
                    break
        row(f"  {acc.username}:", role)

    print(f"\n{LINE}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
