import json
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi import HTTPException
from app.providers.gnani_stt import (
    GnaniSTTProvider,
    DEFAULT_GUJARATI_KEYTERMS,
    _validate_and_repair_wav,
    _merge_transcripts
)


def test_default_gujarati_keyterms_contain_essential_phrases():
    essential = ["છે", "છું", "જાઉં છું", "જઈશ", "જવાનો છું", "જવાનું છે", "જાગવાનું છે", "કાલે સવારે", "વહેલું", "ઘરે"]
    for phrase in essential:
        assert phrase in DEFAULT_GUJARATI_KEYTERMS


def test_merge_transcripts_deduplicates_overlapping_words():
    t1 = "હું ઘરે કાલે જવાનો છું, કાલે સવારે વહેલું"
    t2 = "કાલે સવારે વહેલું જાગવાનું છે."
    merged = _merge_transcripts([t1, t2])
    assert merged == "હું ઘરે કાલે જવાનો છું, કાલે સવારે વહેલું જાગવાનું છે."


def test_merge_transcripts_single_and_empty():
    assert _merge_transcripts([]) == ""
    assert _merge_transcripts(["એક વાક્ય છે."]) == "એક વાક્ય છે."


def test_validate_and_repair_wav_header():
    # Build standard 44-byte WAV header with 0xFFFFFFFF placeholder
    import struct
    header = bytearray(44)
    struct.pack_into("<4sI4s4sIHHIIHH4sI", header, 0,
                     b"RIFF", 0xFFFFFFFF, b"WAVE",
                     b"fmt ", 16, 1, 1, 16000,
                     32000, 2, 16,
                     b"data", 0xFFFFFFFF)
    pcm = b"\x00\x00" * 16000  # 1 second of silence (32000 bytes)
    raw_wav = bytes(header) + pcm

    repaired, sample_rate, channels, bits, dur = _validate_and_repair_wav(raw_wav)
    assert sample_rate == 16000
    assert channels == 1
    assert bits == 16
    assert abs(dur - 1.0) < 0.05

    # Check repaired sizes
    riff_size = struct.unpack("<I", repaired[4:8])[0]
    data_size = struct.unpack("<I", repaired[40:44])[0]
    assert riff_size == len(raw_wav) - 8
    assert data_size == len(pcm)


@pytest.mark.asyncio
async def test_transcribe_gujarati_with_keyterms_and_format():
    provider = GnaniSTTProvider(api_key="mock_key")
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "success": True,
        "request_id": "test-req-123",
        "transcript": "હું ઘરે કાલે જવાનો છું, કાલે સવારે વહેલું જાગવાનું છે.",
        "model": "prisma-v3.0",
        "detected_language_code": "gu-IN",
        "processing_time": 0.28,
        "end_to_end_latency": 0.29
    }

    dummy_pcm = b"\x00\x00" * 8000  # 0.5 sec audio

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_resp
        res = await provider.transcribe(
            audio_bytes=dummy_pcm,
            language_code="gu-IN",
            model="prisma-v3.0"
        )

        assert res.transcript == "હું ઘરે કાલે જવાનો છું, કાલે સવારે વહેલું જાગવાનું છે."
        assert res.language_code == "gu-IN"
        assert res.model == "prisma-v3.0"

        # Verify posted form data
        call_kwargs = mock_post.call_args[1]
        data = call_kwargs["data"]
        assert data["model"] == "prisma-v3.0"
        assert data["language_code"] == "gu-IN"
        assert data["format"] == "transcribe"
        assert "keyterms" in data
        keyterms_sent = json.loads(data["keyterms"])
        assert "છે" in keyterms_sent
        assert "જાગવાનું છે" in keyterms_sent


@pytest.mark.asyncio
async def test_transcribe_codemix_mode_for_english_mixed():
    provider = GnaniSTTProvider(api_key="mock_key")
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "success": True,
        "request_id": "test-req-456",
        "transcript": "કાલે મારે college જવાનું છે.",
        "model": "prisma-v3.0"
    }

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_resp
        res = await provider.transcribe(
            audio_bytes=b"\x00\x00" * 4000,
            language_code="gu-IN,en-IN"
        )
        assert res.transcript == "કાલે મારે college જવાનું છે."
        data = mock_post.call_args[1]["data"]
        assert data["format"] == "codemix"
