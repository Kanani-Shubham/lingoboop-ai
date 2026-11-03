from fastapi import APIRouter, Depends
from app.core.rate_limiter import rate_limiter
from app.core.security import verify_client_token
from app.providers.gnani_tts import GnaniTTSProvider
from app.schemas.common import APIResponse
from app.schemas.tts import TTSRequest, VoiceItem

router = APIRouter(prefix="/api/v1/tts", tags=["Text-to-Speech"])

tts_provider = GnaniTTSProvider()

VERIFIED_VOICES = [
    # Female Voices
    VoiceItem(
        id="Shivani",
        name="Shivani",
        gender="female",
        description="Natural, warm, expressive (Default)",
    ),
    VoiceItem(
        id="Chetana",
        name="Chetana",
        gender="female",
        description="Bright, articulate, cheerful",
    ),
    VoiceItem(
        id="Kalpana",
        name="Kalpana",
        gender="female",
        description="Soothing, gentle, melodic",
    ),
    VoiceItem(
        id="Lakshmi",
        name="Lakshmi",
        gender="female",
        description="Clear, classic, professional",
    ),
    VoiceItem(
        id="Riyaa",
        name="Riyaa",
        gender="female",
        description="Lively, playful, enthusiastic",
    ),
    VoiceItem(
        id="Tarika",
        name="Tarika",
        gender="female",
        description="Crisp, modern, pleasant",
    ),
    VoiceItem(
        id="Vasudha",
        name="Vasudha",
        gender="female",
        description="Rich, melodic, comforting",
    ),
    # Male Voices
    VoiceItem(
        id="Avinash",
        name="Avinash",
        gender="male",
        description="Warm, friendly, confident",
    ),
    VoiceItem(
        id="Devansh",
        name="Devansh",
        gender="male",
        description="Youthful, energetic, bright",
    ),
    VoiceItem(
        id="Prakash",
        name="Prakash",
        gender="male",
        description="Clear, mature, reassuring",
    ),
    VoiceItem(
        id="Shubham",
        name="Shubham",
        gender="male",
        description="Natural, casual, conversational",
    ),
    VoiceItem(
        id="Yashraj",
        name="Yashraj",
        gender="male",
        description="Expressive, dynamic",
    ),
    VoiceItem(
        id="Harshad",
        name="Harshad",
        gender="male",
        description="Deep, authoritative, calm",
    ),
]


@router.get("/voices", response_model=APIResponse)
async def get_voice_catalog():
    """
    Returns the verified catalog of Gnani Timbre v3.0 voice characters.
    """
    return APIResponse(
        success=True,
        data=[v.model_dump() for v in VERIFIED_VOICES]
    )


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

