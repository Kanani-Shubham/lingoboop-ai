from typing import List, Optional
from app.ai.schemas.ai_schemas import (
    AITutorRequest,
    AITutorResponse,
    ConversationTurn,
)
from app.ai.services.ai_service import ai_service


class TutoringService:
    """Specialized tutoring service for grammar explanations, corrections, and interactive practice."""

    async def tutor(
        self,
        user_message: str,
        native_lang: str,
        target_lang: str,
        proficiency_level: str = "beginner",
        character_id: Optional[str] = "fox",
        history: Optional[List[ConversationTurn]] = None,
    ) -> AITutorResponse:
        req = AITutorRequest(
            user_message=user_message,
            native_language=native_lang,
            target_language=target_lang,
            proficiency_level=proficiency_level,
            character_id=character_id,
            history=history or [],
            mode="tutor",
        )
        return await ai_service.tutor_interaction(req)


tutoring_service = TutoringService()

