"""Tests del endpoint de sincronización de estado de usuario."""

import uuid

import pytest

API_KEY = "test-api-key"
HEADERS = {"X-API-Key": API_KEY}


def _bearer(token: str) -> dict:
    return {**HEADERS, "Authorization": f"Bearer {token}"}


@pytest.fixture
def fresh_token(client):
    """Crea un usuario único por test y devuelve su Bearer token."""
    uid = uuid.uuid4().hex[:8]
    payload = {
        "username": f"fresh_{uid}",
        "email": f"fresh_{uid}@example.com",
        "password": "password123",
    }
    client.post("/auth/register", json=payload, headers=HEADERS)
    r = client.post(
        "/auth/login",
        json={"identifier": payload["username"], "password": payload["password"]},
        headers=HEADERS,
    )
    return r.json()["access_token"]


# -- Autenticación ----------------------------------------------------------

def test_get_sin_api_key_devuelve_422(client):
    r = client.get("/user/state")
    assert r.status_code == 422


def test_get_sin_bearer_devuelve_401(client):
    r = client.get("/user/state", headers=HEADERS)
    assert r.status_code == 401


def test_post_sin_bearer_devuelve_401(client):
    r = client.post("/user/state", json={"payload": {}}, headers=HEADERS)
    assert r.status_code == 401


def test_get_con_token_invalido_devuelve_401(client):
    r = client.get("/user/state", headers={**HEADERS, "Authorization": "Bearer token-falso"})
    assert r.status_code == 401


# -- Estado inicial ---------------------------------------------------------

def test_get_usuario_sin_estado_devuelve_null(client, fresh_token):
    r = client.get("/user/state", headers=_bearer(fresh_token))
    assert r.status_code == 200
    data = r.json()
    assert data["payload"] is None
    assert data["version"] == 0


# -- Guardar y recuperar estado ---------------------------------------------

def test_post_guarda_estado(client, auth_token):
    payload = {"myList": [{"animeUrl": "demo://content/test", "titulo": "Test"}]}
    r = client.post("/user/state", json={"payload": payload}, headers=_bearer(auth_token))
    assert r.status_code == 200
    data = r.json()
    assert data["ok"] is True
    assert data["version"] >= 1


def test_get_devuelve_estado_guardado(client, auth_token):
    payload = {"myList": [{"animeUrl": "demo://content/test", "titulo": "Test"}]}
    client.post("/user/state", json={"payload": payload}, headers=_bearer(auth_token))

    r = client.get("/user/state", headers=_bearer(auth_token))
    assert r.status_code == 200
    data = r.json()
    assert data["payload"] is not None
    assert data["version"] >= 1
    assert "myList" in data["payload"]


def test_segunda_actualizacion_incrementa_version(client, auth_token):
    client.post("/user/state", json={"payload": {"setup": True}}, headers=_bearer(auth_token))
    r1 = client.get("/user/state", headers=_bearer(auth_token))
    version_antes = r1.json()["version"]

    payload = {"myList": [], "progress": []}
    r2 = client.post("/user/state", json={"payload": payload}, headers=_bearer(auth_token))
    assert r2.json()["version"] == version_antes + 1


# -- Control de versión optimista -------------------------------------------

def test_expected_version_correcta_acepta_escritura(client, auth_token):
    r = client.get("/user/state", headers=_bearer(auth_token))
    version_actual = r.json()["version"]

    r2 = client.post(
        "/user/state",
        json={"payload": {"myList": []}, "expected_version": version_actual},
        headers=_bearer(auth_token),
    )
    assert r2.status_code == 200
    assert r2.json()["version"] == version_actual + 1


def test_expected_version_incorrecta_devuelve_409(client, auth_token):
    r = client.post(
        "/user/state",
        json={"payload": {"myList": []}, "expected_version": 99999},
        headers=_bearer(auth_token),
    )
    assert r.status_code == 409
    data = r.json()
    assert data["detail"]["error"] == "version_conflict"
    assert "current_version" in data["detail"]


def test_sin_expected_version_siempre_acepta(client, auth_token):
    """Sin expected_version el endpoint no hace comprobación de versión."""
    r = client.post(
        "/user/state",
        json={"payload": {"sinVersion": True}},
        headers=_bearer(auth_token),
    )
    assert r.status_code == 200


# -- Payload arbitrario -----------------------------------------------------

def test_payload_vacio_es_valido(client, auth_token):
    r = client.post("/user/state", json={"payload": {}}, headers=_bearer(auth_token))
    assert r.status_code == 200


def test_payload_anidado_se_preserva(client, auth_token):
    payload = {"a": {"b": {"c": [1, 2, 3]}}, "unicode": "日本語"}
    client.post("/user/state", json={"payload": payload}, headers=_bearer(auth_token))

    r = client.get("/user/state", headers=_bearer(auth_token))
    assert r.json()["payload"] == payload
