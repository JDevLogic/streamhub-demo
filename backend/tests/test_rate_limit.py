"""Tests del rate limiter SQLite sliding-window."""

import sqlite3
import time

import pytest

from security import SQLiteRateLimiter


@pytest.fixture
def rl_db(tmp_path):
    """DB temporal con la tabla rate_limit_log."""
    path = str(tmp_path / "rl_test.db")
    with sqlite3.connect(path) as conn:
        conn.execute("PRAGMA journal_mode=DELETE")
        conn.execute(
            "CREATE TABLE rate_limit_log (key TEXT NOT NULL, ts REAL NOT NULL)"
        )
    yield path


# -- Lógica del limiter ----------------------------------------------------

class TestSQLiteRateLimiter:
    def test_permite_hasta_el_limite(self, rl_db):
        rl = SQLiteRateLimiter(rl_db, default_limit=3, window=60)
        assert rl._check("ip:1.2.3.4", 3) is True
        assert rl._check("ip:1.2.3.4", 3) is True
        assert rl._check("ip:1.2.3.4", 3) is True

    def test_bloquea_al_superar_el_limite(self, rl_db):
        rl = SQLiteRateLimiter(rl_db, default_limit=3, window=60)
        for _ in range(3):
            rl._check("ip:1.2.3.4", 3)
        assert rl._check("ip:1.2.3.4", 3) is False

    def test_keys_distintas_son_independientes(self, rl_db):
        rl = SQLiteRateLimiter(rl_db, default_limit=1, window=60)
        assert rl._check("ip:1.1.1.1", 1) is True
        assert rl._check("ip:2.2.2.2", 1) is True

    def test_primera_peticion_siempre_permitida(self, rl_db):
        rl = SQLiteRateLimiter(rl_db, default_limit=100, window=60)
        assert rl._check("ip:nuevo", 100) is True

    def test_ventana_deslizante_expira_entradas(self, rl_db):
        rl = SQLiteRateLimiter(rl_db, default_limit=1, window=1)
        assert rl._check("ip:1.2.3.4", 1) is True
        assert rl._check("ip:1.2.3.4", 1) is False   # dentro de la ventana
        time.sleep(1.1)
        assert rl._check("ip:1.2.3.4", 1) is True    # ventana expirada

    def test_limite_uno_bloquea_segunda_peticion(self, rl_db):
        rl = SQLiteRateLimiter(rl_db, default_limit=1, window=60)
        rl._check("ip:x", 1)
        assert rl._check("ip:x", 1) is False

    def test_entradas_antiguas_no_cuentan(self, rl_db):
        rl = SQLiteRateLimiter(rl_db, default_limit=2, window=60)
        # Insertar una entrada caducada manualmente
        past = time.time() - 120
        with sqlite3.connect(rl_db) as conn:
            conn.execute(
                "INSERT INTO rate_limit_log (key, ts) VALUES (?, ?)",
                ("ip:5.5.5.5", past),
            )
        # La entrada antigua no cuenta: permite 2 peticiones nuevas
        assert rl._check("ip:5.5.5.5", 2) is True
        assert rl._check("ip:5.5.5.5", 2) is True
        assert rl._check("ip:5.5.5.5", 2) is False


# -- Integración HTTP -------------------------------------------------------

class TestRateLimitHTTP:
    def test_superar_limite_devuelve_429(self, client):
        """Pre-carga el bucket de la IP del test client y comprueba el 429."""
        from app import _limiter
        from db.database import DB_PATH

        key = "global:testclient"
        now = time.time()

        with sqlite3.connect(str(DB_PATH)) as conn:
            for _ in range(_limiter.default_limit):
                conn.execute(
                    "INSERT INTO rate_limit_log (key, ts) VALUES (?, ?)",
                    (key, now),
                )

        try:
            r = client.get("/health")
            assert r.status_code == 429
        finally:
            with sqlite3.connect(str(DB_PATH)) as conn:
                conn.execute("DELETE FROM rate_limit_log WHERE key = ?", (key,))
