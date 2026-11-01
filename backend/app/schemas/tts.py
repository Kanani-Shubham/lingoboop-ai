from typing import Optional
from pydantic import BaseModel, Field


class AudioConfig(BaseModel):
    sample_rate: int = 16000
    num_channels: int = 1
    sample_width: int = 2
    encoding: str = "linear_pcm"
    container: str = "wav"


class TTSRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=1000, description="Text string to synthesize")
    voice: str = Field(default="Shivani", description="Voice identifier from catalog: Shivani, Avinash, Lakshmi, Kalpana, Shubham, etc.")
    model: str = Field(default="timbre-v3.0", description="TTS model version: timbre-v2.5 or timbre-v3.0")
    language: str = Field(default="hi-IN", description="Language code: hi-IN, en-IN, gu-IN, etc.")
    speed: float = Field(default=1.0, ge=0.5, le=2.0, description="Playback tempo multiplier")
    audio_config: Optional[AudioConfig] = Field(default_factory=AudioConfig)


class TTSResponseMetadata(BaseModel):
    audio_base64: str
    content_type: str = "audio/wav"
    character_count: int
    voice: str
    model: str
    language: str
