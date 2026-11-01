import pytest
from app.core.config import Settings


def test_settings_default_values():
    s = Settings(GNANI_API_KEY="test_dummy_key_12345678")
    assert s.GNANI_BASE_URL == "https://api.vachana.ai"
    assert s.GNANI_WS_URL == "wss://api.vachana.ai"
    assert s.GNANI_STT_DEFAULT_MODEL == "prisma-v3.0"
    assert s.GNANI_TTS_DEFAULT_MODEL == "timbre-v3.0"
    assert s.is_gnani_configured() is True


def test_settings_secret_masking():
    secret = "gn_live_secret_key_8899"
    s = Settings(GNANI_API_KEY=secret)
    repr_str = repr(s)
    # The raw secret MUST NOT appear in repr
    assert secret not in repr_str
    # Instead, it should be masked
    assert "gn_l...8899" in repr_str
    assert s.masked_gnani_key() == "gn_l...8899"


def test_settings_placeholder_detection():
    s = Settings(GNANI_API_KEY="your_gnani_dashboard_api_key_here")
    assert s.is_gnani_configured() is False

    s2 = Settings(GNANI_API_KEY="")
    assert s2.is_gnani_configured() is False


def test_settings_supabase_fields_and_masking():
    s = Settings(
        GNANI_API_KEY="test_dummy_key_12345678",
        SUPABASE_URL="https://testproject.supabase.co",
        SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy_anon_payload",
        SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy_service_role_secret",
        DATABASE_URL="postgresql://postgres:secretpassword@db.testproject.supabase.co:5432/postgres"
    )
    assert s.is_supabase_configured() is True
    assert s.is_supabase_service_role_configured() is True
    assert s.SUPABASE_URL == "https://testproject.supabase.co"

    # Ensure service role secret and db password NEVER appear in repr
    repr_str = repr(s)
    assert "dummy_service_role_secret" not in repr_str
    assert "secretpassword" not in repr_str
    assert "eyJh...cret" in repr_str

