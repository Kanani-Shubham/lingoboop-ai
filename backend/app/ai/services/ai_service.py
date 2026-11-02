import json
import re
from typing import Any, Dict, List, Optional
from app.ai.providers.groq_provider import GroqProvider
from app.ai.schemas.ai_schemas import (
    AITutorRequest,
    AITutorResponse,
    ConversationTurn,
    GrammarCorrectionRequest,
    GrammarCorrectionResponse,
    VocabularyItem,
)
from app.core.config import settings

# Character persona descriptions matching polypet-demo.html
PET_PERSONAS = {
    "fox": "You are Maru, a clever, energetic orange fox companion who loves words, idioms, and quick conversation. You speak enthusiastically and encourage learners warmly.",
    "cat": "You are Mimi, a stylish, sharp-witted lavender cat who appreciates precise grammar, elegant pronunciation, and thoughtful phrasing.",
    "rabbit": "You are Bun, an affectionate, cheerful yellow bunny who loves simple daily conversations, warm greetings, and celebrating every little achievement.",
    "panda": "You are Pano, a gentle, wise teal panda who is calm, reassuring, and helps learners practice slowly without feeling rushed or self-conscious.",
    "chick": "You are Pip, a curious, peppy green chick who asks fun follow-up questions and loves discovering new vocabulary words together.",
    "lion": "You are Leo, a noble, encouraging coral lion who inspires courage in speaking out loud and making confident practice mistakes.",
}

LANGUAGE_NAMES = {
    "gu": "Gujarati",
    "gu-in": "Gujarati",
    "hi": "Hindi",
    "hi-in": "Hindi",
    "en": "English",
    "en-us": "English",
    "en-in": "English",
    "ta": "Tamil",
    "ta-in": "Tamil",
    "te": "Telugu",
    "te-in": "Telugu",
    "mr": "Marathi",
    "mr-in": "Marathi",
    "bn": "Bengali",
    "bn-in": "Bengali",
    "es": "Spanish",
    "fr": "French",
    "ja": "Japanese",
}


