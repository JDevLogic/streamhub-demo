# StreamHub Demo

![CI](https://github.com/JDevLogic/streamhub-demo/actions/workflows/ci.yml/badge.svg)
![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?style=flat&logo=fastapi&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-7-DC382D?style=flat&logo=redis&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat&logo=docker&logoColor=white)
![License](https://img.shields.io/badge/Licencia-MIT-green?style=flat)

## Vista previa

![Vista general](docs/screenshots/dashboard-overview.png)
![Actividad](docs/screenshots/dashboard-activity.png)
![Métricas](docs/screenshots/dashboard-metrics.png)

---

> Plataforma de streaming full-stack construida como portfolio técnico. Combina una API REST con FastAPI, caché en dos capas con Redis, autenticación completa, dashboard de telemetría propio y un cliente móvil nativo en Flutter.

---

## ¿Qué demuestra este proyecto?

StreamHub es la versión pública de un sistema de streaming personal diseñado para practicar e integrar múltiples áreas del desarrollo de software en un mismo proyecto cohesionado:

| Área | Patrones y tecnologías |
|---|---|
| API REST | FastAPI, Uvicorn, routing modular, validación de parámetros |
| Caché | Redis con TTL dinámico + Stale-While-Revalidate (SWR) |
| Seguridad | API Key, Bearer tokens, rate limiting sliding-window |
| Infraestructura | Docker Compose, Nginx reverse proxy, systemd, HTTPS/Certbot |
| App móvil | Flutter, Riverpod, reproductor nativo, persistencia offline |
| Observabilidad | Dashboard propio con métricas, actividad y health checks |
| Diseño | Patrón Provider para desacoplar rutas de la fuente de datos |

---

## Stack

| Capa | Tecnología |
|---|---|
| API | FastAPI + Uvicorn |
| Caché distribuida | Redis 7 |
| Caché en memoria | TTLCache (por worker) |
| Persistencia | SQLite — backend y app móvil |
| Autenticación | API Key + sesiones Bearer |
| Rate limiting | SQLite sliding-window |
| Tareas programadas | APScheduler |
| Monitoreo | Dashboard HTML/JS propio con Basic Auth |
| Despliegue | Docker Compose + Nginx + Certbot |
| App móvil | Flutter — Riverpod, media_kit, Drift/SQLite |

---

## Arquitectura

```
Cliente Flutter
      │  X-API-Key / Bearer
      ▼
   Nginx (reverse proxy + TLS)
      │
      ▼
   FastAPI
      ├── Middleware: rate limiter (SQLite sliding-window) + timing
      ├── Middleware: telemetría → Dashboard
      ├── Auth: API Key dependency / Bearer token
      └── Provider layer
            ├── Redis cache (SWR + TTL dinámico)
            └── Fuente de datos (mock / real)
```

**Patrones de caché destacados:**

- **Stale-While-Revalidate (SWR)** — los datos se sirven inmediatamente desde caché y se revalidan en background cuando superan el 75% de su TTL.
- **TTL dinámico** — el TTL se reduce automáticamente para entradas que cambian con frecuencia, aumentando la frescura sin coste adicional.
- **Caché en dos capas** — Redis comparte datos entre workers; TTLCache en memoria evita round-trips a Redis para los accesos más frecuentes.
- **Offline-first en Flutter** — las listas principales se persisten localmente con Drift; la app es funcional sin conexión y sincroniza al recuperarla.

---

## Estructura del proyecto

```
streamhub-demo/
├── backend/
│   ├── providers/        # Abstracción de fuente de datos (mock / real)
│   ├── routes/           # Endpoints REST organizados por dominio
│   ├── db/               # Redis, SQLite, métricas y caché service
│   ├── dashboard/        # Panel de telemetría (HTML + JS + Basic Auth)
│   ├── utils/            # Buffer de logs y registro de actividad
│   └── tests/            # Tests de integración (26 tests, pytest)
├── frontend_flutter/     # Cliente Android (Flutter)
├── nginx/                # Configuración reverse proxy + HTTPS
├── deploy/               # Script de setup para VPS + systemd service
└── docker-compose.yml
```

---

## Inicio rápido

### Con Docker Compose

```bash
cp backend/.env.example backend/.env
# Edita backend/.env con tus valores

docker compose up -d

# Verificar que arranca
curl http://localhost:5050/health
```

### Backend en local

```bash
cd backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# Edita .env con tus valores

python app.py
```

Backend disponible en `http://localhost:5050`. El dashboard de monitoreo en `http://localhost:5050/dashboard`.

### App Flutter

```bash
cd frontend_flutter
flutter pub get

# Emulador Android
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5050 \
  --dart-define=API_KEY=tu_api_key

# Dispositivo físico en la misma red
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.X:5050 \
  --dart-define=API_KEY=tu_api_key
```

---

## Variables de entorno

```bash
cp backend/.env.example backend/.env
```

```env
API_KEY=reemplaza_con_valor_aleatorio_largo
DASHBOARD_USER=reemplaza_con_usuario
DASHBOARD_PASS=reemplaza_con_contraseña_larga
ALLOWED_ORIGINS=http://localhost:3000
DATA_PROVIDER=mock
```

---

## Endpoints principales

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| `GET` | `/health` | — | Estado del servicio y Redis |
| `GET` | `/metrics` | — | Métricas de latencia por ruta |
| `GET` | `/dashboard` | Basic Auth | Panel de monitoreo |
| `GET` | `/animes` | API Key | Catálogo de contenido |
| `GET` | `/ultimos-episodios` | API Key | Episodios recientes |
| `GET` | `/en-emision` | API Key | Contenido en emisión |
| `GET` | `/buscar?q=` | API Key | Búsqueda en el catálogo |
| `GET` | `/anime-detalle?url=` | API Key | Detalle de título |
| `GET` | `/episodios?url=` | API Key | Lista de episodios |
| `GET` | `/servidores?url=` | API Key | Fuentes de vídeo disponibles |
| `GET` | `/resolver?url=` | API Key | Resolución a URL de reproducción |
| `POST` | `/auth/register` | API Key | Registro de usuario |
| `POST` | `/auth/login` | API Key | Inicio de sesión |
| `GET` | `/auth/me` | Bearer | Perfil del usuario autenticado |
| `GET` | `/user/state` | Bearer | Descargar estado del usuario |
| `POST` | `/user/state` | Bearer | Sincronizar estado del usuario |

---

## Modo demo

La versión pública funciona con `DATA_PROVIDER=mock`. Todos los datos son ficticios (títulos inventados, imágenes de dominio público). El endpoint `/resolver` apunta a un vídeo de Google con licencia Creative Commons, usado únicamente para validar el flujo completo:

- Reproducción nativa en el player
- Progreso y "continuar viendo"
- Sincronización de estado entre sesiones
- Registro de telemetría y dashboard de monitoreo

---

## Despliegue en VPS

El directorio `deploy/` incluye un script de setup para Ubuntu/Debian y un service de systemd. El directorio `nginx/` contiene la configuración de reverse proxy con soporte para HTTPS vía Certbot.

```bash
# En el servidor (como root)
bash deploy/setup.sh
```

---

## Contribuir

Consulta [CONTRIBUTING.md](./CONTRIBUTING.md) para instrucciones de setup, cómo ejecutar los tests y las convenciones del proyecto.

---

## Aviso legal

Este repositorio se publica únicamente como demo técnica y educativa. No aloja, almacena, distribuye, vende ni monetiza contenido audiovisual. No está pensado como plataforma pública de streaming ni como producto comercial.

Consulta [DISCLAIMER.md](./DISCLAIMER.md) para más detalle.
