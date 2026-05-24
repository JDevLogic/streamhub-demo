import os
import tempfile

import pytest

# Estas variables deben estar definidas ANTES de importar la app,
# porque security.py y dashboard/routes.py las leen en tiempo de importación.
_test_db = tempfile.mkdtemp()
os.environ.setdefault("API_KEY", "test-api-key")
os.environ.setdefault("DASHBOARD_USER", "testadmin")
os.environ.setdefault("DASHBOARD_PASS", "testpass123")
os.environ.setdefault("DATA_PROVIDER", "mock")
os.environ["DB_DIR"] = _test_db

API_KEY = os.environ["API_KEY"]


@pytest.fixture(scope="session")
def client():
    from fastapi.testclient import TestClient
    from app import app

    with TestClient(app) as c:
        yield c


@pytest.fixture(scope="module")
def auth_token(client):
    """Registra un usuario de prueba y devuelve su Bearer token."""
    payload = {
        "username": "testuser",
        "email": "testuser@example.com",
        "password": "password123",
    }
    client.post("/auth/register", json=payload, headers={"X-API-Key": API_KEY})
    r = client.post(
        "/auth/login",
        json={"identifier": payload["username"], "password": payload["password"]},
        headers={"X-API-Key": API_KEY},
    )
    return r.json()["access_token"]
