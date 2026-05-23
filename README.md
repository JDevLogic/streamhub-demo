# AniStream Demo

![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?style=flat&logo=fastapi&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-7-DC382D?style=flat&logo=redis&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat&logo=docker&logoColor=white)
![License](https://img.shields.io/badge/Licencia-MIT-green?style=flat)

> Demo educativa full-stack orientada a portfolio: arquitectura backend, desarrollo móvil, caché, autenticación, telemetría y despliegue con Docker.

AniStream Demo es la versión pública de un proyecto personal de aprendizaje full-stack. Utiliza datos de demostración y un vídeo público de prueba para mostrar la arquitectura del sistema sin enlazar, alojar, distribuir ni monetizar contenido protegido por derechos de autor.

El objetivo es demostrar cómo se diseña e integra un sistema completo: API REST con FastAPI, caché en dos capas (Redis + memoria), autenticación con sesiones, sincronización de estado de usuario, telemetría, rate limiting, despliegue con Docker y un cliente móvil con Flutter.

---

## Highlights técnicos

- **Arquitectura basada en proveedores** — capa de abstracción entre rutas y fuente de datos; el proveedor mock permite ejecutar el sistema completo sin dependencias externas.
- **Caché en dos capas** — Redis para datos compartidos entre workers + `TTLCache` en memoria para reducir round-trips.
- **Rate limiting con SQLite** — sliding-window implementado sobre SQLite, sin dependencias de Redis para esta función crítica.
- **Sincronización de usuario** — el estado de la app (lista, progreso, historial) se serializa y sincroniza entre dispositivos a través de la API.
- **Dashboard de telemetría propio** — panel protegido con Basic Auth que registra actividad, métricas de latencia, health de fuentes y logs en tiempo real.
- **Reproductor nativo en Flutter** — integración con `media_kit`, progreso persistido localmente con SQLite/Drift y continuación automática.
- **Autenticación completa** — registro, login, sesiones con tokens, expiración y logout desde el cliente.
- **Despliegue listo** — Docker Compose con backend, Redis y Nginx; configuración de Certbot para HTTPS incluida.

---

## Stack

| Capa | Tecnología |
|---|---|
| API | FastAPI + Uvicorn |
| Caché | Redis + TTLCache en memoria |
| Persistencia | SQLite |
| Autenticación | API Key + sesiones Bearer |
| Rate limiting | SQLite sliding-window |
| Tareas programadas | APScheduler |
| Monitoreo | Dashboard propio + telemetría |
| Despliegue | Docker Compose + Nginx + Certbot |
| App móvil | Flutter (Riverpod, media_kit, Drift) |

---

## Estructura del proyecto

```
anistream-demo/
├── backend/
│   ├── providers/        # Capa de abstracción de datos
│   ├── routes/           # Endpoints de la API
│   ├── db/               # SQLite, Redis, métricas y telemetría
│   ├── dashboard/        # Panel de monitoreo
│   └── utils/            # Logs, actividad y helpers
├── frontend_flutter/     # Cliente móvil Android
├── nginx/                # Configuración reverse proxy + HTTPS
├── deploy/               # Systemd service y scripts de despliegue
└── docker-compose.yml
```

---

## Endpoints principales

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| `GET` | `/health` | — | Estado del backend |
| `GET` | `/metrics` | — | Métricas de latencia |
| `GET` | `/dashboard` | Basic Auth | Panel de monitoreo |
| `GET` | `/animes` | API Key | Catálogo demo |
| `GET` | `/ultimos-episodios` | API Key | Episodios recientes |
| `GET` | `/en-emision` | API Key | En emisión |
| `GET` | `/buscar?q=` | API Key | Búsqueda |
| `GET` | `/anime-detalle?url=` | API Key | Detalle de anime |
| `GET` | `/episodios?url=` | API Key | Lista de episodios |
| `GET` | `/servidores?url=` | API Key | Servidores de vídeo |
| `GET` | `/resolver?url=` | API Key | URL de reproducción |
| `POST` | `/auth/register` | API Key | Registro de usuario |
| `POST` | `/auth/login` | API Key | Inicio de sesión |
| `GET` | `/auth/me` | Bearer | Usuario actual |
| `GET` | `/user/state` | Bearer | Descargar estado |
| `POST` | `/user/state` | Bearer | Subir estado |

---

## Modo demo

La versión pública funciona con `DATA_PROVIDER=mock`. Todos los datos devueltos por la API son ficticios. El endpoint `/resolver` apunta a un vídeo público de Google usado únicamente para validar el flujo completo:

- reproducción nativa en el player
- progreso y "continuar viendo"
- sincronización de estado entre dispositivos
- telemetría y dashboard de monitoreo

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
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# Edita .env con tus valores

python app.py
```

Backend disponible en `http://localhost:5050`.

### App Flutter

```bash
cd frontend_flutter
flutter pub get

# Emulador Android
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5050 \
  --dart-define=API_KEY=tu_api_key

# Dispositivo físico (misma red local)
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

## Despliegue en VPS

El directorio `deploy/` incluye un script de setup para Ubuntu/Debian y un service de systemd. El directorio `nginx/` contiene la configuración de reverse proxy con soporte para HTTPS vía Certbot.

```bash
# En el servidor (como root)
bash deploy/setup.sh
```

---

## Aviso legal

Este repositorio se publica únicamente como demo técnica y educativa. No aloja, almacena, distribuye, vende ni monetiza contenido audiovisual. No está pensado como plataforma pública de streaming ni como producto comercial.

Consulta [DISCLAIMER.md](./DISCLAIMER.md) para más detalle.
