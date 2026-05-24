# Propuesta: WebSockets para actividad en tiempo real

## Problema

El dashboard actual obtiene los datos de actividad mediante polling (peticiones periódicas al servidor). Esto introduce latencia artificial y genera tráfico innecesario. La app Flutter tampoco puede recibir actualizaciones push sin polling.

## Solución

Añadir un endpoint WebSocket que emita eventos de actividad en tiempo real. El dashboard y la app Flutter se suscriben y reciben cada entrada nueva instantáneamente.

## Diseño

### Endpoint

```
GET /ws/activity
```

Requiere API Key como query param para no complicar el handshake WebSocket con headers custom:

```
ws://localhost:5050/ws/activity?api_key=...
```

### Formato del mensaje

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "method": "GET",
  "path": "/animes",
  "status": 200,
  "duration_ms": 45.2,
  "ip": "192.168.1.1"
}
```

### Arquitectura interna

1. Un `ConnectionManager` global mantiene la lista de clientes WebSocket conectados.
2. El middleware de telemetría, al registrar cada petición, llama a `manager.broadcast(entry)`.
3. Cada cliente conectado recibe el evento inmediatamente.

```python
class ConnectionManager:
    def __init__(self):
        self.active: list[WebSocket] = []

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self.active.append(ws)

    def disconnect(self, ws: WebSocket):
        self.active.remove(ws)

    async def broadcast(self, data: dict):
        for ws in self.active:
            await ws.send_json(data)
```

### Dashboard JS

Reemplazar el polling de actividad por una conexión WebSocket:

```js
const ws = new WebSocket(`ws://${location.host}/ws/activity?api_key=...`);
ws.onmessage = (e) => appendActivityRow(JSON.parse(e.data));
```

## Archivos a tocar

- `backend/routes/ws.py` — nuevo archivo con el endpoint y ConnectionManager
- `backend/app.py` — registrar el nuevo router
- `backend/utils/activity.py` — notificar al manager al registrar actividad
- `backend/dashboard/assets/dashboard.js` — sustituir polling por WebSocket
- `frontend_flutter/` — opcional, añadir feed de actividad en tiempo real

## Complejidad estimada

Media. FastAPI tiene soporte nativo para WebSockets. Lo más delicado es integrar el broadcast en el middleware de telemetría sin bloquear el event loop (usar `asyncio.create_task`).
