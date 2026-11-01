import os
from pathlib import Path
from typing import Optional
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Secure Application Configuration.
    Loads from backend/.env or root .env, ensuring secrets are never leaked.
    """
    APP_ENV: str = "development"
    APP_NAME: str = "LingoBoom-Backend"
    DEBUG: bool = False
    HOST: str = "127.0.0.1"
    PORT: int = 8000

    # Gnani.ai / Vachana VoiceOS Configuration
    GNANI_BASE_URL: str = Field(default="https://api.vachana.ai", description="Official Gnani/Vachana HTTPS base URL")
    GNANI_WS_URL: str = Field(default="wss://api.vachana.ai", description="Official Gnani/Vachana WebSocket base URL")
    GNANI_API_KEY: Optional[str] = Field(default=None, description="Dashboard API Key with STT & TTS scopes")

    # STT Settings (Prisma)
    GNANI_STT_PATH: str = Field(default="/stt/v3", description="REST endpoint for Prisma STT")
    GNANI_STT_STREAM_PATH: str = Field(default="/stt/v3/stream", description="Streaming WebSocket endpoint")
    GNANI_STT_DEFAULT_MODEL: str = "prisma-v3.0"

    # TTS Settings (Timbre)
    GNANI_TTS_PATH: str = Field(default="/api/v1/tts/inference", description="REST endpoint for Timbre TTS inference")
    GNANI_TTS_SSE_PATH: str = Field(default="/api/v1/tts/sse", description="Server-Sent Events endpoint")
    GNANI_TTS_WS_PATH: str = Field(default="/api/v1/tts", description="Real-time WebSocket endpoint")
    GNANI_TTS_DEFAULT_MODEL: str = "timbre-v3.0"
    GNANI_TTS_DEFAULT_VOICE: str = "Shivani"

    # Safety, Timeouts & Limits
    GNANI_REQUEST_TIMEOUT_SECONDS: float = 30.0
    RATE_LIMIT_REQUESTS_PER_MINUTE: int = 60

    # Supabase Configuration
    SUPABASE_URL: Optional[str] = Field(default=None, description="Supabase project URL")
    SUPABASE_ANON_KEY: Optional[str] = Field(default=None, description="Supabase public anon key")
    SUPABASE_SERVICE_ROLE_KEY: Optional[str] = Field(default=None, description="Supabase backend-only service role key")
    DATABASE_URL: Optional[str] = Field(default=None, description="Direct PostgreSQL database connection URL")

    # Pydantic Settings Config: check backend/.env first, then root .env
    model_config = SettingsConfigDict(
        env_file=(
            Path(__file__).resolve().parent.parent.parent / ".env",
            Path(__file__).resolve().parent.parent.parent.parent / ".env"
        ),
        env_file_encoding="utf-8",
        extra="ignore"
    )

    @field_validator("GNANI_BASE_URL")
    @classmethod
    def validate_base_url(cls, v: str) -> str:
        v = v.rstrip("/")
        if not v.startswith("http://") and not v.startswith("https://"):
            raise ValueError("GNANI_BASE_URL must start with http:// or https://")
        return v

    @field_validator("GNANI_WS_URL")
    @classmethod
    def validate_ws_url(cls, v: str) -> str:
        v = v.rstrip("/")
        if not v.startswith("ws://") and not v.startswith("wss://"):
            raise ValueError("GNANI_WS_URL must start with ws:// or wss://")
        return v

    def is_gnani_configured(self) -> bool:
        """Check whether a non-empty, non-placeholder API key is configured."""
        if not self.GNANI_API_KEY:
            return False
        val = self.GNANI_API_KEY.strip()
        return len(val) > 0 and val != "your_gnani_dashboard_api_key_here" and val != "your_gnani_api_key_here"

    def masked_gnani_key(self) -> str:
        """Returns a safely masked key string (e.g. 'gn_...abc') without exposing the secret."""
        if not self.is_gnani_configured():
            return "UNCONFIGURED"
        raw = self.GNANI_API_KEY.strip()
        if len(raw) <= 8:
            return "***"
        return f"{raw[:4]}...{raw[-4:]}"

    def is_supabase_configured(self) -> bool:
        """Check whether Supabase URL and keys are configured."""
        if not self.SUPABASE_URL or not self.SUPABASE_ANON_KEY:
            return False
        return not self.SUPABASE_URL.startswith("https://your-project-id") and not self.SUPABASE_ANON_KEY.startswith("your_")

    def is_supabase_service_role_configured(self) -> bool:
        """Check whether backend service role key is configured."""
        if not self.SUPABASE_SERVICE_ROLE_KEY:
            return False
        return not self.SUPABASE_SERVICE_ROLE_KEY.startswith("your_")

    def masked_supabase_service_role(self) -> str:
        if not self.is_supabase_service_role_configured():
            return "UNCONFIGURED"
        raw = self.SUPABASE_SERVICE_ROLE_KEY.strip()
        if len(raw) <= 8:
            return "***"
        return f"{raw[:4]}...{raw[-4:]}"

    def __repr__(self) -> str:
        """Prevent secrets from leaking when settings object is printed or logged."""
        return (
            f"Settings(APP_ENV='{self.APP_ENV}', "
            f"GNANI_BASE_URL='{self.GNANI_BASE_URL}', "
            f"GNANI_API_KEY='{self.masked_gnani_key()}', "
            f"SUPABASE_URL='{self.SUPABASE_URL}', "
            f"SUPABASE_SERVICE_ROLE='{self.masked_supabase_service_role()}', "
            f"STT_MODEL='{self.GNANI_STT_DEFAULT_MODEL}', "
            f"TTS_MODEL='{self.GNANI_TTS_DEFAULT_MODEL}')"
        )


# Singleton settings instance
settings = Settings()
