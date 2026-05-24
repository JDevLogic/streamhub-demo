from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse

from providers.provider_factory import get_provider
from security import require_api_key


router = APIRouter(dependencies=[Depends(require_api_key)])
provider = get_provider()


@router.get("/catalog")
async def get_catalog():
    data = provider.get_catalog()
    return JSONResponse(data)


@router.get("/latest-episodes")
async def get_latest_episodes():
    data = provider.get_latest_episodes()
    return JSONResponse(data)


@router.get("/on-air")
async def get_on_air():
    data = provider.get_on_air()
    return JSONResponse(data)


@router.get("/search")
async def search(q: str = ""):
    if not q.strip():
        raise HTTPException(status_code=400, detail="Falta parámetro q")

    data = provider.search(q.strip())
    return JSONResponse(data)


@router.get("/by-genre")
async def get_by_genre(genero: str = ""):
    if not genero.strip():
        raise HTTPException(status_code=400, detail="Falta parámetro genero")

    data = provider.get_by_genre(genero.strip())
    return JSONResponse(data)


@router.post("/prefetch", status_code=202)
async def prefetch():
    """Endpoint conservado para compatibilidad en modo demo.

    En la versión pública no realiza scraping ni llamadas externas.
    """
    return {"queued": 0, "mode": "demo"}
