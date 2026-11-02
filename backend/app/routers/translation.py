from fastapi import APIRouter, Depends
from app.core.rate_limiter import rate_limiter
from app.core.security import verify_client_token
from app.providers.translation_service import translation_service
from app.schemas.common import APIResponse
from app.schemas.translation import TranslationRequest

router = APIRouter(prefix="/api/v1/translation", tags=["Translation"])


@router.post("/translate", response_model=APIResponse)
async def translate_text(
    request: TranslationRequest,
    client_id: str = Depends(verify_client_token)
):
    """
    Translates spoken or typed text between Indian languages and English.
    Integrates upstream NMT with robust phrase and sentence intelligence.
    """
    rate_limiter.check_rate_limit(client_id)

    result = await translation_service.translate(request)

    return APIResponse(
        success=True,
        data=result.model_dump()
    )

