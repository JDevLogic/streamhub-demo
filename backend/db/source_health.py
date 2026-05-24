"""Demo source health tracking for the public portfolio version.

This module keeps the same public functions used by the dashboard, but only
tracks safe demo sources.
"""

from __future__ import annotations

import functools
import threading
import time
from collections import defaultdict, deque
from typing import Callable


WINDOW_SIZE = 50
ERR_MAX_LEN = 300


SOURCES: dict[str, dict] = {
    "mock_catalog": {
        "label": "Mock Catalog",
        "kind": "provider",
        "primary": True,
    },
    "mock_metadata": {
        "label": "Mock Metadata",
        "kind": "api",
        "primary": False,
    },
    "demo_video": {
        "label": "Demo Video",
        "kind": "media",
        "primary": False,
    },
}


_lock = threading.Lock()
_events: dict[str, deque[tuple[str, float]]] = defaultdict(
    lambda: deque(maxlen=WINDOW_SIZE)
)
_last_ok: dict[str, float] = {}
_last_empty: dict[str, float] = {}
_last_fail: dict[str, float] = {}
_last_err: dict[str, str] = {}


def record_success(source: str, elapsed_ms: float) -> None:
    now = time.time()
    elapsed = round(float(elapsed_ms), 1)

    with _lock:
        _events[source].append(("ok", elapsed))
        _last_ok[source] = now


def record_empty(source: str, elapsed_ms: float) -> None:
    now = time.time()
    elapsed = round(float(elapsed_ms), 1)

    with _lock:
        _events[source].append(("empty", elapsed))
        _last_empty[source] = now


def record_failure(source: str, error: str, elapsed_ms: float) -> None:
    now = time.time()
    elapsed = round(float(elapsed_ms), 1)
    err_msg = (error or "unknown error")[:ERR_MAX_LEN]

    with _lock:
        _events[source].append(("fail", elapsed))
        _last_fail[source] = now
        _last_err[source] = err_msg


def reset(source: str) -> None:
    with _lock:
        _events.pop(source, None)
        _last_ok.pop(source, None)
        _last_empty.pop(source, None)
        _last_fail.pop(source, None)
        _last_err.pop(source, None)


def _stats_from_events(events: list[tuple[str, float]]) -> dict:
    ok_count = sum(1 for outcome, _ in events if outcome == "ok")
    empty_count = sum(1 for outcome, _ in events if outcome == "empty")
    fail_count = sum(1 for outcome, _ in events if outcome == "fail")
    times = sorted(elapsed for _, elapsed in events)
    total = len(events)

    avg_ms = round(sum(times) / len(times), 1) if times else None
    p95_ms = round(times[int(len(times) * 0.95)], 1) if times else None
    success_rate = round(ok_count / total, 3) if total else None

    return {
        "ok_count": ok_count,
        "empty_count": empty_count,
        "fail_count": fail_count,
        "total": total,
        "success_rate": success_rate,
        "avg_ms": avg_ms,
        "p95_ms": p95_ms,
    }


def _classify(ok_count: int, empty_count: int, fail_count: int) -> str:
    total = ok_count + empty_count + fail_count

    if total == 0:
        return "idle"

    success_rate = ok_count / total

    if success_rate >= 0.9:
        return "green"

    if success_rate >= 0.5:
        return "amber"

    return "red"


def _snapshot_one(name: str) -> dict:
    meta = SOURCES.get(
        name,
        {
            "label": name,
            "kind": "unknown",
            "primary": False,
        },
    )

    with _lock:
        events = list(_events.get(name, ()))
        last_ok = _last_ok.get(name)
        last_empty = _last_empty.get(name)
        last_fail = _last_fail.get(name)
        last_error = _last_err.get(name)

    stats = _stats_from_events(events)
    status = _classify(
        stats["ok_count"],
        stats["empty_count"],
        stats["fail_count"],
    )

    return {
        "name": name,
        "label": meta["label"],
        "kind": meta["kind"],
        "primary": meta["primary"],
        "status": status,
        "last_ok": last_ok,
        "last_empty": last_empty,
        "last_fail": last_fail,
        "last_error": last_error,
        "error_categories": [],
        **stats,
    }


def snapshot() -> list[dict]:
    """Return a list with one dict per registered demo source."""
    return [_snapshot_one(name) for name in SOURCES]


def track_source(name: str, track_empty: bool = False) -> Callable:
    """Decorator that records source health for demo providers."""

    def _decorator(fn: Callable) -> Callable:
        @functools.wraps(fn)
        def _wrapper(*args, **kwargs):
            t0 = time.perf_counter()

            try:
                result = fn(*args, **kwargs)
            except Exception as exc:
                elapsed = (time.perf_counter() - t0) * 1000
                record_failure(name, f"{type(exc).__name__}: {exc}", elapsed)
                raise

            elapsed = (time.perf_counter() - t0) * 1000

            if track_empty and not result:
                record_empty(name, elapsed)
            else:
                record_success(name, elapsed)

            return result

        return _wrapper

    return _decorator

