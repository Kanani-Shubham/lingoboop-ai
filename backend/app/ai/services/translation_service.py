from typing import Optional
from app.ai.schemas.ai_schemas import AITutorRequest, AITutorResponse
from app.ai.services.ai_service import ai_service


class TranslationService:
    """Specialized translation service delegating to Groq AI intelligence."""

    async def translate(
        self,
        text: str,
        source_lang: str,
        target_lang: str,
        character_id: Optional[str] = "fox",
    ) -> AITutorResponse:
        req = AITutorRequest(
            user_message=text,
            native_language=source_lang,
            target_language=target_lang,
            character_id=character_id,
            mode="translate",
        )
        return await ai_service.tutor_interaction(req)


translation_ai_service = TranslationService()

