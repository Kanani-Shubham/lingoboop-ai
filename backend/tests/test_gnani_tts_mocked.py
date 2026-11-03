import base64
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi import HTTPException
from app.providers.gnani_tts import GnaniTTSProvider
from app.schemas.tts import TTSRequest, AudioConfig


@pytest.mark.asyncio
async def test_tts_synthesize_raw_binary_mocked():
    provider = GnaniTTSProvider(api_key="mock_key_tts")

    dummy_audio_bytes = b"RIFF____WAVEfmt " + b"\x00" * 100
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.headers = {"content-type": "audio/wav"}
    mock_resp.content = dummy_audio_bytes

    req = TTSRequest(
        text="Hello, welcome to LingoBoom!",
        voice="Nalini",
        language="en-IN",
        speed=1.0
    )

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_resp
        result = await provider.synthesize(req)

        assert result.character_count == len(req.text)
        assert result.voice == "Nalini"
        assert result.language == "en-IN"
        assert result.content_type == "audio/wav"

        # Verify decoded audio matches original binary bytes
        decoded = base64.b64decode(result.audio_base64)
        assert decoded == dummy_audio_bytes

        # Verify headers sent
        call_kwargs = mock_post.call_args[1]
        assert call_kwargs["headers"]["X-API-Key-ID"] == "mock_key_tts"
        assert call_kwargs["json"]["text"] == "Hello, welcome to LingoBoom!"
        assert call_kwargs["json"]["model"] == "timbre-v3.0"


@pytest.mark.asyncio
async def test_tts_synthesize_json_response_mocked():
    provider = GnaniTTSProvider(api_key="mock_key_tts")

    sample_b64 = base64.b64encode(b"RIFF____WAVEfmt " + b"synthesized_audio_data").decode("utf-8")
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.headers = {"content-type": "application/json"}
    mock_resp.json.return_value = {"audio": sample_b64}

    req = TTSRequest(text="नमस्ते", language="hi-IN")

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_resp
        result = await provider.synthesize(req)

        assert result.audio_base64 == sample_b64
        assert result.language == "hi-IN"


@pytest.mark.asyncio
async def test_tts_auth_failure_mocked():
    provider = GnaniTTSProvider(api_key="bad_key")

    mock_resp = MagicMock()
    mock_resp.status_code = 401
    mock_resp.text = "Unauthorized"

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_resp
        with pytest.raises(HTTPException) as exc_info:
            await provider.synthesize(TTSRequest(text="Test"))

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail["error_code"] == "AUTHENTICATION_FAILED"


@pytest.mark.asyncio
async def test_tts_voice_catalog_endpoint():
    from app.routers.tts import get_voice_catalog
    resp = await get_voice_catalog()
    assert resp.success is True
    assert len(resp.data) == 13
    voice_ids = [v["id"] for v in resp.data]
    assert "Shivani" in voice_ids
    assert "Avinash" in voice_ids
    assert "Shubham" in voice_ids
    assert "Lakshmi" in voice_ids
    for v in resp.data:
        assert v["model"] == "timbre-v3.0"
        assert v["gender"] in ["male", "female"]
        assert len(v["supported_languages"]) > 0
        assert "en-IN" in v["sample_text_by_lang"]