class AIService:
    """
    Central AI Intelligence Orchestrator.
    Manages Groq openai/gpt-oss-120b inference, persona adaptation, structured JSON synthesis,
    and fallback handling.
    """

    def __init__(self, provider: Optional[GroqProvider] = None):
        self.provider = provider or GroqProvider()

    def _build_system_prompt(self, req: AITutorRequest) -> str:
        pet_key = (req.character_id or "fox").lower()
        persona = PET_PERSONAS.get(pet_key, PET_PERSONAS["fox"])

        native_lang_code = req.native_language.lower().split("-")[0]
        target_lang_code = req.target_language.lower().split("-")[0]
        native_lang_name = LANGUAGE_NAMES.get(native_lang_code, req.native_language)
        target_lang_name = LANGUAGE_NAMES.get(target_lang_code, req.target_language)

        return f"""{persona}
You are an expert AI language tutor and speaking partner for LingoBoom.
The learner's native language is {native_lang_name} ({req.native_language}) and their target learning language is {target_lang_name} ({req.target_language}).
Learner proficiency level: {req.proficiency_level}.

CRITICAL INSTRUCTIONS:
1. When the user speaks or writes in {native_lang_name}, translate their sentence accurately into natural {target_lang_name}.
2. When the user speaks or writes in {target_lang_name}, review their grammar:
   - If incorrect, provide a gentle correction in "correction" and explain the mistake simply in {native_lang_name} in "explanation".
   - If correct, set "correction" to null and provide a short compliment or insight in "explanation".
3. "reply_text": Your spoken conversational response to the user in {target_lang_name} (keep it friendly, natural, and concise - 1 to 2 sentences max so it can be spoken via Text-to-Speech).
4. "examples": Provide 1 to 2 natural alternative ways to say the sentence.
5. "pronunciation_guide": Provide a clear phonetic pronunciation guide for the translated sentence or reply.
6. Never invent non-existent grammar rules. Be warm, patient, and never make the learner feel embarrassed.

YOU MUST ALWAYS RESPOND IN STRICT VALID JSON MATCHING THIS EXACT SCHEMA:
{{
  "source_text": string,
  "translated_text": string,
  "detected_language": string (ISO 639-1 e.g. "gu", "hi", "en"),
  "target_language": string (ISO 639-1 e.g. "en", "gu", "hi"),
  "correction": string or null,
  "explanation": string,
  "examples": [string],
  "reply_text": string,
  "pronunciation_guide": string,
  "vocabulary_breakdown": [
    {{"word": string, "meaning": string, "part_of_speech": string, "example": string}}
  ],
  "conversation_mode": "learning"
}}"""

    async def tutor_interaction(self, req: AITutorRequest) -> AITutorResponse:
        """
        Processes learner input through Groq openai/gpt-oss-120b and returns a structured response.
        """
        # If Groq key is not yet configured, provide safe instructional fallback
        if not settings.is_groq_configured():
            return self._build_unconfigured_fallback(req)

        system_prompt = self._build_system_prompt(req)

        messages: List[Dict[str, str]] = [{"role": "system", "content": system_prompt}]

        # Append recent bounded history (max 6 turns to manage token window)
        bounded_history = req.history[-6:] if req.history else []
        for turn in bounded_history:
            messages.append({"role": turn.role, "content": turn.content})

        # Append current user message
        messages.append({"role": "user", "content": req.user_message})

        try:
            raw_content = await self.provider.chat_completion(
                messages=messages,
                model=settings.GROQ_MODEL,
                temperature=0.3,
                max_tokens=1024,
                response_format={"type": "json_object"},
            )

            parsed_data = self._clean_and_parse_json(raw_content)
            return AITutorResponse(
                source_text=parsed_data.get("source_text") or req.user_message,
                translated_text=parsed_data.get("translated_text") or req.user_message,
                detected_language=parsed_data.get("detected_language") or req.native_language[:2],
                target_language=parsed_data.get("target_language") or req.target_language[:2],
                correction=parsed_data.get("correction"),
                explanation=parsed_data.get("explanation"),
                examples=parsed_data.get("examples") or [],
                reply_text=parsed_data.get("reply_text") or parsed_data.get("translated_text") or "Keep practicing!",
                pronunciation_guide=parsed_data.get("pronunciation_guide"),
                vocabulary_breakdown=[
                    VocabularyItem(**item) for item in parsed_data.get("vocabulary_breakdown", [])
                    if isinstance(item, dict) and "word" in item and "meaning" in item
                ] if parsed_data.get("vocabulary_breakdown") else None,
                conversation_mode=parsed_data.get("conversation_mode") or "learning",
                provider="groq",
                model=settings.GROQ_MODEL,
            )

        except Exception as e:
            # Handle upstream provider errors gracefully
            if isinstance(e, json.JSONDecodeError):
                return self._build_resilient_fallback(req, f"AI response formatting issue: {str(e)[:60]}")
            raise e

    def _clean_and_parse_json(self, raw_str: str) -> Dict[str, Any]:
        """Strip markdown fences (```json ... ```) and extract valid JSON."""
        cleaned = raw_str.strip()
        if cleaned.startswith("```"):
            cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
            cleaned = re.sub(r"\s*```$", "", cleaned)
        return json.loads(cleaned)

    def _build_unconfigured_fallback(self, req: AITutorRequest) -> AITutorResponse:
        """Returns a helpful structured message when GROQ_API_KEY is not yet added."""
        clean_text = req.user_message.strip()
        return AITutorResponse(
            source_text=clean_text,
            translated_text=clean_text,
            detected_language=req.native_language[:2],
            target_language=req.target_language[:2],
            correction=None,
            explanation="Groq API key is not yet configured. Please add GROQ_API_KEY to backend/.env to activate GPT-OSS 120B intelligence.",
            examples=[clean_text],
            reply_text=f"Hello! I am ready to practice with you once your Groq API key is added.",
            pronunciation_guide=None,
            vocabulary_breakdown=None,
            conversation_mode="setup_required",
            provider="lingoboom_local_gateway",
            model="unconfigured",
        )

    def _build_resilient_fallback(self, req: AITutorRequest, reason: str) -> AITutorResponse:
        clean_text = req.user_message.strip()
        return AITutorResponse(
            source_text=clean_text,
            translated_text=clean_text,
            detected_language=req.native_language[:2],
            target_language=req.target_language[:2],
            correction=None,
            explanation=reason,
            examples=[clean_text],
            reply_text=f"Let's practice: {clean_text}",
            pronunciation_guide=None,
            vocabulary_breakdown=None,
            conversation_mode="resilient_mode",
            provider="groq_fallback",
            model=settings.GROQ_MODEL,
        )


ai_service = AIService()

