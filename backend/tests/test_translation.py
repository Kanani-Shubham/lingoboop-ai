import sys
from pathlib import Path
import pytest
from httpx import ASGITransport, AsyncClient

backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.main import app
from app.core.config import settings
from app.core.security import create_mock_jwt

TEST_JWT_SECRET = "test-secret-for-translation-endpoint"
TEST_USER_ID = "00000000-0000-0000-0000-000000000002"


@pytest.fixture(autouse=True)
def configure_auth_secret(monkeypatch):
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", TEST_JWT_SECRET)
    monkeypatch.setattr(settings, "SUPABASE_URL", "https://test.supabase.co")


def get_auth_headers() -> dict:
    token = create_mock_jwt(user_id=TEST_USER_ID, secret=TEST_JWT_SECRET)
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_translation_unauthorized_rejection():
    """Verify translation endpoint rejects unauthenticated requests with 401."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/translation/translate",
            json={
                "text": "તમે કેમ છો?",
                "source_language": "gu-IN",
                "target_language": "en-IN"
            }
        )
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "MISSING_AUTHORIZATION"


@pytest.mark.asyncio
async def test_translation_phrase_match():
    transport = ASGITransport(app=app)
    headers = get_auth_headers()
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/translation/translate",
            headers=headers,
            json={
                "text": "તમે કેમ છો?",
                "source_language": "gu-IN",
                "target_language": "en-IN"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["original_text"] == "તમે કેમ છો?"
        assert data["data"]["translated_text"] == "How are you?"
        assert data["data"]["provider"] == "lingoboom_phrase_engine"


@pytest.mark.asyncio
async def test_translation_identity_when_same_language():
    transport = ASGITransport(app=app)
    headers = get_auth_headers()
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/translation/translate",
            headers=headers,
            json={
                "text": "Hello world",
                "source_language": "en-US",
                "target_language": "en-IN"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["translated_text"] == "Hello world"
        assert data["data"]["provider"] == "identity"


@pytest.mark.asyncio
async def test_translation_fallback():
    transport = ASGITransport(app=app)
    headers = get_auth_headers()
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/translation/translate",
            headers=headers,
            json={
                "text": "તમે સારું કામ કર્યું",
                "source_language": "gu-IN",
                "target_language": "en-IN"
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "you" in data["data"]["translated_text"]
