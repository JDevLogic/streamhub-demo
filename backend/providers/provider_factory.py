import os

from providers.mock_provider import provider as mock_provider


def get_provider():
    """Devuelve el proveedor de datos activo para la demo pública."""
    data_provider = os.getenv("DATA_PROVIDER", "mock").lower().strip()

    if data_provider != "mock":
        raise RuntimeError(
            "Esta versión pública solo soporta DATA_PROVIDER=mock."
        )

    return mock_provider

