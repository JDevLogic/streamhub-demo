"""SQLite connection and schema initialisation.

Single responsibility: open connections and ensure tables exist.
No business logic, no scraping.
"""

import os
import sqlite3
from pathlib import Path

_DB_DIR = Path(os.environ.get("DB_DIR", str(Path(__file__).resolve().parent)))
DB_PATH = _DB_DIR / "anime_cache.db"

_DDL = """
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;

CREATE TABLE IF NOT EXISTS rate_limit_log (
    key TEXT NOT NULL,
    ts  REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS rl_key_ts ON rate_limit_log(key, ts);

CREATE TABLE IF NOT EXISTS intro_skips (
    episodio_url TEXT PRIMARY KEY,
    label        TEXT NOT NULL DEFAULT '',
    intro_start  REAL NOT NULL DEFAULT 0,
    intro_end    REAL NOT NULL DEFAULT 85,
    updated_at   REAL NOT NULL,
    no_intro     INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS seen_episodes (
    episodio_url TEXT PRIMARY KEY,
    last_seen    REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT NOT NULL UNIQUE,
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at    REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS user_sessions (
    token      TEXT PRIMARY KEY,
    user_id    INTEGER NOT NULL,
    created_at REAL NOT NULL,
    expires_at REAL NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions(expires_at);

CREATE TABLE IF NOT EXISTS user_state (
    user_id     INTEGER PRIMARY KEY,
    payload     TEXT NOT NULL,
    updated_at  REAL NOT NULL,
    version     INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Telemetry Phase 4: durable hourly rollup of source outcomes so the
-- dashboard can answer "when do failures happen" (objective #3). One row
-- per (source, outcome, err_category, day, hour); count incremented in
-- place. day/hour are server-local time. err_category is '' for non-fail.
CREATE TABLE IF NOT EXISTS source_events_hourly (
    source       TEXT NOT NULL,
    outcome      TEXT NOT NULL,
    err_category TEXT NOT NULL DEFAULT '',
    day          TEXT NOT NULL,
    hour         INTEGER NOT NULL,
    count        INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (source, outcome, err_category, day, hour)
);
CREATE INDEX IF NOT EXISTS idx_seh_source_day
    ON source_events_hourly(source, day);
"""


def _migrate(conn: sqlite3.Connection) -> None:
    """Apply schema migrations. Idempotent — safe to run every startup."""
    # intro_skips: migrate old schema (anime_url PK) to new (episodio_url PK)
    intro_cols = {row[1] for row in conn.execute("PRAGMA table_info(intro_skips)")}
    if "anime_url" in intro_cols:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS intro_skips_new (
                episodio_url TEXT PRIMARY KEY,
                label        TEXT NOT NULL DEFAULT '',
                intro_start  REAL NOT NULL DEFAULT 0,
                intro_end    REAL NOT NULL DEFAULT 85,
                updated_at   REAL NOT NULL,
                no_intro     INTEGER NOT NULL DEFAULT 0
            );
            INSERT OR IGNORE INTO intro_skips_new
                SELECT anime_url, COALESCE(anime_title,''), intro_start, intro_end, updated_at, 0
                FROM intro_skips;
            DROP TABLE intro_skips;
            ALTER TABLE intro_skips_new RENAME TO intro_skips;
        """)
    intro_cols = {row[1] for row in conn.execute("PRAGMA table_info(intro_skips)")}
    if "no_intro" not in intro_cols:
        conn.execute(
            "ALTER TABLE intro_skips ADD COLUMN no_intro INTEGER NOT NULL DEFAULT 0"
        )

    # user_state: add version column for optimistic concurrency control.
    user_state_cols = {row[1] for row in conn.execute("PRAGMA table_info(user_state)")}
    if "version" not in user_state_cols:
        conn.execute(
            "ALTER TABLE user_state ADD COLUMN version INTEGER NOT NULL DEFAULT 0"
        )


def get_db_connection() -> sqlite3.Connection:
    """Return an open WAL-mode connection with Row factory enabled."""
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Create all tables and apply migrations. Safe to call multiple times."""
    with get_db_connection() as conn:
        conn.executescript(_DDL)
        _migrate(conn)
