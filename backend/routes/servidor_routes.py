from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse

from providers.provider_factory import get_provider
from security import require_api_key


router = APIRouter(dependencies=[Depends(require_api_key)])
provider = get_provider()


@router.get("/servidores")
async def get_servidores(url: str = ""):
    if not url.strip():
        raise HTTPException(status_code=400, detail="Falta parámetro url")

    data = provider.get_servidores(url.strip())
    return JSONResponse(data)


@router.get("/resolver")
async def get_resolver(url: str = ""):
    if not url.strip():
        raise HTTPException(status_code=400, detail="Falta parámetro url")

    data = provider.resolver(url.strip())
    return JSONResponse(data)

