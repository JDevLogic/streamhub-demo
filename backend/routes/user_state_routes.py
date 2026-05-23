import json
import time
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel

from auth_utils import extract_bearer_token as _extract_bearer_token, open_conn as _open_conn
from security import require_api_key

router = APIRouter(prefix="/user/state", tags=["user-state"], dependencies=[Depends(require_api_key)])


class UserStateBody(BaseModel):
    payload: dict
    # Optimistic concurrency: client sends the version it last observed.
    # Server rejects with 409 if it no longer matches, forcing a re-merge.
    # Absent/null disables the check (legacy clients).
    expected_version: Optional[int] = None


def _require_user_id_from_auth(authorization: Optional[str]) -> int:
    token = _extract_bearer_token(authorization)
    if not token:
        raise HTTPException(status_code=401, detail="No autenticado")
    now = time.time()
    with _open_conn() as conn:
        row = conn.execute(
            "SELECT user_id FROM user_sessions WHERE token = ? AND expires_at > ?",
            (token, now),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Sesión inválida")
    return int(row["user_id"])


@router.get("")
async def get_user_state(authorization: Optional[str] = Header(default=None)):
    user_id = _require_user_id_from_auth(authorization)
    with _open_conn() as conn:
        row = conn.execute(
            "SELECT payload, updated_at, version FROM user_state WHERE user_id = ?",
            (user_id,),
        ).fetchone()
    if not row:
        return {"payload": None, "updated_at": None, "version": 0}
    return {
        "payload": json.loads(str(row["payload"])),
        "updated_at": float(row["updated_at"]),
        "version": int(row["version"]),
    }


@router.post("")
async def save_user_state(
    body: UserStateBody,
    authorization: Optional[str] = Header(default=None),
):
    user_id = _require_user_id_from_auth(authorization)
    now = time.time()
    payload_json = json.dumps(body.payload, ensure_ascii=False, separators=(",", ":"))
    with _open_conn() as conn:
        # BEGIN IMMEDIATE acquires the write lock up-front, so concurrent
        # uploads from two devices serialize here and the version check is
        # effectively atomic.
        conn.execute("BEGIN IMMEDIATE")
        row = conn.execute(
            "SELECT version FROM user_state WHERE user_id = ?",
            (user_id,),
        ).fetchone()
        current_version = int(row["version"]) if row else 0

        if body.expected_version is not None and body.expected_version != current_version:
            conn.execute("ROLLBACK")
            raise HTTPException(
                status_code=409,
                detail={
                    "error": "version_conflict",
                    "current_version": current_version,
                },
            )

        new_version = current_version + 1
        conn.execute(
            """
            INSERT INTO user_state (user_id, payload, updated_at, version)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
              payload = excluded.payload,
              updated_at = excluded.updated_at,
              version = excluded.version
            """,
            (user_id, payload_json, now, new_version),
        )
        conn.commit()
    return {"ok": True, "updated_at": now, "version": new_version}
