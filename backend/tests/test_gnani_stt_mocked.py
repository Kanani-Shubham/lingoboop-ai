import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi import HTTPException
from app.providers.gnani_stt import GnaniSTTProvider


@pytest.mark.asyncio
async def test_stt_transcribe_success_mocked():
    provider = GnaniSTTProvider(api_key="mock_key_12345")

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "transcript": "તમને કેમ છે?",
        "confidence": 0.94,
        "words": [
            {"word": "તમને", "confidence": 0.95, "start_time": 0.0, "end_time": 0.4},
            {"word": "કેમ", "confidence": 0.93, "start_time": 0.45, "end_time": 0.75},
            {"word": "છે", "confidence": 0.94, "start_time": 0.8, "end_time": 1.1}
        ]
    }

    dummy_audio = b"\x00\x00" * 8000  # 0.5s dummy PCM

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_resp
        result = await provider.transcribe(
            audio_bytes=dummy_audio,
            filename="test.wav",
            language_code="gu-IN"
        )

        assert result.transcript == "તમને કેમ છે?"
        assert result.language_code == "gu-IN"
        assert result.confidence == 0.94
        assert len(result.words) == 3
        assert result.words[0].word == "તમને"

        # Verify correct header and endpoint were called
        mock_post.assert_called_once()
        call_kwargs = mock_post.call_args[1]
        assert call_kwargs["headers"]["X-API-Key-ID"] == "mock_key_12345"
        assert "audio_file" in call_kwargs["files"]
        assert call_kwargs["data"]["language_code"] == "gu-IN"


@pytest.mark.asyncio
async def test_stt_authentication_error_mocked():
    provider = GnaniSTTProvider(api_key="invalid_key")

    mock_resp = MagicMock()
    mock_resp.status_code = 401
    mock_resp.text = "Unauthorized: Invalid API Key"

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_resp
        with pytest.raises(HTTPException) as exc_info:
            await provider.transcribe(audio_bytes=b"dummy", language_code="hi-IN")

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail["error_code"] == "AUTHENTICATION_FAILED"


@pytest.mark.asyncio
async def test_stt_rate_limit_mocked():
    provider = GnaniSTTProvider(api_key="mock_key")

    mock_resp = MagicMock()
    mock_resp.status_code = 429
    mock_resp.text = "Rate limit exceeded"

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_resp
        with pytest.raises(HTTPException) as exc_info:
            await provider.transcribe(audio_bytes=b"dummy")

        assert exc_info.value.status_code == 429
        assert exc_info.value.detail["error_code"] == "UPSTREAM_RATE_LIMITED"


@pytest.mark.asyncio
async def test_stt_empty_audio_validation():
    provider = GnaniSTTProvider(api_key="mock_key")
    with pytest.raises(HTTPException) as exc_info:
        await provider.transcribe(audio_bytes=b"")

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["error_code"] == "EMPTY_AUDIO"

