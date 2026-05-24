"""Tests del sistema de autenticación (registro, login, sesión)."""

import pytest

API_KEY = "test-api-key"
HEADERS = {"X-API-Key": API_KEY}


def test_registro_exitoso(client):
    r = client.post(
        "/auth/register",
        json={"username": "usuario1", "email": "usuario1@example.com", "password": "pass1234"},
        headers=HEADERS,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


def test_registro_duplicado_devuelve_409(client):
    payload = {"username": "usuario2", "email": "usuario2@example.com", "password": "pass1234"}
    client.post("/auth/register", json=payload, headers=HEADERS)
    r = client.post("/auth/register", json=payload, headers=HEADERS)
    assert r.status_code == 409


def test_registro_password_corta_devuelve_422(client):
    r = client.post(
        "/auth/register",
        json={"username": "usuario3", "email": "usuario3@example.com", "password": "abc"},
        headers=HEADERS,
    )
    assert r.status_code == 422


def test_login_exitoso(client, auth_token):
    assert auth_token is not None
    assert len(auth_token) > 10


def test_login_credenciales_incorrectas(client):
    r = client.post(
        "/auth/login",
        json={"identifier": "testuser", "password": "contraseña-incorrecta"},
        headers=HEADERS,
    )
    assert r.status_code == 401


def test_me_con_token_valido(client, auth_token):
    r = client.get("/auth/me", headers={"Authorization": f"Bearer {auth_token}"})
    assert r.status_code == 200
    data = r.json()
    assert data["username"] == "testuser"
    assert "email" in data


def test_me_sin_token_devuelve_401(client):
    r = client.get("/auth/me")
    assert r.status_code == 401


def test_me_token_invalido_devuelve_401(client):
    r = client.get("/auth/me", headers={"Authorization": "Bearer token-falso"})
    assert r.status_code == 401


def test_logout(client, auth_token):
    r = client.post("/auth/logout", headers={"Authorization": f"Bearer {auth_token}"})
    assert r.status_code == 200
    assert r.json()["ok"] is True
