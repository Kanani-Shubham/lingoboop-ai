import base64
from collections import OrderedDict
from typing import Dict, Optional
import httpx
from fastapi import HTTPException, status
from app.core.config import settings
from app.providers.base import BaseTTSProvider
from app.schemas.tts import TTSRequest, TTSResponseMetadata

# In-memory LRU cache for synthesized prompt phrases (max 128 entries)
_TTS_CACHE: "OrderedDict[str, TTSResponseMetadata]" = OrderedDict()
_MAX_CACHE_SIZE = 128
_SHARED_CLIENT: Optional[httpx.AsyncClient] = None


def normalize_pcm_16bit(pcm_bytes: bytes, target_peak_dbfs: float = -1.0, target_rms_dbfs: float = -15.0) -> bytes:
    """
    Safely normalizes 16-bit linear PCM audio for high-clarity speech playback on mobile devices.
    Applies calculated gain targeting ~ -15.0 dBFS RMS with a -1.0 dBFS ceiling and smooth soft-knee limiter.
    Guarantees zero clipping and avoids excessive floor noise amplification.
    """
    import math
    import struct

    num_samples = len(pcm_bytes) // 2
    if num_samples == 0:
        return pcm_bytes

    try:
        samples = list(struct.unpack(f"<{num_samples}h", pcm_bytes))
    except Exception:
        return pcm_bytes

    peak = max(abs(s) for s in samples)
    if peak == 0:
        return pcm_bytes

    peak_dbfs = 20 * math.log10(peak / 32768.0)
    sum_sq = sum(float(s) * float(s) for s in samples)
    rms = math.sqrt(sum_sq / num_samples)
    rms_dbfs = 20 * math.log10(rms / 32768.0) if rms > 0 else -999.0

    # Guard: if already loud enough (peak >= -1.5 dBFS or RMS >= -17 dBFS), avoid double-normalizing
    if peak_dbfs >= -1.5 or rms_dbfs >= -17.0:
        return pcm_bytes

    target_rms_amp = 32768.0 * (10 ** (target_rms_dbfs / 20.0))  # ~ 5836 for -15 dBFS
    target_peak_amp = 32768.0 * (10 ** (target_peak_dbfs / 20.0))  # ~ 29205 for -1.0 dBFS

    desired_rms_gain = (target_rms_amp / rms) if rms > 0 else 1.0
    max_linear_gain = target_peak_amp / peak
    gain = min(desired_rms_gain, max_linear_gain * 1.5)
    gain = max(1.0, min(gain, 3.5))  # Safe gain cap between 1.0x and 3.5x (+10.8 dB)

    threshold = 26000.0  # ~ -2.0 dBFS
    ceiling = 31000.0    # ~ -0.48 dBFS
    ratio = ceiling - threshold

    out_samples = []
    for s in samples:
        val = s * gain
        abs_val = abs(val)
        if abs_val <= threshold:
            out_val = val
        else:
            over = abs_val - threshold
            compressed_over = ratio * math.tanh(over / ratio)
            limited = threshold + compressed_over
            out_val = math.copysign(limited, val)

        int_val = int(round(out_val))
        if int_val > 32767:
            int_val = 32767
        elif int_val < -32768:
            int_val = -32768
        out_samples.append(int_val)

    return struct.pack(f"<{num_samples}h", *out_samples)


