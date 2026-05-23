"""Shared auth/session helpers used by auth_routes and user_state_routes."""

import sqlite3
from typing import Optional

from db.database import DB_PATH


def open_conn() -> sqlite3.Connection:
    """Open a SQLite connection with Row factory (5s busy timeout)."""
    conn = sqlite3.connect(DB_PATH, timeout=5)
    conn.row_factory = sqlite3.Row
    return conn


def extract_bearer_token(auth_header: Optional[str]) -> Optional[str]:
    """Parse ``Authorization: Bearer <token>`` → token string (or None)."""
    if not auth_header:
        return None
    parts = auth_header.strip().split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None
    token = parts[1].strip()
    return token or None
