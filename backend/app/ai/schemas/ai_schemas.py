from typing import Dict, List, Literal, Optional
from pydantic import BaseModel, Field


class ConversationTurn(BaseModel):
    role: Literal["user", "assistant", "system"]
    content: str


class VocabularyItem(BaseModel):
    word: str
    meaning: str
    part_of_speech: Optional[str] = None
    example: Optional[str] = None


class AITutorRequest(BaseModel):
    user_message: str = Field(..., min_length=1, max_length=2000, description="User's input text or speech transcript")
    native_language: str = Field(default="gu-IN", description="User's native language code (e.g. gu-IN, hi-IN)")
    target_language: str = Field(default="en-US", description="Target learning language code (e.g. en-US, en-IN)")
    proficiency_level: Literal["beginner", "intermediate", "advanced"] = Field(
        default="beginner", description="Learner's current skill level"
    )
    character_id: Optional[str] = Field(default="fox", description="Selected PolyPet character key")
    history: List[ConversationTurn] = Field(default_factory=list, description="Recent conversation turns (max 6-8)")
    mode: Literal["tutor", "translate", "correct", "exercise", "vocabulary"] = Field(
        default="tutor", description="Interaction intent"
    )


class AITutorResponse(BaseModel):
    source_text: str = Field(..., description="Original user input")
    translated_text: str = Field(..., description="Accurate translation into target language")
    detected_language: str = Field(default="gu", description="Detected language code of source_text")
    target_language: str = Field(default="en", description="Target language code")
    correction: Optional[str] = Field(default=None, description="Corrected sentence if user made grammar mistakes")
    explanation: Optional[str] = Field(default=None, description="Helpful, non-judgmental explanation in user's native language")
    examples: List[str] = Field(default_factory=list, description="Natural alternative sentences or usage examples")
    reply_text: str = Field(..., description="AI Companion's spoken response back to the learner")
    pronunciation_guide: Optional[str] = Field(default=None, description="Phonetic or transliterated speaking guide")
    vocabulary_breakdown: Optional[List[VocabularyItem]] = Field(
        default=None, description="Important vocabulary explained in native tongue"
    )
    conversation_mode: str = Field(default="learning", description="Context mode")
    provider: str = Field(default="groq", description="Underlying AI inference provider")
    model: str = Field(default="openai/gpt-oss-120b", description="AI model used")


class GrammarCorrectionRequest(BaseModel):
    sentence: str = Field(..., min_length=1, max_length=1000)
    native_language: str = Field(default="gu-IN")
    target_language: str = Field(default="en-US")
    character_id: Optional[str] = Field(default="fox")


class GrammarCorrectionResponse(BaseModel):
    original_sentence: str
    corrected_sentence: str
    is_correct: bool
    explanation: str
    improved_alternatives: List[str] = Field(default_factory=list)


class ExerciseItem(BaseModel):
    id: str
    prompt: str
    native_prompt: str
    options: List[str] = Field(default_factory=list)
    correct_answer: str
    explanation: str


class ExerciseResponse(BaseModel):
    proficiency_level: str
    target_language: str
    topic: str
    exercises: List[ExerciseItem]


class DailyPracticeItem(BaseModel):
    id: str
    target_sentence: str
    native_translation: str
    category: str
    difficulty: str
    pronunciation_guide: Optional[str] = None
    context_tip: Optional[str] = None


class DailyPracticeRequest(BaseModel):
    native_language: str = Field(default="gu-IN")
    target_language: str = Field(default="en-US")
    proficiency_level: Literal["beginner", "intermediate", "advanced"] = Field(default="beginner")
    count: int = Field(default=20, ge=5, le=30)
    category: Optional[str] = None


class DailyPracticeResponse(BaseModel):
    date: str
    native_language: str
    target_language: str
    proficiency_level: str
    sentences: List[DailyPracticeItem]

