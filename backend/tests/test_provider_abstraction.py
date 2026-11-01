import pytest
from typing import Optional
from app.providers.base import BaseSTTProvider, BaseTTSProvider
from app.schemas.stt import STTResponseData
from app.schemas.tts import TTSRequest, TTSResponseMetadata


class MockAlternativeSTTProvider(BaseSTTProvider):
    """Demonstrates swapping Gnani STT for a third-party engine (e.g. Whisper) cleanly."""
    async def transcribe(
        self,
        audio_bytes: bytes,
        filename: str = "audio.wav",
        language_code: str = "gu-IN",
        model: Optional[str] = None
    ) -> STTResponseData:
        return STTResponseData(
            transcript="Alternative provider transcription",
            language_code=language_code,
            model="mock-whisper-v3",
            confidence=0.99
        )


class MockAlternativeTTSProvider(BaseTTSProvider):
    """Demonstrates swapping Gnani TTS for a third-party engine cleanly."""
    async def synthesize(self, request: TTSRequest) -> TTSResponseMetadata:
        return TTSResponseMetadata(
            audio_base64="ZHVtbXlfc3BlZWNo",
            content_type="audio/wav",
            character_count=len(request.text),
            voice="MockVoice",
            model="mock-tts-v1",
            language=request.language
        )


@pytest.mark.asyncio
async def test_swappable_stt_provider_contract():
    provider: BaseSTTProvider = MockAlternativeSTTProvider()
    res = await provider.transcribe(b"raw_bytes", language_code="hi-IN")
    assert isinstance(res, STTResponseData)
    assert res.transcript == "Alternative provider transcription"
    assert res.model == "mock-whisper-v3"


@pytest.mark.asyncio
async def test_swappable_tts_provider_contract():
    provider: BaseTTSProvider = MockAlternativeTTSProvider()
    res = await provider.synthesize(TTSRequest(text="Hello world"))
    assert isinstance(res, TTSResponseMetadata)
    assert res.audio_base64 == "ZHVtbXlfc3BlZWNo"
