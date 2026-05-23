"""Durable hourly rollup of source outcomes — Phase 4 of the telemetry plan.

Answers objective #3: *when* do failures happen (e.g. a source that
degrades at night). The live traffic-light view lives in
:mod:`db.source_health` (rolling 50-event window in Redis); this module is
the long-term history, backed by the shared SQLite DB so it survives
restarts and Redis flushes.

Design notes
------------
* One row per ``(source, outcome, err_category, day, hour)``; ``count`` is
  incremented in place via an UPSERT.
* Writes are **best-effort**: a telemetry failure must never break a
  scrape, so :func:`record` swallows every exception.
* Writes run inline (one tiny UPSERT) rather than via a scheduler flush.
  At this app's volume the cost is negligible, and — unlike a per-process
  in-memory accumulator flushed by the single scheduler-lock owner — every
  worker process persists its own events with no data loss.
* ``day``/``hour`` are **server-local** time; the dashboard shows them
  as-is. A timezone offset can be layered on later if needed.
* Old buckets are pruned by a daily scheduler job (see ``scheduler.py``).
"""

from __future__ import annotations

import logging
import time
from datetime import datetime

from db.database import get_db_connection

_log = logging.getLogger(__name__)

RETENTION_DAYS = 90


def record(source: str, outcome: str, err_category: str | None = None) -> None:
    """Increment the hourly bucket for one event. Best-effort, never raises."""
    try:
        now = datetime.now()
        day = now.strftime("%Y-%m-%d")
        hour = now.hour
        cat = err_category or ""
        conn = get_db_connection()
        try:
            conn.execute("PRAGMA busy_timeout=3000")
            conn.execute(
                """
                INSERT INTO source_events_hourly
                    (source, outcome, err_category, day, hour, count)
                VALUES (?, ?, ?, ?, ?, 1)
                ON CONFLICT(source, outcome, err_category, day, hour)
                DO UPDATE SET count = count + 1
                """,
                (source, outcome, cat, day, hour),
            )
            conn.commit()
        finally:
            conn.close()
    except Exception as exc:  # telemetry must not break the caller
        _log.debug("event_history.record skipped (%s/%s): %s",
                   source, outcome, exc)


def history(source: str, days: int = 7) -> dict:
    """Hourly + daily aggregates for one source over the last ``days`` days.

    ``by_hour`` always has 24 entries (0-23) so the dashboard can render a
    fixed strip even for sparse data.
    """
    days = max(1, min(int(days), RETENTION_DAYS))
    since_day = datetime.fromtimestamp(
        time.time() - days * 86400
    ).strftime("%Y-%m-%d")

    by_hour = {h: {"ok": 0, "empty": 0, "fail": 0} for h in range(24)}
    by_day: dict[str, dict] = {}
    by_category: dict[str, int] = {}

    rows = []
    try:
        conn = get_db_connection()
        try:
            rows = conn.execute(
                """
                SELECT outcome, err_category, day, hour, SUM(count) AS c
                FROM source_events_hourly
                WHERE source = ? AND day >= ?
                GROUP BY outcome, err_category, day, hour
                """,
                (source, since_day),
            ).fetchall()
        finally:
            conn.close()
    except Exception as exc:
        _log.debug("event_history.history failed (%s): %s", source, exc)

    for r in rows:
        outcome = r["outcome"]
        c = int(r["c"])
        h = int(r["hour"])
        if 0 <= h <= 23 and outcome in by_hour[h]:
            by_hour[h][outcome] += c
        d = by_day.setdefault(r["day"], {"ok": 0, "empty": 0, "fail": 0})
        if outcome in d:
            d[outcome] += c
        if outcome == "fail" and r["err_category"]:
            by_category[r["err_category"]] = (
                by_category.get(r["err_category"], 0) + c
            )

    return {
        "source": source,
        "days": days,
        "by_hour": [{"hour": h, **by_hour[h]} for h in range(24)],
        "by_day": [{"day": d, **v} for d, v in sorted(by_day.items())],
        "by_category": [
            {"category": k, "count": v}
            for k, v in sorted(
                by_category.items(), key=lambda kv: kv[1], reverse=True
            )
        ],
    }


def prune(retention_days: int = RETENTION_DAYS) -> int:
    """Delete buckets older than ``retention_days``. Returns rows removed."""
    try:
        cutoff = datetime.fromtimestamp(
            time.time() - retention_days * 86400
        ).strftime("%Y-%m-%d")
        conn = get_db_connection()
        try:
            cur = conn.execute(
                "DELETE FROM source_events_hourly WHERE day < ?", (cutoff,)
            )
            conn.commit()
            return cur.rowcount
        finally:
            conn.close()
    except Exception as exc:
        _log.debug("event_history.prune failed: %s", exc)
        return 0
