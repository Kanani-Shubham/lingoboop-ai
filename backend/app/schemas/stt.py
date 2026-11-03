from typing import List, Optional
from pydantic import BaseModel, Field


class WordConfidence(BaseModel):
    word: str
    confidence: Optional[float] = None
    start_time: Optional[float] = None
    end_time: Optional[float] = None


class STTRequestMetadata(BaseModel):
    language_code: str = Field(default="gu-IN", description="BCP-47 language code, e.g. gu-IN, hi-IN, en-IN")
    model: Optional[str] = Field(default="prisma-v3.0", description="Target STT model version")


class STTResponseData(BaseModel):
    transcript: str
    language_code: str
    model: str
    confidence: Optional[float] = None
    words: Optional[List[WordConfidence]] = None
    duration_seconds: Optional[float] = None
    truncated: Optional[bool] = None
    recording_id: Optional[str] = None
    raw_response: Optional[dict] = None

