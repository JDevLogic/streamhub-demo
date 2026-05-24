"""Tests de los endpoints del catálogo (requieren X-API-Key)."""

import pytest

API_KEY = "test-api-key"
HEADERS = {"X-API-Key": API_KEY}


# -- Autenticación ----------------------------------------------------------

def test_catalog_sin_key_devuelve_422(client):
    r = client.get("/catalog")
    assert r.status_code == 422


def test_catalog_key_incorrecta_devuelve_401(client):
    r = client.get("/catalog", headers={"X-API-Key": "clave-incorrecta"})
    assert r.status_code == 401


# -- Catálogo ---------------------------------------------------------------

def test_catalog_devuelve_lista(client):
    r = client.get("/catalog", headers=HEADERS)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) > 0
    assert "titulo" in data[0]
    assert "url" in data[0]


def test_ultimos_episodios(client):
    r = client.get("/latest-episodes", headers=HEADERS)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) > 0


def test_en_emision(client):
    r = client.get("/on-air", headers=HEADERS)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert all(a["estado"] == "En emisión" for a in data)


# -- Búsqueda ---------------------------------------------------------------

def test_buscar_sin_query_devuelve_400(client):
    r = client.get("/search", headers=HEADERS)
    assert r.status_code == 400


def test_buscar_con_resultado(client):
    r = client.get("/search?q=demo", headers=HEADERS)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) > 0


def test_buscar_sin_resultado(client):
    r = client.get("/search?q=xyznotexists", headers=HEADERS)
    assert r.status_code == 200
    assert r.json() == []


# -- Detalle y episodios ----------------------------------------------------

def test_detail(client):
    r = client.get(
        "/detail?url=demo://anime/demo-adventure", headers=HEADERS
    )
    assert r.status_code == 200
    data = r.json()
    assert data["titulo"] == "Demo Adventure"
    assert "sinopsis" in data
    assert "generos" in data


def test_detail_sin_url_devuelve_400(client):
    r = client.get("/detail", headers=HEADERS)
    assert r.status_code == 400


def test_episodios_devuelve_lista(client):
    r = client.get(
        "/episodes?url=demo://anime/demo-adventure", headers=HEADERS
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) > 0
    assert "episodio" in data[0]


def test_episodios_sin_url_devuelve_400(client):
    r = client.get("/episodes", headers=HEADERS)
    assert r.status_code == 400


# -- Servidores y resolver --------------------------------------------------

def test_servidores(client):
    r = client.get("/sources?url=demo://episode/test", headers=HEADERS)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) > 0


def test_resolver_devuelve_url_reproduccion(client):
    r = client.get("/resolver?url=demo://video/test", headers=HEADERS)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) > 0
    assert "url" in data[0]
    assert data[0]["url"].startswith("http")
