from __future__ import annotations

from collections import defaultdict, deque
from threading import RLock
from time import monotonic


class InMemoryRateLimiter:
    def __init__(self):
        self._events: dict[str, deque[float]] = defaultdict(deque)
        self._lock = RLock()

    def allow(self, key: str, max_requests: int, window_seconds: int) -> bool:
        now = monotonic()
        threshold = now - window_seconds
        with self._lock:
            bucket = self._events[key]
            while bucket and bucket[0] <= threshold:
                bucket.popleft()
            if len(bucket) >= max_requests:
                return False
            bucket.append(now)
            return True


rate_limiter = InMemoryRateLimiter()
