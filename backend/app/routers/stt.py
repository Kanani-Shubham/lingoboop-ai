from fastapi import APIRouter, Depends, File, Form, UploadFile
from app.core.rate_limiter import rate_limiter
from app.core.security import verify_client_token
from app.providers.gnani_stt import GnaniSTTProvider
from app.schemas.common import APIResponse

router = APIRouter(prefix="/api/v1/stt", tags=["Speech-to-Text"])

stt_provider = GnaniSTTProvider()


@router.post("/transcribe", response_model=APIResponse)
async def transcribe_audio(
    audio_file: UploadFile = File(..., description="Audio file binary (.wav, .mp3, .pcm)"),
    language_code: str = Form(default="gu-IN", description="BCP-47 language code: gu-IN, hi-IN, en-IN"),
    model: str = Form(default="prisma-v3.0", description="STT model identifier"),
    client_id: str = Depends(verify_client_token)
):
    """
    Transcribes audio buffer via Gnani Prisma v3.0 STT.
    Includes client rate limiting and usage accounting.
    """
    rate_limiter.check_rate_limit(client_id)

    audio_bytes = await audio_file.read()
    result = await stt_provider.transcribe(
        audio_bytes=audio_bytes,
        filename=audio_file.filename or "audio.wav",
        language_code=language_code,
        model=model
    )

    # Estimate audio duration (16-bit 16kHz mono = 32000 bytes/sec)
    duration_sec = len(audio_bytes) / 32000.0 if len(audio_bytes) > 0 else 0.0
    rate_limiter.record_audio_usage(client_id, duration_sec)

    return APIResponse(
        success=True,
        data=result.model_dump()
    )
