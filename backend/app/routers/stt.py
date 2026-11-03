import json
from typing import Optional
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
    format: Optional[str] = Form(default=None, description="Output format: transcribe, codemix, verbatim"),
    keyterms: Optional[str] = Form(default=None, description="Optional keyterms as JSON array or comma-separated"),
    topic: Optional[str] = Form(default=None, description="Optional topic hint for context"),
    previous_text: Optional[str] = Form(default=None, description="Optional transcript of preceding utterance"),
    client_id: str = Depends(verify_client_token)
):
    """
    Transcribes audio buffer via Gnani Prisma v3.0 STT.
    Includes client rate limiting, keyterm biasing, segmentation for long audio, and usage accounting.
    """
    rate_limiter.check_rate_limit(client_id)

    keyterm_list = None
    if keyterms:
        try:
            keyterm_list = json.loads(keyterms)
            if not isinstance(keyterm_list, list):
                keyterm_list = [str(keyterm_list)]
        except Exception:
            keyterm_list = [k.strip() for k in keyterms.split(",") if k.strip()]

    audio_bytes = await audio_file.read()
    result = await stt_provider.transcribe(
        audio_bytes=audio_bytes,
        filename=audio_file.filename or "audio.wav",
        language_code=language_code,
        model=model,
        format_mode=format,
        keyterms=keyterm_list,
        topic=topic,
        previous_text=previous_text
    )

    duration_sec = result.duration_seconds or (len(audio_bytes) / 32000.0 if len(audio_bytes) > 0 else 0.0)
    rate_limiter.record_audio_usage(client_id, duration_sec)

    return APIResponse(
        success=True,
        data=result.model_dump()
    )
