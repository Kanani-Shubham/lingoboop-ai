import httpx
import json
import logging
import re
import struct
import time
import uuid
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from app.core.config import settings
from app.providers.base import BaseSTTProvider
from app.schemas.stt import STTResponseData, WordConfidence

logger = logging.getLogger("lingoboop.stt")

_SHARED_STT_CLIENT: Optional[httpx.AsyncClient] = None

# Contextual vocabulary hints for conversational Gujarati language learning
DEFAULT_GUJARATI_KEYTERMS = [
    "છે", "છું", "જાઉં છું", "જઈશ", "જવાનો છું", "જવાનું છે", "જાગવાનું છે",
    "કાલે સવારે", "વહેલું", "ઘરે", "મને", "તમારે", "શું", "ક્યાં", "કેમ",
    "આવશો", "નહીં", "ગામમાં", "કામ", "અભ્યાસ", "મિત્રો", "કોલેજ", "પ્રોજેક્ટ"
]


def _get_shared_stt_client(timeout: float) -> httpx.AsyncClient:
    global _SHARED_STT_CLIENT
    if _SHARED_STT_CLIENT is None or _SHARED_STT_CLIENT.is_closed:
        _SHARED_STT_CLIENT = httpx.AsyncClient(
            timeout=timeout,
            limits=httpx.Limits(max_keepalive_connections=20, max_connections=50)
        )
    return _SHARED_STT_CLIENT


