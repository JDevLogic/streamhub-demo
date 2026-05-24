# Propuesta: Refresh Token Rotation

## Problema

El sistema de auth actual emite un access token en el login y no hay forma de renovarlo sin volver a autenticarse. En producción esto obliga al usuario a re-login cuando el token expira.

## Solución

Emitir dos tokens en el login:

- **Access token** — vida corta (15–60 min), usado en cada petición con `Authorization: Bearer`
- **Refresh token** — vida larga (7–30 días), usado una sola vez para obtener un nuevo par de tokens

Cada vez que se usa el refresh token se revoca y se emite uno nuevo (rotation). Si se detecta reutilización de un token ya revocado se invalida toda la sesión.

## Cambios necesarios

### Nueva tabla SQLite

```sql
CREATE TABLE refresh_tokens (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id   INTEGER NOT NULL REFERENCES users(id),
    token     TEXT NOT NULL UNIQUE,   -- hash SHA-256 del token real
    expires_at DATETIME NOT NULL,
    revoked   INTEGER DEFAULT 0
);
```

### Nuevo endpoint

`POST /auth/refresh`

```json
// Request
{ "refresh_token": "..." }

// Response
{
  "access_token": "...",
  "refresh_token": "...",    // nuevo token, el anterior queda revocado
  "token_type": "bearer"
}
```

### Modificar `/auth/login`

Añadir `refresh_token` a la respuesta actual junto al `access_token`.

### Modificar `/auth/logout` (si existe o crear)

`POST /auth/logout` — revoca el refresh token activo de la sesión.

## Archivos a tocar

- `backend/routes/auth.py` — endpoint refresh + modificar login/logout
- `backend/db/sqlite.py` — nueva tabla y queries
- `backend/tests/test_auth.py` — casos: refresh válido, token expirado, reutilización detectada

## Complejidad estimada

Media. El patrón está bien definido; lo más delicado es la detección de reutilización y limpiar tokens expirados (tarea programada con APScheduler ya existe).
