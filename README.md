# AniStream Demo

> Proyecto educativo full-stack orientado a portfolio, centrado en arquitectura backend, desarrollo móvil, caché, autenticación, telemetría y despliegue con Docker.

AniStream Demo es la versión pública y segura de un proyecto personal de aprendizaje full-stack.

Esta versión utiliza datos de demostración y un vídeo público de prueba para enseñar la arquitectura del sistema sin enlazar, alojar, distribuir ni monetizar contenido protegido por derechos de autor.

El objetivo principal de este repositorio es demostrar conocimientos técnicos reales: diseño de APIs REST con FastAPI, caché con Redis y SQLite, autenticación, sincronización de usuario, telemetría, rate limiting, Docker, Nginx y desarrollo móvil con Flutter.

---

## Modo demo

La versión pública funciona con:

DATA_PROVIDER=mock

Todos los datos devueltos por la API son datos de demostración.

El endpoint de resolución devuelve un vídeo público de prueba usado únicamente para validar:

- reproducción nativa;
- progreso de reproducción;
- continuar viendo;
- sincronización de usuario;
- telemetría;
- dashboard de monitoreo;
- integración entre app móvil y backend.

---

## Características principales

- Backend con FastAPI.
- Cliente móvil Android desarrollado con Flutter.
- Arquitectura basada en proveedores de datos.
- Proveedor mock para demo pública.
- Caché con Redis.
- Persistencia con SQLite.
- Autenticación y sesiones de usuario.
- Sincronización de estado del usuario.
- Historial de visualización.
- Sección de continuar viendo.
- Reproductor nativo con vídeo demo.
- Dashboard protegido con Basic Auth.
- Telemetría y monitoreo de fuentes demo.
- Rate limiting.
- Configuración mediante variables de entorno.
- Despliegue con Docker Compose.
- Configuración de Nginx como reverse proxy.

---

## Arquitectura

Estructura general del proyecto:

anistream-demo/
├── backend/              API FastAPI, auth, caché, dashboard y telemetría
│   ├── providers/        Proveedores de datos
│   ├── mock/             Datos de demostración
│   ├── routes/           Rutas de la API
│   ├── db/               SQLite, Redis, métricas y telemetría
│   └── dashboard/        Panel de monitoreo
├── frontend_flutter/     Cliente móvil Flutter
├── nginx/                Configuración de reverse proxy
├── deploy/               Archivos de despliegue
└── docker-compose.yml    Backend, Redis y Nginx

---

## Stack backend

| Capa | Tecnología |
|---|---|
| API | FastAPI + Uvicorn |
| Caché | Redis + caché en memoria |
| Persistencia | SQLite |
| Autenticación | API Key + sesiones |
| Tareas programadas | APScheduler |
| Monitoreo | Dashboard propio + telemetría |
| Despliegue | Docker Compose + Nginx |

---

## Stack frontend

| Capa | Tecnología |
|---|---|
| Framework | Flutter |
| Estado | Riverpod |
| Persistencia local | SQLite / Drift |
| Reproductor | media_kit |
| Preferencias | SharedPreferences |

---

## Endpoints principales

| Método | Ruta | Descripción |
|---|---|---|
| GET | /health | Estado del backend |
| GET | /metrics | Métricas del sistema |
| GET | /dashboard | Dashboard protegido |
| GET | /animes | Catálogo demo |
| GET | /ultimos-episodios | Episodios demo recientes |
| GET | /en-emision | Lista demo en emisión |
| GET | /buscar?q= | Búsqueda demo |
| GET | /anime-detalle?url= | Detalle demo |
| GET | /episodios?url= | Lista demo de episodios |
| GET | /servidores?url= | Lista demo de servidores |
| GET | /resolver?url= | Resolución de vídeo demo |
| POST | /auth/register | Registro de usuario |
| POST | /auth/login | Inicio de sesión |
| GET | /auth/me | Usuario actual |
| GET | /user/state | Descargar estado sincronizado |
| POST | /user/state | Subir estado sincronizado |

---

## Variables de entorno

Copia el archivo de ejemplo:

cp backend/.env.example backend/.env

Variables esperadas:

API_KEY=replace_with_long_random_value
DASHBOARD_USER=replace_with_non_default_user
DASHBOARD_PASS=replace_with_long_random_password
ALLOWED_ORIGINS=http://localhost:3000
DATA_PROVIDER=mock

---

## Ejecutar con Docker Compose

Desde la raíz del proyecto:

docker compose up -d

Comprobar el backend:

curl http://localhost:5050/health

Ver logs:

docker compose logs -f backend
docker compose logs -f nginx

---

## Ejecutar backend en local

cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py

Backend disponible en:

http://localhost:5050

---

## Ejecutar app Flutter

cd frontend_flutter
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5050 --dart-define=API_KEY=your_api_key

En un dispositivo físico dentro de la misma red local, usa la IP LAN del ordenador:

flutter run --dart-define=API_BASE_URL=http://192.168.1.X:5050 --dart-define=API_KEY=your_api_key

---

## Finalidad de portfolio

Este repositorio demuestra:

- diseño de APIs backend;
- arquitectura basada en proveedores;
- separación entre datos y lógica de negocio;
- autenticación;
- caché;
- persistencia con SQLite;
- integración con Redis;
- telemetría;
- dashboard de monitoreo;
- integración backend-móvil;
- despliegue con Docker;
- desarrollo móvil con Flutter;
- organización de un proyecto full-stack real.

---

## Aviso

Este repositorio se publica únicamente como demo técnica y educativa.

No aloja, almacena, distribuye, vende ni monetiza contenido audiovisual.  
No está pensado como plataforma pública de streaming ni como producto comercial.

Consulta también DISCLAIMER.md.
