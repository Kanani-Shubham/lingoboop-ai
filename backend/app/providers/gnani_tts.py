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

            # Gnani /api/v1/tts/inference returns raw binary audio (WAV/MP3) or JSON with audio base64
            content_type = response.headers.get("content-type", "audio/wav")
            audio_b64 = ""

            if "application/json" in content_type:
                data = response.json()
                if "audio" in data:
                    audio_b64 = data["audio"]
                elif "audio_content" in data:
                    audio_b64 = data["audio_content"]
                elif "data" in data and isinstance(data["data"], dict):
                    audio_b64 = data["data"].get("audio", "")
            else:
                # Raw binary audio returned
                audio_b64 = base64.b64encode(response.content).decode("utf-8")

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
