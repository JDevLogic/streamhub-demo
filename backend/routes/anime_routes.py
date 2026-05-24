from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse

from providers.provider_factory import get_provider
from security import require_api_key


router = APIRouter(dependencies=[Depends(require_api_key)])
provider = get_provider()


@router.get("/animes")
async def get_animes():
    data = provider.get_animes()
    return JSONResponse(data)


@router.get("/ultimos-episodios")
async def get_ultimos_episodios():
    data = provider.get_ultimos_episodios()
    return JSONResponse(data)


@router.get("/en-emision")
async def get_en_emision():
    data = provider.get_en_emision()
    return JSONResponse(data)


@router.get("/buscar")
async def search_animes(q: str = ""):
    if not q.strip():
        raise HTTPException(status_code=400, detail="Falta parámetro q")

    data = provider.buscar(q.strip())
    return JSONResponse(data)


@router.get("/animes-por-genero")
async def get_animes_por_genero(genero: str = ""):
    if not genero.strip():
        raise HTTPException(status_code=400, detail="Falta parámetro genero")

    data = provider.get_animes_por_genero(genero.strip())
    return JSONResponse(data)


@router.post("/prefetch", status_code=202)
async def prefetch_animes():
    """Endpoint conservado para compatibilidad en modo demo.

    En la versión pública no realiza scraping ni llamadas externas.
    """
    return {"queued": 0, "mode": "demo"}

