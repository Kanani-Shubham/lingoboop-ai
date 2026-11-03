from fastapi import APIRouter
from app.core.config import settings
from app.schemas.common import APIResponse

router = APIRouter(tags=["Health"])


@router.get("/health", response_model=APIResponse)
@router.get("/api/v1/health", response_model=APIResponse)
async def health_check():
    """System health check and provider readiness report (zero secrets exposed)."""
    return APIResponse(
        success=True,
        data={
            "status": "healthy",
            "app_name": settings.APP_NAME,
            "environment": settings.APP_ENV,
            "gnani_provider": {
                "configured": settings.is_gnani_configured(),
                "base_url": settings.GNANI_BASE_URL,
                "stt_model": settings.GNANI_STT_DEFAULT_MODEL,
                "tts_model": settings.GNANI_TTS_DEFAULT_MODEL,
                "api_key_status": "present" if settings.is_gnani_configured() else "missing"
            },
            "supabase": {
                "configured": settings.is_supabase_configured(),
                "service_role_configured": settings.is_supabase_service_role_configured()
            }
        }
    )
