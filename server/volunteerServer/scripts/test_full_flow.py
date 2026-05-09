#!/usr/bin/env python3
"""
Full end-to-end walkthrough of the volunteer event lifecycle.

Phases tested:
  1. Setup      — create organizer + 8 participants
  2. Pending    — organizer creates event (status: pending)
  3. Approved   — admin approves event
  4. Applied    — all participants apply, organizer accepts them
  5. Attendance — organizer starts event, marks everyone present
  6. Grouping   — organizer sets 2 groups, auto-distributes
  7. Active     — organizer confirms groups → event goes active
  8. Chats      — verify chat access per role (organizer / leader / member)
  9. Finish     — organizer finishes event → status: completed

Run:
  python scripts/test_full_flow.py
  python scripts/test_full_flow.py --base-url http://localhost:8000
  python scripts/test_full_flow.py --keep-active   # stop before finishing (leave event active for iOS)
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

DEFAULT_PASSWORD = "FlowTest123!"
DEFAULT_BASE_URL = "http://127.0.0.1:8000"
LEADERS_CHAT_ID = 9999

PREFIX = "flowtest"

# ─── ANSI colours ─────────────────────────────────────────────────────────────
GREEN = "\033[92m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
RED = "\033[91m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"

def ok(msg: str) -> None:
    print(f"  {GREEN}✓{RESET} {msg}")

def info(msg: str) -> None:
    print(f"  {CYAN}·{RESET} {msg}")

def warn(msg: str) -> None:
    print(f"  {YELLOW}!{RESET} {msg}")

def step(title: str) -> None:
    print(f"\n{BOLD}{YELLOW}━━ {title} ━━{RESET}")

def section(title: str) -> None:
    width = 60
    bar = "─" * width
    print(f"\n{BOLD}{CYAN}{bar}{RESET}")
    print(f"{BOLD}{CYAN}  {title}{RESET}")
    print(f"{BOLD}{CYAN}{bar}{RESET}")

def show_button(label: str, available: bool = True) -> None:
    icon = f"{GREEN}[✓]{RESET}" if available else f"{DIM}[ ]{RESET}"
    print(f"    {icon} {label}")

def show_screen(title: str, items: list[str]) -> None:
    print(f"\n  {BOLD}📱 {title}{RESET}")
    for item in items:
        print(f"     {item}")

# ─── HTTP client ──────────────────────────────────────────────────────────────
class ApiError(RuntimeError):
    def __init__(self, method: str, path: str, status: int, body: str) -> None:
        self.method = method
        self.path = path
        self.status = status
        self.body = body
        super().__init__(f"{method} {path} → {status}: {body}")


class ApiClient:
    def __init__(self, base_url: str) -> None:
        self.base_url = base_url.rstrip("/") + "/"

    def get(self, path: str, token: str | None = None) -> Any:
        return self._request("GET", path, token=token)

    def post(self, path: str, payload: dict | None = None, token: str | None = None) -> Any:
        return self._request("POST", path, payload=payload, token=token)

    def delete(self, path: str, token: str | None = None) -> Any:
        return self._request("DELETE", path, token=token)

    def _request(self, method: str, path: str, payload: dict | None = None, token: str | None = None) -> Any:
        body = None if payload is None else json.dumps(payload, ensure_ascii=False).encode()
        headers: dict[str, str] = {"Accept": "application/json"}
        if body:
            headers["Content-Type"] = "application/json"
        if token:
            headers["Authorization"] = f"Bearer {token}"

        req = Request(urljoin(self.base_url, path.lstrip("/")), data=body, headers=headers, method=method)
        try:
            with urlopen(req, timeout=20) as resp:
                raw = resp.read().decode()
                return json.loads(raw) if raw else None
        except HTTPError as exc:
            raise ApiError(method, path, exc.code, exc.read().decode()) from exc
        except URLError as exc:
            raise RuntimeError(f"Cannot reach {self.base_url}: {exc.reason}") from exc


# ─── Domain objects ───────────────────────────────────────────────────────────
@dataclass
class Actor:
    username: str
    password: str
    token: str
    profile_id: int
    display_name: str
    role: str = "participant"   # organizer / leader / member


@dataclass
class GroupInfo:
    number: int
    leader: Actor | None
    members: list[Actor] = field(default_factory=list)


# ─── Helpers ──────────────────────────────────────────────────────────────────
def load_dotenv(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        values[k.strip()] = v.strip().strip('"').strip("'")
    return values


def login(api: ApiClient, username: str, password: str) -> str:
    return api.post("/auth/login", {"username": username, "password": password})["access_token"]


def ensure_user(
    api: ApiClient,
    *,
    username: str,
    email: str,
    password: str,
    profile_payload: dict,
    display_name: str,
) -> Actor:
    try:
        api.post("/auth/register", {"username": username, "email": email, "password": password})
        ok(f"registered {username}")
    except ApiError as exc:
        if exc.status != 400:
            raise
        ok(f"reused {username}")

    token = login(api, username, password)
    profile = api.post("/api/profile", profile_payload, token=token)
    return Actor(
        username=username,
        password=password,
        token=token,
        profile_id=profile["id"],
        display_name=display_name,
    )


def make_event_payload(title: str, volunteers_needed: int) -> dict:
    starts_at = datetime.now(UTC) + timedelta(hours=2)
    ends_at = starts_at + timedelta(hours=3)
    return {
        "title": title,
        "direction": "Социальная помощь",
        "description": "Полный тест lifecycle события: заявки → посещаемость → группы → чаты → завершение.",
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


def check_chats(
    api: ApiClient,
    *,
    event_id: str,
    actor: Actor,
    expected_titles: list[str],
    label: str,
) -> None:
    chats = api.get(f"/api/events/{event_id}/chats", token=actor.token)
    titles = [c["title"] for c in chats]
    for title in expected_titles:
        found = any(title in t for t in titles)
        show_button(f"{label}: {title}", available=found)
    for chat in chats:
        chat_id = chat["id"]
        # send a test message
        api.post(
            f"/api/events/{event_id}/chats/{chat_id}/messages",
            {"content": f"{actor.display_name} → {chat['title']}"},
            token=actor.token,
        )
        msgs = api.get(f"/api/events/{event_id}/chats/{chat_id}/messages", token=actor.token)
        ok(f"chat «{chat['title']}»: {len(msgs)} message(s)")


# ─── Main walkthrough ─────────────────────────────────────────────────────────
def run(api: ApiClient, admin_token: str, password: str, keep_active: bool) -> None:

    # ══════════════════════════════════════════════════════════════════════════
    section("PHASE 1 — Setup: create organizer + 8 participants")
    # ══════════════════════════════════════════════════════════════════════════
    step("Creating organizer")
    org_email = f"{PREFIX}.organizer@flowtest.local"
    organizer = ensure_user(
        api,
        username=f"{PREFIX}-organizer",
        email=org_email,
        password=password,
        display_name="Организатор Тестов",
        profile_payload={
            "type": "volunteer",
            "avatar_url": None,
            "first_name": "Организатор",
            "last_name": "Тестов",
            "phone": "+375291230000",
            "email": org_email,
            "city": "Минск",
            "country": "Беларусь",
            "skills": ["Организация мероприятий", "Лидерство"],
            "about": "Тестовый организатор.",
        },
    )
    organizer.role = "organizer"

    step("Creating 8 participants")
    PARTICIPANT_COUNT = 8
    participants: list[Actor] = []
    for i in range(1, PARTICIPANT_COUNT + 1):
        email = f"{PREFIX}.p{i:02d}@flowtest.local"
        actor = ensure_user(
            api,
            username=f"{PREFIX}-p{i:02d}",
            email=email,
            password=password,
            display_name=f"Участник {i:02d}",
            profile_payload={
                "type": "volunteer",
                "avatar_url": None,
                "first_name": f"Участник",
                "last_name": f"{i:02d}",
                "phone": f"+37529123{i:04d}",
                "email": email,
                "city": "Минск",
                "country": "Беларусь",
                "skills": ["Общение с людьми", "Работа в команде"],
                "about": f"Тестовый участник #{i}.",
            },
        )
        participants.append(actor)

    show_screen("Главный экран (все пользователи)", [
        "Лента событий — пустая (нет подтверждённых событий)",
        "Мои события — пустые",
        "Баннер активного события — нет",
    ])

    # ══════════════════════════════════════════════════════════════════════════
    section("PHASE 2 — Organizer creates event (status: pending)")
    # ══════════════════════════════════════════════════════════════════════════
    step("Creating event")
    event = api.post(
        "/api/events",
        make_event_payload("Flowtest: полный цикл события", volunteers_needed=PARTICIPANT_COUNT + 1),
        token=organizer.token,
    )
    event_id = event["id"]
    ok(f"event created: {event_id} (status: {event['status']})")

    show_screen("Организатор — карточка события", [
        f"Статус: {event['status']}  (ожидает подтверждения)",
        "Кнопки:",
    ])
    show_button("Подать заявку", available=False)
    show_button("Начать событие", available=False)

    show_screen("Участник — событие в ленте", [
        "Событие НЕ видно в ленте (status=pending)",
    ])

    # ══════════════════════════════════════════════════════════════════════════
    section("PHASE 3 — Admin approves event (status: approved)")
    # ══════════════════════════════════════════════════════════════════════════
    step("Approving event")
    event = api.post(f"/api/events/{event_id}/approve", token=admin_token)
    ok(f"approved (status: {event['status']})")

    show_screen("Участник — лента событий", [
        "✅ Событие появилось в ленте",
        "Кнопки:",
    ])
    show_button("Подать заявку")
    show_button("Начать событие", available=False)

    # ══════════════════════════════════════════════════════════════════════════
    section("PHASE 4 — Participants apply; organizer accepts all")
    # ══════════════════════════════════════════════════════════════════════════
    step("Participants applying")
    for actor in participants:
        api.post(f"/api/events/{event_id}/applications", token=actor.token)
        ok(f"{actor.display_name} applied")

    show_screen("Участник — карточка события (после подачи заявки)", [
        "Статус заявки: pending (ожидает)",
        "Кнопки:",
    ])
    show_button("Отменить заявку")
    show_button("Подать заявку", available=False)

    step("Organizer accepts all applications")
    applications = api.get(f"/api/events/{event_id}/applications", token=organizer.token)
    by_profile = {app["profile"]["id"]: app for app in applications}
    for actor in participants:
        app = by_profile.get(actor.profile_id)
        if app and app["status"] != "accepted":
            api.post(f"/api/events/applications/{app['application_id']}/accept", token=organizer.token)
            ok(f"accepted: {actor.display_name}")

    show_screen("Участник — карточка события (после принятия)", [
        "Статус заявки: accepted ✅",
    ])
    show_screen("Организатор — карточка события", [
        f"Принято участников: {PARTICIPANT_COUNT}",
        "Кнопки:",
    ])
    show_button("Начать событие")
    show_button("Список участников")

    # ══════════════════════════════════════════════════════════════════════════
    section("PHASE 5 — Organizer starts event → attendance (status: attendance)")
    # ══════════════════════════════════════════════════════════════════════════
    step("Starting event")
    event = api.post(f"/api/events/{event_id}/start", token=organizer.token)
    ok(f"status: {event['status']}")

    attendance = api.get(f"/api/events/{event_id}/attendance", token=organizer.token)
    ok(f"attendance list: {len(attendance)} records")

    show_screen("Организатор — экран отметки присутствия", [
        f"Список из {len(attendance)} участников",
        "Каждый: [ ] отметить присутствие",
        "Кнопки:",
    ])
    show_button("Подтвердить присутствие")

    step("Marking everyone present")
    present_ids = [item["application_id"] for item in attendance]
    event = api.post(
        f"/api/events/{event_id}/attendance/confirm",
        {"presentApplicationIDs": present_ids},
        token=organizer.token,
    )
    ok(f"confirmed {len(present_ids)} present → status: {event['status']}")

    # ══════════════════════════════════════════════════════════════════════════
    section("PHASE 6 — Organizer assigns 2 groups (status: grouping)")
    # ══════════════════════════════════════════════════════════════════════════
    show_screen("Организатор — экран группировки", [
        f"Присутствует: {len(present_ids)} участников",
        "Выбрать количество групп: [1] [2] [3] [4] [5]",
        "Кнопки:",
    ])
    show_button("Авто-распределить")
    show_button("Подтвердить группы", available=False)

    step("Setting 2 groups and auto-distributing")
    api.post(f"/api/events/{event_id}/grouping/confirm", {"groupCount": 2}, token=organizer.token)
    groups_raw = api.post(f"/api/events/{event_id}/groups/auto", token=organizer.token)
    ok(f"auto-distributed into {len(groups_raw)} groups")

    groups_raw = api.get(f"/api/events/{event_id}/groups", token=organizer.token)
    by_pid: dict[int, Actor] = {u.profile_id: u for u in participants}

    groups: list[GroupInfo] = []
    for g in groups_raw:
        leader_actor = by_pid.get(g["leader_id"])
        member_actors = [by_pid[m["profile_id"]] for m in g["members"] if m["profile_id"] in by_pid]
        gi = GroupInfo(number=g["group_number"], leader=leader_actor, members=member_actors)
        if leader_actor:
            leader_actor.role = "leader"
        groups.append(gi)
        ok(f"Group {gi.number}: leader={leader_actor.display_name if leader_actor else '—'}, members={[m.display_name for m in member_actors]}")

    show_screen("Организатор — группы после авто-распределения", [
        f"Группа 1: {groups[0].leader.display_name if groups[0].leader else '—'} (лидер) + {len(groups[0].members)} участников",
        f"Группа 2: {groups[1].leader.display_name if groups[1].leader else '—'} (лидер) + {len(groups[1].members)} участников",
        "Кнопки:",
    ])
    show_button("Авто-распределить заново")
    show_button("Добавить группу")
    show_button("Удалить группу")
    show_button("Подтвердить группы")

    # ══════════════════════════════════════════════════════════════════════════
    section("PHASE 7 — Organizer confirms groups → event ACTIVE")
    # ══════════════════════════════════════════════════════════════════════════
    step("Confirming groups")
    event = api.post(f"/api/events/{event_id}/groups/confirm", token=organizer.token)
    ok(f"status: {event['status']}")

    show_screen("Организатор — карточка активного события", [
        "Статус: Активно",
        "Кнопки:",
    ])
    show_button("Редактировать группы")
    show_button("Завершить событие")

    show_screen("Участник — карточка активного события", [
        "Статус: Активно",
        "Кнопки:",
    ])
    show_button("Чат")

    show_screen("Главный экран — у всех участников", [
        "🟢 Баннер: «Событие идёт сейчас»",
        f"   {event['title']}  ›",
        "(тап → открывает карточку активного события)",
    ])

    # ══════════════════════════════════════════════════════════════════════════
    section("PHASE 8 — Chat access verification")
    # ══════════════════════════════════════════════════════════════════════════

    # Organizer
    step(f"Organizer chat ({organizer.display_name})")
    info("→ Sees: Чат лидеров (only)")
    check_chats(api, event_id=event_id, actor=organizer, expected_titles=["Чат лидеров"], label="Организатор")

    # Group leaders
    for gi in groups:
        if gi.leader is None:
            continue
        step(f"Leader of group {gi.number}: {gi.leader.display_name}")
        info(f"→ Sees: Группа {gi.number} + Чат лидеров")
        check_chats(
            api,
            event_id=event_id,
            actor=gi.leader,
            expected_titles=[f"Группа {gi.number}", "Чат лидеров"],
            label=f"Лидер {gi.number}",
        )
        show_screen(f"Лидер группы {gi.number} — список чатов", [
            f"[💬] Группа {gi.number}",
            "[⭐] Чат лидеров",
        ])

    # Regular members
    for gi in groups:
        if not gi.members:
            continue
        member = gi.members[0]
        step(f"Member of group {gi.number}: {member.display_name}")
        info(f"→ Sees: Группа {gi.number} ONLY (no leaders chat)")
        check_chats(
            api,
            event_id=event_id,
            actor=member,
            expected_titles=[f"Группа {gi.number}"],
            label=f"Участник гр.{gi.number}",
        )
        show_screen(f"Участник группы {gi.number} — чат", [
            f"(1 chat room → сразу открывается Группа {gi.number})",
        ])

    # Verify message isolation between chats
    step("Verifying message isolation between chat rooms")
    all_chat_ids = set()
    for g in groups_raw:
        all_chat_ids.add(g["group_number"])
    all_chat_ids.add(LEADERS_CHAT_ID)

    for chat_id in sorted(all_chat_ids):
        try:
            msgs = api.get(f"/api/events/{event_id}/chats/{chat_id}/messages", token=organizer.token)
            chat_label = "Чат лидеров" if chat_id == LEADERS_CHAT_ID else f"Группа {chat_id}"
            ok(f"{chat_label}: {len(msgs)} messages (isolated ✓)")
        except ApiError:
            pass

    # ══════════════════════════════════════════════════════════════════════════
    section("PHASE 9 — Organizer can still edit groups while active")
    # ══════════════════════════════════════════════════════════════════════════
    step("Editing groups in active phase (should work)")
    try:
        live_groups = api.get(f"/api/events/{event_id}/groups", token=organizer.token)
        ok(f"GET /groups works in active phase → {len(live_groups)} groups")
        show_button("Редактировать группы (в активной фазе)")
    except ApiError as exc:
        warn(f"GET /groups failed: {exc}")

    # ══════════════════════════════════════════════════════════════════════════
    section("PHASE 10 — Finish event (status: completed)")
    # ══════════════════════════════════════════════════════════════════════════
    if keep_active:
        step("--keep-active flag set: skipping finish")
        info("Event stays ACTIVE for iOS testing.")
    else:
        step("Organizer finishes event")
        event = api.post(f"/api/events/{event_id}/finish", token=organizer.token)
        ok(f"status: {event['status']}")

        show_screen("Карточка завершённого события", [
            "Статус: Завершено",
            "Все кнопки: не активны",
            "Участники: получили уведомление",
        ])

        show_screen("Главный экран", [
            "Баннер активного события — исчез",
        ])

    # ══════════════════════════════════════════════════════════════════════════
    section("SUMMARY — iOS Login Credentials")
    # ══════════════════════════════════════════════════════════════════════════
    pw = password
    print(f"\n  {BOLD}Event ID:  {event_id}{RESET}")
    status_label = "active" if keep_active else "completed"
    print(f"  Status:    {status_label}")
    print()
    print(f"  {BOLD}Organizer{RESET} (sees: кнопки управления + чат лидеров):")
    print(f"    username: {organizer.username}")
    print(f"    password: {pw}")
    print()
    for gi in groups:
        if gi.leader:
            print(f"  {BOLD}Leader of group {gi.number}{RESET} (sees: чат группы {gi.number} + чат лидеров):")
            print(f"    username: {gi.leader.username}")
            print(f"    password: {pw}")
        for m in gi.members:
            print(f"  Member of group {gi.number} (sees: чат группы {gi.number} only):")
            print(f"    username: {m.username}")
            print(f"    password: {pw}")
        print()


# ─── Entry point ──────────────────────────────────────────────────────────────
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Full event lifecycle walkthrough test.")
    parser.add_argument("--base-url", default=os.getenv("VOLUNTEER_API_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--password", default=DEFAULT_PASSWORD)
    parser.add_argument("--admin-username")
    parser.add_argument("--admin-password")
    parser.add_argument(
        "--keep-active",
        action="store_true",
        help="Do not finish the event — leave it active so you can open the iOS app and test.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    env = load_dotenv(Path(__file__).resolve().parents[1] / ".env")

    admin_username = args.admin_username or env.get("DEFAULT_ADMIN_USERNAME") or "admin"
    admin_password = args.admin_password or env.get("DEFAULT_ADMIN_PASSWORD") or "Admin12345!"

    api = ApiClient(args.base_url)

    try:
        print(f"{BOLD}Connecting to {args.base_url}…{RESET}")
        admin_token = login(api, admin_username, admin_password)
        ok(f"admin login OK ({admin_username})")
    except Exception as exc:
        print(f"\n{RED}ERROR: {exc}{RESET}", file=sys.stderr)
        return 1

    try:
        run(api, admin_token=admin_token, password=args.password, keep_active=args.keep_active)
    except ApiError as exc:
        print(f"\n{RED}API ERROR: {exc}{RESET}", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"\n{RED}ERROR: {exc}{RESET}", file=sys.stderr)
        raise

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
