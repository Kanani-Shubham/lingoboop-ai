import json
from typing import Any, Dict, List, Optional
import httpx
from fastapi import HTTPException, status
from app.core.config import settings
from app.ai.providers.base_provider import BaseLLMProvider


class GroqProvider(BaseLLMProvider):
    """
    Official Groq Cloud Provider Implementation.
    Uses official endpoint: POST https://api.groq.com/openai/v1/chat/completions
    Primary Model: openai/gpt-oss-120b (Configured via GROQ_MODEL in backend/.env)
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        model: Optional[str] = None,
    ):
        self.api_key = api_key or settings.GROQ_API_KEY
        self.base_url = (base_url or settings.GROQ_BASE_URL).rstrip("/")
        self.endpoint_url = f"{self.base_url}/chat/completions"
        self.default_model = model or settings.GROQ_MODEL
        self.timeout = settings.GROQ_TIMEOUT_SECONDS

    def _get_headers(self) -> Dict[str, str]:
        if not self.api_key or not self.api_key.strip() or self.api_key.strip().startswith("your_"):
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail={
                    "error_code": "PROVIDER_KEY_MISSING",
                    "message": "Groq API key is not configured. Please set GROQ_API_KEY in backend/.env.",
                },
            )
        return {
            "Authorization": f"Bearer {self.api_key.strip()}",
            "Content-Type": "application/json",
        }

    async def chat_completion(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str] = None,
        temperature: float = 0.3,
        max_tokens: int = 1024,
        response_format: Optional[Dict[str, str]] = None,
    ) -> str:
        headers = self._get_headers()
        target_model = model or self.default_model

        payload: Dict[str, Any] = {
            "model": target_model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }

        if response_format:
            payload["response_format"] = response_format

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    self.endpoint_url,
                    headers=headers,
                    json=payload,
                )

            if response.status_code == 401 or response.status_code == 403:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail={
                        "error_code": "AUTHENTICATION_FAILED",
                        "message": "Invalid Groq API key or unauthorized access.",
                    },
                )
            elif response.status_code == 429:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail={
                        "error_code": "UPSTREAM_RATE_LIMITED",
                        "message": "Groq rate limit reached. Please wait a moment before sending another message.",
                    },
                )
            elif response.status_code >= 400:
                err_detail = "Groq provider error"
                try:
                    err_json = response.json()
                    err_detail = err_json.get("error", {}).get("message") or err_json.get("message") or err_detail
                except Exception:
                    err_detail = response.text[:200]

                raise HTTPException(
                    status_code=response.status_code,
                    detail={"error_code": "UPSTREAM_ERROR", "message": err_detail},
                )

            res_json = response.json()
            choices = res_json.get("choices", [])
            if not choices:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail={"error_code": "EMPTY_RESPONSE", "message": "Groq returned an empty choice set."},
                )

            message_obj = choices[0].get("message", {})
            content = message_obj.get("content", "")
            return content

        except httpx.TimeoutException:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail={"error_code": "TIMEOUT", "message": f"Groq API timed out after {self.timeout}s."},
            )
        except httpx.RequestError:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail={"error_code": "NETWORK_ERROR", "message": "Failed to connect to Groq Cloud API."},
            )

