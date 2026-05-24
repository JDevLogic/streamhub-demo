# Contribuir a StreamHub Demo

Gracias por tu interés. Este es un proyecto educativo — cualquier mejora, corrección o sugerencia es bienvenida.

---

## Requisitos previos

- Python 3.10 o superior
- Flutter 3.x (solo si trabajas en el cliente móvil)
- Docker y Docker Compose (opcional, para levantar Redis o el stack completo)

---

## Poner en marcha el backend

```bash
cd backend
python -m venv venv

# Linux / macOS
source venv/bin/activate
# Windows
venv\Scripts\activate

pip install -r requirements.txt
cp .env.example .env
```

Edita `.env` y asigna valores a las variables:

```env
API_KEY=cualquier_cadena_larga_aleatoria
DASHBOARD_USER=admin
DASHBOARD_PASS=cualquier_contraseña_larga
ALLOWED_ORIGINS=http://localhost:3000
DATA_PROVIDER=mock
```

Arranca el servidor:

```bash
python app.py
# o con recarga automática:
uvicorn app:app --reload --port 5050
```

El backend queda disponible en `http://localhost:5050`.
El dashboard de monitoreo en `http://localhost:5050/dashboard`.

---

## Ejecutar los tests

```bash
cd backend
pip install -r requirements-dev.txt
pytest tests/ -v
```

Los tests no necesitan Redis ni ninguna variable de entorno configurada — el entorno de prueba se inicializa automáticamente en `tests/conftest.py`.

---

## Poner en marcha la app Flutter

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

## Stack completo con Docker

```bash
cp backend/.env.example backend/.env
# Edita backend/.env

docker compose up -d
```

---

## Estructura del proyecto

Consulta el [README](./README.md) para la descripción completa de la arquitectura y los patrones implementados.

```
streamhub-demo/
├── backend/
│   ├── providers/   — abstracción de fuente de datos
│   ├── routes/      — endpoints REST por dominio
│   ├── db/          — Redis, SQLite, métricas y caché
│   ├── dashboard/   — panel de telemetría
│   ├── utils/       — utilidades transversales
│   └── tests/       — tests de integración
├── frontend_flutter/  — cliente Android (Flutter + Riverpod)
├── nginx/             — configuración reverse proxy
└── deploy/            — script de setup para VPS + systemd
```

---

## Convenciones

- El backend usa **Python 3.10+** con type hints donde aportan claridad.
- Los commits siguen el estilo del repositorio: mensaje en español, imperativo, sin puntuación final.
- No se aceptan cambios que introduzcan scraping real ni dependencias de fuentes externas de contenido.