def _validate_and_repair_wav(audio_bytes: bytes) -> Tuple[bytes, int, int, int, float]:
    """
    Validates audio WAV bytes, repairs 0xFFFFFFFF streaming placeholder size fields,
    and returns (repaired_bytes, sample_rate, channels, bits_per_sample, duration_seconds).
    """
    if len(audio_bytes) < 44:
        if audio_bytes.startswith(b"RIFF"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error_code": "AUDIO_TOO_SHORT", "message": f"Audio file is too short ({len(audio_bytes)} bytes)."}
            )
        sample_rate = 16000
        channels = 1
        bits_per_sample = 16
        duration_sec = len(audio_bytes) / 32000.0
        return audio_bytes, sample_rate, channels, bits_per_sample, duration_sec

    # Check for RIFF header
    if audio_bytes.startswith(b"RIFF"):
        data_idx = -1
        for i in range(12, min(len(audio_bytes) - 8, 200)):
            if audio_bytes[i:i+4] == b"data":
                data_idx = i
                break

        sample_rate = 16000
        channels = 1
        bits_per_sample = 16

        try:
            channels = struct.unpack("<H", audio_bytes[22:24])[0]
            sample_rate = struct.unpack("<I", audio_bytes[24:28])[0]
            bits_per_sample = struct.unpack("<H", audio_bytes[34:36])[0]
        except Exception:
            pass

        if channels not in (1, 2):
            channels = 1
        if sample_rate < 8000 or sample_rate > 48000:
            sample_rate = 16000
        if bits_per_sample not in (8, 16, 24, 32):
            bits_per_sample = 16

        ba = bytearray(audio_bytes)
        actual_riff_size = len(audio_bytes) - 8

        if data_idx != -1:
            actual_data_size = len(audio_bytes) - (data_idx + 8)
            existing_riff = struct.unpack("<I", audio_bytes[4:8])[0]
            existing_data = struct.unpack("<I", audio_bytes[data_idx+4:data_idx+8])[0]
            if existing_riff in (0, 0xFFFFFFFF) or existing_data in (0, 0xFFFFFFFF) or existing_data > len(audio_bytes):
                struct.pack_into("<I", ba, 4, actual_riff_size)
                struct.pack_into("<I", ba, data_idx + 4, actual_data_size)
            bytes_per_sec = sample_rate * channels * (bits_per_sample // 8)
            duration_sec = actual_data_size / float(bytes_per_sec) if bytes_per_sec > 0 else 0.0
            return bytes(ba), sample_rate, channels, bits_per_sample, duration_sec

        bytes_per_sec = sample_rate * channels * (bits_per_sample // 8)
        duration_sec = (len(audio_bytes) - 44) / float(bytes_per_sec) if bytes_per_sec > 0 else 0.0
        return bytes(ba), sample_rate, channels, bits_per_sample, duration_sec

    # Raw PCM audio without header
    sample_rate = 16000
    channels = 1
    bits_per_sample = 16
    bytes_per_sec = sample_rate * channels * (bits_per_sample // 8)
    duration_sec = len(audio_bytes) / float(bytes_per_sec) if bytes_per_sec > 0 else 0.0
    return audio_bytes, sample_rate, channels, bits_per_sample, duration_sec


def _merge_transcripts(transcripts: List[str]) -> str:
    """Merges sequential overlapping transcripts by detecting and deduplicating word overlap."""
    if not transcripts:
        return ""
    if len(transcripts) == 1:
        return transcripts[0].strip()

    merged = transcripts[0].strip()
    for t in transcripts[1:]:
        t = t.strip()
        if not t:
            continue
        words1 = merged.split()
        words2 = t.split()

        max_overlap = min(len(words1), len(words2), 8)
        best_overlap = 0
        for k in range(max_overlap, 0, -1):
            w1_sub = [re.sub(r'[^\w\s]', '', w) for w in words1[-k:]]
            w2_sub = [re.sub(r'[^\w\s]', '', w) for w in words2[:k]]
            if w1_sub == w2_sub:
                best_overlap = k
                break

        if best_overlap > 0:
            merged = " ".join(words1 + words2[best_overlap:])
        else:
            merged = f"{merged} {t}"

    return merged


class GnaniSTTProvider(BaseSTTProvider):
    """
    Official Gnani Prisma v3.0 STT Provider Implementation.
    Uses official endpoint: POST https://api.vachana.ai/stt/v3
    Authentication Header: X-API-Key-ID: <GNANI_API_KEY>
    """
    def __init__(self, api_key: Optional[str] = None, base_url: Optional[str] = None):
        self.api_key = api_key or settings.GNANI_API_KEY
        self.base_url = (base_url or settings.GNANI_BASE_URL).rstrip("/")
        self.endpoint_url = f"{self.base_url}{settings.GNANI_STT_PATH}"
        self.timeout = settings.GNANI_REQUEST_TIMEOUT_SECONDS

    def _get_headers(self) -> dict:
        if not self.api_key or not self.api_key.strip():
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail={
                    "error_code": "PROVIDER_KEY_MISSING",
                    "message": "Gnani API key is not configured. Set GNANI_API_KEY in backend/.env."
                }
            )
        return {
            "X-API-Key-ID": self.api_key.strip()
        }

    async def transcribe(
        self,
        audio_bytes: bytes,
        filename: str = "audio.wav",
        language_code: str = "gu-IN",
        model: Optional[str] = None,
        format_mode: Optional[str] = None,
        keyterms: Optional[list] = None,
        topic: Optional[str] = None,
        previous_text: Optional[str] = None
    ) -> STTResponseData:
        if not audio_bytes or len(audio_bytes) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error_code": "EMPTY_AUDIO", "message": "Provided audio file is empty."}
            )

        rec_id = uuid.uuid4().hex[:8]
        repaired_audio, sample_rate, channels, bits, duration_sec = _validate_and_repair_wav(audio_bytes)
        target_model = model or settings.GNANI_STT_DEFAULT_MODEL

        # Determine optimal format mode:
        # For pure Gujarati: 'transcribe' applies ITN (numbers, currency) and preserves script.
        # For mixed Gujarati/English: 'codemix' preserves Latin script for English words and Gujarati for Gujarati.
        if format_mode:
            target_format = format_mode
        elif "en" in language_code.lower() or language_code == "indic-auto":
            target_format = "codemix"
        else:
            target_format = "transcribe"

        # Determine keyterms:
        # Combine default Gujarati learning keyterms with caller-supplied terms
        effective_keyterms = []
        if "gu" in language_code.lower() or language_code == "indic-auto":
            effective_keyterms.extend(DEFAULT_GUJARATI_KEYTERMS)
        if keyterms and isinstance(keyterms, list):
            for k in keyterms:
                if k not in effective_keyterms:
                    effective_keyterms.append(k)

        # Handle Long Audio Segmentation (if audio > 26.0 seconds)
        # Gnani REST endpoint enforces a 30-second hard limit per request.
        if duration_sec > 26.0:
            logger.info(f"[GnaniSTT] Recording {rec_id} duration ({duration_sec:.2f}s) > 26s; applying speech segmentation.")
            return await self._transcribe_long_audio_segmented(
                rec_id=rec_id,
                audio_bytes=repaired_audio,
                sample_rate=sample_rate,
                channels=channels,
                bits=bits,
                duration_sec=duration_sec,
                filename=filename,
                language_code=language_code,
                target_model=target_model,
                target_format=target_format,
                keyterms=effective_keyterms,
                topic=topic,
                previous_text=previous_text
            )

        # Single-segment transcription
        return await self._transcribe_single_segment(
            rec_id=rec_id,
            audio_bytes=repaired_audio,
            duration_sec=duration_sec,
            sample_rate=sample_rate,
            channels=channels,
            filename=filename,
            language_code=language_code,
            target_model=target_model,
            target_format=target_format,
            keyterms=effective_keyterms,
            topic=topic or "Language learning, daily conversation, translation",
            previous_text=previous_text
        )

    async def _transcribe_single_segment(
        self,
        rec_id: str,
        audio_bytes: bytes,
        duration_sec: float,
        sample_rate: int,
        channels: int,
        filename: str,
        language_code: str,
        target_model: str,
        target_format: str,
        keyterms: list,
        topic: Optional[str] = None,
        previous_text: Optional[str] = None
    ) -> STTResponseData:
        headers = self._get_headers()

        files = {
            "audio_file": (filename, audio_bytes, "audio/wav")
        }
        data = {
            "model": target_model,
            "language_code": language_code,
            "format": target_format
        }

        if keyterms:
            data["keyterms"] = json.dumps(keyterms[:200], ensure_ascii=False)
        if topic:
            data["topic"] = topic[:1600]
        if previous_text:
            data["previous_text"] = previous_text[-600:]

        start_time = time.time()
        try:
            client = _get_shared_stt_client(self.timeout)
            response = await client.post(
                self.endpoint_url,
                headers=headers,
                files=files,
                data=data
            )
            latency = time.time() - start_time

            if response.status_code == 401 or response.status_code == 403:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail={
                        "error_code": "AUTHENTICATION_FAILED",
                        "message": "Invalid Gnani API key or insufficient permissions for STT."
                    }
                )
            elif response.status_code == 429:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail={
                        "error_code": "UPSTREAM_RATE_LIMITED",
                        "message": "Gnani API quota/rate limit reached. Please wait before retrying."
                    }
                )
            elif response.status_code >= 400:
                err_detail = "Upstream provider error"
                try:
                    err_json = response.json()
                    err_detail = err_json.get("message") or err_json.get("detail") or err_detail
                except Exception:
                    err_detail = response.text[:200]
                raise HTTPException(
                    status_code=response.status_code,
                    detail={"error_code": "UPSTREAM_ERROR", "message": err_detail}
                )

            res_json = response.json()
            parsed = self._parse_response(res_json, language_code, target_model, duration_sec, rec_id)

            logger.info(
                f"[GnaniSTT] RecID: {rec_id} | Lang: {language_code} | Model: {target_model} | Format: {target_format} "
                f"| Dur: {duration_sec:.2f}s | Bytes: {len(audio_bytes)} | Latency: {latency:.2f}s "
                f"| Truncated: {parsed.truncated} | Transcript: '{parsed.transcript}'"
            )
            return parsed

        except httpx.TimeoutException:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail={"error_code": "TIMEOUT", "message": f"Gnani STT timed out after {self.timeout}s."}
            )
        except httpx.RequestError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail={"error_code": "NETWORK_ERROR", "message": f"Failed to connect to Gnani STT API: {exc}"}
            )

    async def _transcribe_long_audio_segmented(
        self,
        rec_id: str,
        audio_bytes: bytes,
        sample_rate: int,
        channels: int,
        bits: int,
        duration_sec: float,
        filename: str,
        language_code: str,
        target_model: str,
        target_format: str,
        keyterms: list,
        topic: Optional[str],
        previous_text: Optional[str]
    ) -> STTResponseData:
        """Splits long audio (> 26s) into 22s segments with 0.8s overlap at energy minima, transcribes each, and merges."""
        bytes_per_sec = sample_rate * channels * (bits // 8)
        bytes_per_sample = channels * (bits // 8)
        target_chunk_bytes = 22 * bytes_per_sec
        overlap_bytes = int(0.8 * bytes_per_sec)

        # Locate raw PCM start
        data_idx = -1
        for i in range(12, min(len(audio_bytes) - 8, 200)):
            if audio_bytes[i:i+4] == b"data":
                data_idx = i
                break
        pcm_start = data_idx + 8 if data_idx != -1 else 44
        raw_pcm = audio_bytes[pcm_start:]

        segment_transcripts: List[str] = []
        all_words: List[WordConfidence] = []
        last_text = previous_text

        offset = 0
        seg_idx = 0
        total_pcm_len = len(raw_pcm)

        while offset < total_pcm_len:
            seg_idx += 1
            chunk_end = min(offset + target_chunk_bytes, total_pcm_len)

            # If not the last chunk, find low-energy point near chunk_end to avoid cutting words
            if chunk_end < total_pcm_len:
                search_start = max(offset + target_chunk_bytes - int(1.5 * bytes_per_sec), offset + int(5.0 * bytes_per_sec))
                search_end = min(offset + target_chunk_bytes + int(1.5 * bytes_per_sec), total_pcm_len)
                best_cut = chunk_end
                min_amp = 32767

                step = max(bytes_per_sample * 8, 16)
                for pos in range(search_start, search_end - 2, step):
                    try:
                        s = abs(struct.unpack("<h", raw_pcm[pos:pos+2])[0])
                        if s < min_amp:
                            min_amp = s
                            best_cut = pos
                            if s < 200:
                                break
                    except Exception:
                        break
                chunk_end = best_cut

            chunk_pcm = raw_pcm[offset:chunk_end]
            if len(chunk_pcm) < bytes_per_sec * 0.3:  # Skip tiny residual < 0.3s
                break

            # Build valid 44-byte WAV for chunk
            chunk_data_len = len(chunk_pcm)
            chunk_riff_len = 36 + chunk_data_len
            header = bytearray(44)
            struct.pack_into("<4sI4s4sIHHIIHH4sI", header, 0,
                             b"RIFF", chunk_riff_len, b"WAVE",
                             b"fmt ", 16, 1, channels, sample_rate,
                             bytes_per_sec, bytes_per_sample, bits,
                             b"data", chunk_data_len)
            chunk_wav = bytes(header) + chunk_pcm
            chunk_dur = chunk_data_len / float(bytes_per_sec)

            sub_res = await self._transcribe_single_segment(
                rec_id=f"{rec_id}_seg{seg_idx}",
                audio_bytes=chunk_wav,
                duration_sec=chunk_dur,
                sample_rate=sample_rate,
                channels=channels,
                filename=f"seg_{seg_idx}.wav",
                language_code=language_code,
                target_model=target_model,
                target_format=target_format,
                keyterms=keyterms,
                topic=topic,
                previous_text=last_text
            )

            if sub_res.transcript:
                segment_transcripts.append(sub_res.transcript)
                last_text = sub_res.transcript
            if sub_res.words:
                all_words.extend(sub_res.words)

            if chunk_end >= total_pcm_len:
                break
            offset = max(offset, chunk_end - overlap_bytes)

        merged_transcript = _merge_transcripts(segment_transcripts)
        return STTResponseData(
            transcript=merged_transcript,
            language_code=language_code,
            model=target_model,
            confidence=0.92,
            words=all_words if all_words else None,
            duration_seconds=duration_sec,
            truncated=False,
            recording_id=rec_id,
            raw_response={"segments_count": seg_idx, "transcripts": segment_transcripts}
        )

    def _parse_response(
        self,
        data: dict,
        language_code: str,
        model: str,
        duration_sec: Optional[float] = None,
        rec_id: Optional[str] = None
    ) -> STTResponseData:
        """Standardize various Gnani STT response formats into STTResponseData."""
        transcript = ""
        confidence = None
        words = []
        truncated = False

        if isinstance(data, dict):
            if "transcript" in data:
                transcript = data["transcript"]
                confidence = data.get("confidence")
            elif "data" in data and isinstance(data["data"], dict):
                transcript = data["data"].get("transcript", "")
                confidence = data["data"].get("confidence")
            elif "result" in data and isinstance(data["result"], list) and len(data["result"]) > 0:
                first = data["result"][0]
                transcript = first.get("transcript", "")
                confidence = first.get("confidence")

            truncated = bool(data.get("truncated", False))

            if "words" in data and isinstance(data["words"], list):
                for w in data["words"]:
                    if isinstance(w, dict):
                        words.append(WordConfidence(
                            word=w.get("word", ""),
                            confidence=w.get("confidence"),
                            start_time=w.get("start_time"),
                            end_time=w.get("end_time")
                        ))

        return STTResponseData(
            transcript=transcript.strip(),
            language_code=language_code,
            model=model,
            confidence=confidence,
            words=words if words else None,
            duration_seconds=duration_sec,
            truncated=truncated,
            recording_id=rec_id,
            raw_response=data
        )
