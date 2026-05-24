# Arquitectura de StreamHub

Documento de referencia para entender las capas del sistema, el flujo de una petición y las decisiones de diseño que no caben en el README.

---

## Visión general

```
Cliente Flutter
    │  X-API-Key / Bearer
    ▼
Nginx  (TLS termination, X-Real-IP forwarding)
    │
    ▼
FastAPI / Uvicorn
    ├── Middleware: timing + registro de actividad
    ├── Rate limiter  (sliding-window, SQLite)
    ├── Auth          (API Key o Bearer token)
    └── Provider layer
            ├── TTLCache  (en memoria, por worker)
            ├── Redis     (compartido entre workers)
            └── MockProvider / RealProvider
```

---

## Ciclo de vida de una petición

1. **Nginx** acepta la conexión, termina TLS y añade `X-Real-IP` con la IP original del cliente antes de pasar la petición a FastAPI por HTTP.

2. **Middleware de telemetría** registra timestamp de inicio y encola el registro de actividad (método, ruta, IP, duración, status) al finalizar la respuesta.

3. **Rate limiter** consulta SQLite con una ventana deslizante: cuenta las peticiones de la IP en los últimos N segundos y rechaza con 429 si supera el límite. Usa WAL mode para no bloquear lecturas concurrentes.

4. **Auth** comprueba el método requerido por la ruta:
   - `X-API-Key` — clave estática en `.env`, comparada con `hmac.compare_digest`.
   - `Bearer token` — JWT firmado con clave secreta; payload contiene `user_id` y `exp`.

5. **Provider layer** resuelve el dato:
   - Consulta primero `TTLCache` (en memoria, instancia por worker).
   - Si miss, consulta Redis con lógica SWR: si el dato está entre el 75 % y el 100 % de su TTL se sirve inmediatamente y se lanza un `asyncio.create_task` para revalidar en background.
   - Si miss total, llama al proveedor de datos y guarda en Redis con TTL dinámico.

6. **Respuesta** sale por Nginx hacia el cliente.

---

## Estrategia de caché

### Dos capas

| Capa | Alcance | TTL | Persistencia |
|---|---|---|---|
| TTLCache | Por worker (en memoria) | Igual que Redis | No — se pierde al reiniciar |
| Redis | Compartido entre workers | Dinámico (ver abajo) | Sí — volumen Docker |

La TTLCache reduce la carga sobre Redis para los endpoints más calientes. En un despliegue con varios workers Uvicorn cada proceso tiene su propia copia; el hit rate real de TTLCache es proporcional a la carga por worker.

### TTL dinámico

Cada entrada en Redis lleva un contador `change_count` que se incrementa cuando el dato cambia entre escrituras consecutivas. El TTL efectivo se calcula como:

```
ttl = max(base × 0.25,  base − change_count × base × 0.10)
```

Un título con 5 cambios registrados tiene TTL = 50 % del base. Uno sin cambios conserva el TTL máximo. No requiere configuración manual.

### Stale-While-Revalidate

Si `elapsed > ttl_effective × 0.75` el dato se considera *stale*: se sirve inmediatamente al cliente y se lanza una tarea en background (`asyncio.create_task`) que refresca Redis antes de que el TTL expire. El cliente nunca espera el re-fetch.

---

## Modelo de autenticación

### API Key

Pensada para el cliente Flutter y cualquier consumidor machine-to-machine. La clave se envía en el header `X-API-Key`. Se compara con `hmac.compare_digest` para evitar timing attacks.

### Bearer token (sesiones de usuario)

Flujo completo:

```
POST /auth/register  →  crea usuario en SQLite
POST /auth/login     →  devuelve { token, expires_at }
GET  /auth/me        →  valida token de sesión en SQLite, devuelve perfil
GET  /user/state     →  descarga estado (Mi Lista, progreso)
POST /user/state     →  sube estado desde el cliente
```

Los tokens son strings aleatorios (`secrets.token_urlsafe(48)`) almacenados en la tabla `user_sessions` junto con su fecha de expiración. La validación comprueba existencia y `expires_at`. Logout elimina la fila; tokens expirados permanecen hasta limpieza periódica.

---

## Roles de SQLite

Una sola base de datos (`streamhub_cache.db`) con cuatro responsabilidades:

| Tabla | Uso |
|---|---|
| `rate_limit_log` | Registro de peticiones para sliding-window |
| `users` + `user_sessions` | Autenticación y gestión de tokens Bearer |
| `user_state` | Estado sincronizado del usuario (Mi Lista, progreso) |
| `telemetry` | Actividad y métricas durables (complementa el buffer en memoria) |
| `intro_skips` | Timestamps de intro por episodio (feature del dashboard) |

SQLite opera en modo WAL (`PRAGMA journal_mode=WAL`) para permitir lecturas concurrentes sin bloquear escrituras — necesario cuando Uvicorn corre con varios workers.

---

## Sincronización de estado Flutter ↔ backend

El cliente envía y recibe un objeto JSON plano con el historial completo del usuario:

```json
{
  "myList": [
    { "animeUrl": "...", "titulo": "...", "estado": "watching", ... }
  ],
  "progress": [
    { "episodeUrl": "...", "position": 142.5, ... }
  ]
}
```

La clave `animeUrl` es un artefacto del historial del proyecto y se mantiene por compatibilidad con clientes ya instalados. El backend y Flutter la tratan como identificador opaco de contenido.

La resolución de conflictos es *last-write-wins* por campo: el servidor compara `updatedAt` de cada entrada y conserva la más reciente.

---

## Proveedor de datos

Las rutas nunca llaman directamente a una fuente de datos — pasan siempre por el `Provider`:

```python
provider = get_provider()   # resuelto por DATA_PROVIDER en .env

provider.get_catalog()
provider.get_detail(url)
provider.get_episodes(url)
provider.get_sources(url)
```

`MockProvider` devuelve datos estáticos ficticios. Un `RealProvider` implementaría la misma interfaz apuntando a la fuente real. Cambiar de modo no toca ninguna ruta ni ninguna lógica de caché.

---

## Flutter: datos offline

Las listas principales (`/catalog`, `/latest-episodes`, `/on-air`) se persisten localmente con Drift (SQLite). Al abrir la app:

1. Se lanza el fetch de red en background.
2. Si hay caché local se muestra inmediatamente (sin spinner).
3. Cuando llega la respuesta de red se actualiza la vista y se sobreescribe la caché.
4. Si la red falla y hay caché, la app sigue siendo funcional.

Los detalles de título y listas de episodios no se cachean offline (demasiados URLs únicos, prioridad baja).
