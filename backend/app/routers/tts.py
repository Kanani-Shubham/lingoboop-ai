from fastapi import APIRouter, Depends
from app.core.rate_limiter import rate_limiter
from app.core.security import verify_client_token
from app.providers.gnani_tts import GnaniTTSProvider
from app.schemas.common import APIResponse
from app.schemas.tts import TTSRequest

router = APIRouter(prefix="/api/v1/tts", tags=["Text-to-Speech"])

tts_provider = GnaniTTSProvider()


@router.post("/synthesize", response_model=APIResponse)
async def synthesize_speech(
    request: TTSRequest,
    client_id: str = Depends(verify_client_token)
):
    """
    Synthesizes speech audio via Gnani Timbre TTS.
    Returns base64-encoded audio and speech metadata.
    """
    rate_limiter.check_rate_limit(client_id)

    result = await tts_provider.synthesize(request)

    return APIResponse(
        success=True,
        data=result.model_dump()
    )

