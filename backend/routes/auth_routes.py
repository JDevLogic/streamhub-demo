import hashlib
import hmac
import secrets
import sqlite3
import time
from typing import Optional

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from auth_utils import extract_bearer_token as _extract_bearer_token, open_conn as _open_conn

router = APIRouter(prefix="/auth", tags=["auth"])

_SESSION_TTL_SECONDS = 60 * 60 * 24 * 30  # 30 days


class RegisterBody(BaseModel):
    username: str = Field(min_length=3, max_length=40)
    email: str = Field(min_length=5, max_length=120)
    password: str = Field(min_length=6, max_length=200)


class LoginBody(BaseModel):
    identifier: str = Field(min_length=3, max_length=120)
    password: str = Field(min_length=6, max_length=200)


def _hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    derived = hashlib.scrypt(
        password.encode("utf-8"),
        salt=bytes.fromhex(salt),
        n=2**14,
        r=8,
        p=1,
        dklen=32,
    )
    return f"scrypt${salt}${derived.hex()}"


def _verify_password(password: str, stored: str) -> bool:
    try:
        algo, salt_hex, digest_hex = stored.split("$", 2)
        if algo != "scrypt":
            return False
        candidate = hashlib.scrypt(
            password.encode("utf-8"),
            salt=bytes.fromhex(salt_hex),
            n=2**14,
            r=8,
            p=1,
            dklen=32,
        ).hex()
        return hmac.compare_digest(candidate, digest_hex)
    except Exception:
        return False


def _get_user_by_session_token(token: str) -> Optional[sqlite3.Row]:
    now = time.time()
    with _open_conn() as conn:
        row = conn.execute(
            """
            SELECT u.id, u.username, u.email
            FROM user_sessions s
            JOIN users u ON u.id = s.user_id
            WHERE s.token = ? AND s.expires_at > ?
            """,
            (token, now),
        ).fetchone()
        return row


@router.post("/register")
async def register(payload: RegisterBody):
    username = payload.username.strip()
    email = payload.email.strip().lower()
    password = payload.password

    if not username or not email:
        raise HTTPException(status_code=400, detail="Datos inválidos")

    pw_hash = _hash_password(password)
    now = time.time()

    with _open_conn() as conn:
        try:
            cur = conn.execute(
                """
                INSERT INTO users (username, email, password_hash, created_at)
                VALUES (?, ?, ?, ?)
                """,
                (username, email, pw_hash, now),
            )
            user_id = int(cur.lastrowid)
            conn.commit()
        except sqlite3.IntegrityError:
            raise HTTPException(status_code=409, detail="Usuario o email ya existe")

    return {"ok": True, "user_id": user_id}


@router.post("/login")
async def login(payload: LoginBody):
    identifier = payload.identifier.strip()
    password = payload.password
    if not identifier:
        raise HTTPException(status_code=400, detail="Credenciales inválidas")

    with _open_conn() as conn:
        user = conn.execute(
            """
            SELECT id, username, email, password_hash
            FROM users
            WHERE lower(email) = lower(?) OR lower(username) = lower(?)
            LIMIT 1
            """,
            (identifier, identifier),
        ).fetchone()

        if not user or not _verify_password(password, str(user["password_hash"])):
            raise HTTPException(status_code=401, detail="Credenciales inválidas")

        token = secrets.token_urlsafe(48)
        expires_at = time.time() + _SESSION_TTL_SECONDS
        conn.execute(
            """
            INSERT INTO user_sessions (token, user_id, created_at, expires_at)
            VALUES (?, ?, ?, ?)
            """,
            (token, int(user["id"]), time.time(), expires_at),
        )
        conn.commit()

    return {
        "ok": True,
        "access_token": token,
        "token_type": "bearer",
        "expires_at": expires_at,
        "user": {
            "id": int(user["id"]),
            "username": str(user["username"]),
            "email": str(user["email"]),
        },
    }


@router.get("/me")
async def me(authorization: Optional[str] = Header(default=None)):
    token = _extract_bearer_token(authorization)
    if not token:
        raise HTTPException(status_code=401, detail="No autenticado")

    user = _get_user_by_session_token(token)
    if not user:
        raise HTTPException(status_code=401, detail="Sesión inválida")

    return {
        "id": int(user["id"]),
        "username": str(user["username"]),
        "email": str(user["email"]),
    }


@router.post("/logout")
async def logout(authorization: Optional[str] = Header(default=None)):
    token = _extract_bearer_token(authorization)
    if not token:
        return {"ok": True}

    with _open_conn() as conn:
        conn.execute("DELETE FROM user_sessions WHERE token = ?", (token,))
        conn.commit()
    return {"ok": True}
