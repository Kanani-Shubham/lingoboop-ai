from abc import ABC, abstractmethod
from typing import Optional
from app.schemas.stt import STTResponseData
from app.schemas.tts import TTSRequest, TTSResponseMetadata


class BaseSTTProvider(ABC):
    """
    Abstract interface for Speech-to-Text providers.
    Enables swapping out Gnani Prisma for other providers (e.g. Whisper, Google Cloud Speech)
    without touching application route handlers or business logic.
    """
    @abstractmethod
    async def transcribe(
        self,
        audio_bytes: bytes,
        filename: str = "audio.wav",
        language_code: str = "gu-IN",
        model: Optional[str] = None
    ) -> STTResponseData:
        """Transcribe an audio buffer into text with confidence metrics."""
        pass


class BaseTTSProvider(ABC):
    """
    Abstract interface for Text-to-Speech providers.
    Enables swapping out Gnani Timbre for other providers (e.g. ElevenLabs, Google TTS)
    without rewriting application controllers.
    """
    @abstractmethod
    async def synthesize(
        self,
        request: TTSRequest
    ) -> TTSResponseMetadata:
        """Synthesize text into speech audio bytes (base64 encoded)."""
        pass
