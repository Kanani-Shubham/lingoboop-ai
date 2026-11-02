from typing import Optional
from pydantic import BaseModel, Field


class TranslationRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000, description="Source text to translate")
    source_language: str = Field(default="gu-IN", description="BCP-47 or ISO language code of input")
    target_language: str = Field(default="en-IN", description="BCP-47 or ISO language code of target")
    character_id: Optional[str] = Field(default=None, description="Pet character identifier for persona-adapted tone")
    user_id: Optional[str] = Field(default=None, description="User ID for usage tracking")


class TranslationResponseData(BaseModel):
    original_text: str
    translated_text: str
    source_language: str
    target_language: str
    phonetic: Optional[str] = None
    notes: Optional[str] = None
    provider: str = Field(default="lingoboom_nmt", description="Engine used for translation")

