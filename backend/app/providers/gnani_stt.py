import httpx
from typing import Optional
from fastapi import HTTPException, status
from app.core.config import settings
from app.providers.base import BaseSTTProvider
from app.schemas.stt import STTResponseData, WordConfidence


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
        model: Optional[str] = None
    ) -> STTResponseData:
        if not audio_bytes or len(audio_bytes) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error_code": "EMPTY_AUDIO", "message": "Provided audio file is empty."}
            )

        headers = self._get_headers()
        target_model = model or settings.GNANI_STT_DEFAULT_MODEL

        # Form-data payload as officially documented for /stt/v3
        files = {
            "audio_file": (filename, audio_bytes, "audio/wav")
        }
        data = {
            "model": target_model,
            "language_code": language_code
        }

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    self.endpoint_url,
                    headers=headers,
                    files=files,
                    data=data
                )

            # Handle HTTP errors safely without leaking headers/keys
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
            return self._parse_response(res_json, language_code, target_model)

        except httpx.TimeoutException:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail={"error_code": "TIMEOUT", "message": f"Gnani STT timed out after {self.timeout}s."}
            )
        except httpx.RequestError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail={"error_code": "NETWORK_ERROR", "message": "Failed to connect to Gnani STT API."}
            )

    def _parse_response(self, data: dict, language_code: str, model: str) -> STTResponseData:
        """Standardize various Gnani STT response formats into STTResponseData."""
        transcript = ""
        confidence = None
        words = []

        if isinstance(data, dict):
            # Format 1: {"transcript": "...", "confidence": 0.94}
            # Format 2: {"data": {"transcript": "...", "confidence": 0.94}}
            # Format 3: {"result": [{"transcript": "...", "confidence": 0.94}]}
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
            raw_response=data
        )