def _wrap_pcm_as_wav(pcm_bytes: bytes, sample_rate: int = 16000, num_channels: int = 1, bits_per_sample: int = 16) -> bytes:
    """Wraps raw linear PCM audio bytes into a standard 44-byte WAV (RIFF/WAVE) container,
    repairs Gnani's 0xFFFFFFFF streaming placeholder size fields, and normalizes audio loudness
    so speech sounds loud, balanced, and clear on physical mobile device speakers."""
    import struct
    if pcm_bytes.startswith(b"RIFF"):
        if len(pcm_bytes) >= 44:
            data_idx = pcm_bytes.find(b"data")
            if data_idx != -1 and data_idx + 8 <= len(pcm_bytes):
                actual_data_size = len(pcm_bytes) - (data_idx + 8)
                actual_riff_size = len(pcm_bytes) - 8
                existing_riff_size = struct.unpack("<I", pcm_bytes[4:8])[0]
                existing_data_size = struct.unpack("<I", pcm_bytes[data_idx+4:data_idx+8])[0]

                # Extract and normalize the PCM data
                raw_pcm = pcm_bytes[data_idx + 8 : data_idx + 8 + actual_data_size]
                normalized_pcm = normalize_pcm_16bit(raw_pcm)

                ba = bytearray(pcm_bytes[:data_idx + 8])
                if existing_riff_size in (0, 0xFFFFFFFF) or existing_data_size in (0, 0xFFFFFFFF) or existing_data_size > len(pcm_bytes):
                    struct.pack_into("<I", ba, 4, actual_riff_size)
                    struct.pack_into("<I", ba, data_idx + 4, actual_data_size)
                return bytes(ba) + normalized_pcm
        return pcm_bytes

    # If raw PCM was provided without RIFF header:
    normalized_pcm = normalize_pcm_16bit(pcm_bytes)
    byte_rate = sample_rate * num_channels * (bits_per_sample // 8)
    block_align = num_channels * (bits_per_sample // 8)
    data_size = len(normalized_pcm)
    riff_size = 36 + data_size

    header = bytearray()
    header.extend(b"RIFF")
    header.extend(struct.pack("<I", riff_size))
    header.extend(b"WAVE")
    header.extend(b"fmt ")
    header.extend(struct.pack("<I", 16))  # Subchunk1Size (16 for PCM)
    header.extend(struct.pack("<H", 1))   # AudioFormat (1 for PCM)
    header.extend(struct.pack("<H", num_channels))
    header.extend(struct.pack("<I", sample_rate))
    header.extend(struct.pack("<I", byte_rate))
    header.extend(struct.pack("<H", block_align))
    header.extend(struct.pack("<H", bits_per_sample))
    header.extend(b"data")
    header.extend(struct.pack("<I", data_size))
    return bytes(header) + pcm_bytes


def _get_shared_client(timeout: float) -> httpx.AsyncClient:
    global _SHARED_CLIENT
    if _SHARED_CLIENT is None or _SHARED_CLIENT.is_closed:
        _SHARED_CLIENT = httpx.AsyncClient(
            timeout=timeout,
            limits=httpx.Limits(max_keepalive_connections=20, max_connections=50)
        )
    return _SHARED_CLIENT


class GnaniTTSProvider(BaseTTSProvider):
    """
    Official Gnani Timbre TTS Provider Implementation.
    Uses official endpoint: POST https://api.vachana.ai/api/v1/tts/inference
    Authentication Header: X-API-Key-ID: <GNANI_API_KEY>
    Includes connection pooling and LRU phrase caching.
    """
    def __init__(self, api_key: Optional[str] = None, base_url: Optional[str] = None):
        self.api_key = api_key or settings.GNANI_API_KEY
        self.base_url = (base_url or settings.GNANI_BASE_URL).rstrip("/")
        self.endpoint_url = f"{self.base_url}{settings.GNANI_TTS_PATH}"
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
            "X-API-Key-ID": self.api_key.strip(),
            "Content-Type": "application/json"
        }

    async def synthesize(self, request: TTSRequest) -> TTSResponseMetadata:
        target_model = request.model or settings.GNANI_TTS_DEFAULT_MODEL

        # Check in-memory LRU cache first for sub-millisecond repeated playback
        cache_key = f"{request.text.strip().lower()}:{request.language}:{request.voice}:{request.speed}:{target_model}"
        if cache_key in _TTS_CACHE:
            cached = _TTS_CACHE[cache_key]
            _TTS_CACHE.move_to_end(cache_key)
            return cached

        headers = self._get_headers()

        payload = {
            "text": request.text,
            "voice": request.voice,
            "model": target_model,
            "language": request.language,
            "speed": request.speed,
            "audio_config": request.audio_config.model_dump() if request.audio_config else {
                "sample_rate": 16000,
                "num_channels": 1,
                "sample_width": 2,
                "encoding": "linear_pcm",
                "container": "wav"
            }
        }

        try:
            client = _get_shared_client(self.timeout)
            response = await client.post(
                self.endpoint_url,
                headers=headers,
                json=payload
            )

            if response.status_code == 401 or response.status_code == 403:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail={
                        "error_code": "AUTHENTICATION_FAILED",
                        "message": "Invalid Gnani API key or insufficient permissions for TTS."
                    }
                )
            elif response.status_code == 429:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail={
                        "error_code": "UPSTREAM_RATE_LIMITED",
                        "message": "Gnani TTS rate limit reached. Please wait before retrying."
                    }
                )
            elif response.status_code >= 400:
                err_detail = "Upstream TTS provider error"
                try:
                    err_json = response.json()
                    err_detail = err_json.get("message") or err_json.get("detail") or err_detail
                except Exception:
                    err_detail = response.text[:200]
                raise HTTPException(
                    status_code=response.status_code,
                    detail={"error_code": "UPSTREAM_ERROR", "message": err_detail}
                )

            # Gnani /api/v1/tts/inference returns raw binary audio (linear PCM) or JSON with audio base64
            content_type = response.headers.get("content-type", "audio/wav")
            audio_b64 = ""

            if "application/json" in content_type:
                data = response.json()
                raw_b64 = data.get("audio") or data.get("audio_content") or (data.get("data", {}) if isinstance(data.get("data"), dict) else {}).get("audio", "")
                if raw_b64:
                    raw_bytes = base64.b64decode(raw_b64)
                    wav_bytes = _wrap_pcm_as_wav(raw_bytes, sample_rate=16000, num_channels=1, bits_per_sample=16)
                    audio_b64 = base64.b64encode(wav_bytes).decode("utf-8")
            else:
                # Raw binary audio returned - wrap linear PCM into standard WAV container
                wav_bytes = _wrap_pcm_as_wav(response.content, sample_rate=16000, num_channels=1, bits_per_sample=16)
                audio_b64 = base64.b64encode(wav_bytes).decode("utf-8")

            res_metadata = TTSResponseMetadata(
                audio_base64=audio_b64,
                content_type=content_type if "audio" in content_type else "audio/wav",
                character_count=len(request.text),
                voice=request.voice,
                model=payload["model"],
                language=request.language
            )

            # Store in LRU cache
            _TTS_CACHE[cache_key] = res_metadata
            if len(_TTS_CACHE) > _MAX_CACHE_SIZE:
                _TTS_CACHE.popitem(last=False)

            return res_metadata

        except httpx.TimeoutException:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail={"error_code": "TIMEOUT", "message": f"Gnani TTS timed out after {self.timeout}s."}
            )
        except httpx.RequestError:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail={"error_code": "NETWORK_ERROR", "message": "Failed to connect to Gnani TTS API."}
            )
