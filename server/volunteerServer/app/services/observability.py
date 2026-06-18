from __future__ import annotations

import logging
from collections import Counter
from threading import RLock

logger = logging.getLogger("app.geocode")


class InMemoryMetrics:
    def __init__(self):
        self._counter = Counter()
        self._lock = RLock()

    def inc(self, key: str, value: int = 1) -> None:
        with self._lock:
            self._counter[key] += value

    def snapshot(self) -> dict[str, int]:
        with self._lock:
            return dict(self._counter)


metrics = InMemoryMetrics()
