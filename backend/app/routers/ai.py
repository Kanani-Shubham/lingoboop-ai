from fastapi import APIRouter, Depends
from app.ai.schemas.ai_schemas import (
    AITutorRequest,
    AITutorResponse,
    GrammarCorrectionRequest,
    GrammarCorrectionResponse,
)
from app.ai.services.ai_service import ai_service
from app.core.rate_limiter import rate_limiter
from app.core.security import verify_client_token
from app.schemas.common import APIResponse

router = APIRouter(prefix="/api/v1/ai", tags=["AI Intelligence (Groq)"])


@router.post("/tutor", response_model=APIResponse)
async def tutor_endpoint(
    request: AITutorRequest,
    client_id: str = Depends(verify_client_token),
):
    """
    Central AI Intelligence Endpoint (Powered by Groq openai/gpt-oss-120b).
    Provides structured translation, grammar corrections, explanations in native tongue,
    and pet-adapted spoken replies.
    """
    rate_limiter.check_rate_limit(client_id)

    result = await ai_service.tutor_interaction(request)

    return APIResponse(
        success=True,
        data=result.model_dump(),
    )


@router.post("/translate", response_model=APIResponse)
async def translate_endpoint(
    request: AITutorRequest,
    client_id: str = Depends(verify_client_token),
):
    """
    AI-Powered Translation with grammar context and alternatives.
    """
    rate_limiter.check_rate_limit(client_id)
    request.mode = "translate"

    result = await ai_service.tutor_interaction(request)

    return APIResponse(
        success=True,
        data=result.model_dump(),
    )


@router.post("/correct", response_model=APIResponse)
async def correct_endpoint(
    request: GrammarCorrectionRequest,
    client_id: str = Depends(verify_client_token),
):
    """
    Grammar correction and explanation endpoint.
    """
    rate_limiter.check_rate_limit(client_id)

    tutor_req = AITutorRequest(
        user_message=request.sentence,
        native_language=request.native_language,
        target_language=request.target_language,
        character_id=request.character_id,
        mode="correct",
    )

    tutor_res = await ai_service.tutor_interaction(tutor_req)

    is_correct = tutor_res.correction is None or tutor_res.correction.strip() == tutor_res.source_text.strip()
    corrected = tutor_res.correction if tutor_res.correction else tutor_res.source_text

    response_data = GrammarCorrectionResponse(
        original_sentence=request.sentence,
        corrected_sentence=corrected,
        is_correct=is_correct,
        explanation=tutor_res.explanation or "The sentence looks good!",
        improved_alternatives=tutor_res.examples,
    )

    return APIResponse(
        success=True,
        data=response_data.model_dump(),
    )

