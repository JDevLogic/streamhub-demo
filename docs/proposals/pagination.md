# Propuesta: Paginación en endpoints de listado

## Problema

Los endpoints `/animes`, `/ultimos-episodios` y `/en-emision` devuelven todos los resultados de una vez. En producción con datos reales esto se convierte en un problema de rendimiento y memoria.

## Solución

Añadir paginación por offset a los endpoints de listado. Es el patrón más sencillo y suficiente para este caso.

### Query params

```
GET /animes?page=1&limit=20
GET /ultimos-episodios?page=1&limit=20
GET /en-emision?page=1&limit=20
GET /buscar?q=naruto&page=1&limit=20
```

Valores por defecto: `page=1`, `limit=20`. Límite máximo: `limit=100`.

### Formato de respuesta

Envolver los datos en un envelope estándar:

```json
{
  "data": [...],
  "page": 1,
  "limit": 20,
  "total": 87,
  "pages": 5
}
```

## Cambios necesarios

### Provider (mock y real)

Añadir soporte de `offset` / `limit` en los métodos que devuelven listas:

```python
def get_animes(self, page: int = 1, limit: int = 20) -> dict:
    offset = (page - 1) * limit
    items = self._all_animes[offset : offset + limit]
    return {"data": items, "total": len(self._all_animes), ...}
```

### Routes

Añadir parámetros query con validación FastAPI:

```python
@router.get("/animes")
def get_animes(page: int = Query(1, ge=1), limit: int = Query(20, ge=1, le=100)):
    ...
```

### Flutter

Adaptar el cliente para consumir el nuevo formato y añadir scroll infinito o botones de página.

## Archivos a tocar

- `backend/providers/mock_provider.py`
- `backend/providers/base_provider.py` (si existe interfaz)
- `backend/routes/catalog.py`
- `backend/tests/test_catalog.py` — verificar que el envelope es correcto y que los límites se aplican
- `frontend_flutter/` — adaptar modelos y llamadas a la API

## Complejidad estimada

Baja-media. El mock solo necesita slicing de lista. Lo más laborioso es actualizar el cliente Flutter para manejar el nuevo envelope y el estado de paginación.
