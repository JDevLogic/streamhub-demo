# Contribuir a StreamHub Demo

Gracias por tu interés. Este es un proyecto educativo — cualquier mejora, corrección o sugerencia es bienvenida.

Para levantar el entorno consulta la sección [Inicio rápido](./README.md#inicio-rápido) del README.

---

## Ejecutar los tests

```bash
cd backend
pip install -r requirements-dev.txt
pytest tests/ -v
```

No necesitan Redis ni variables de entorno configuradas — `tests/conftest.py` inicializa el entorno de prueba automáticamente.

---

## Convenciones

- Commits en español, imperativo, sin puntuación final.
- El backend usa Python 3.10+ con type hints donde aportan claridad.
- No se aceptan cambios que introduzcan scraping real ni dependencias de fuentes externas de contenido.
