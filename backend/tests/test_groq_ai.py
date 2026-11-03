import json
import sys
from pathlib import Path
from unittest.mock import AsyncMock, patch
import pytest
from httpx import ASGITransport, AsyncClient

backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.main import app
from app.core.config import Settings, settings
from app.ai.providers.groq_provider import GroqProvider
from app.ai.schemas.ai_schemas import AITutorRequest
from app.core.security import create_mock_jwt

TEST_JWT_SECRET = "test-secret-for-ai-endpoint-security"
TEST_USER_ID = "00000000-0000-0000-0000-000000000001"


@pytest.fixture(autouse=True)
def configure_auth_secret(monkeypatch):
    """Configure secret so test JWTs validate properly."""
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", TEST_JWT_SECRET)
    monkeypatch.setattr(settings, "SUPABASE_URL", "https://test.supabase.co")


def get_auth_headers() -> dict:
    token = create_mock_jwt(user_id=TEST_USER_ID, secret=TEST_JWT_SECRET)
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_groq_unauthorized_rejection():
    """Verify endpoint rejects requests without valid JWT authorization."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/api/v1/ai/tutor",
            json={
                "user_message": "તમે કેમ છો?",
                "native_language": "gu-IN",
                "target_language": "en-US",
                "proficiency_level": "beginner",
                "character_id": "fox",
            },
        )
        assert res.status_code == 401
        assert res.json()["error"]["code"] == "MISSING_AUTHORIZATION"


@pytest.mark.asyncio
async def test_groq_unconfigured_fallback():
    """Verify that when GROQ_API_KEY is not configured, the endpoint returns a clear, safe setup response."""
    transport = ASGITransport(app=app)
    headers = get_auth_headers()
    with patch.object(Settings, "is_groq_configured", return_value=False):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/api/v1/ai/tutor",
                headers=headers,
                json={
                    "user_message": "તમે કેમ છો?",
                    "native_language": "gu-IN",
                    "target_language": "en-US",
                    "proficiency_level": "beginner",
                    "character_id": "fox",
                },
            )
            assert res.status_code == 200
            data = res.json()
            assert data["success"] is True
            assert "Groq API key is not yet configured" in data["data"]["explanation"]
            assert data["data"]["conversation_mode"] == "setup_required"


@pytest.mark.asyncio
async def test_groq_mocked_success_interaction():
    """Verify end-to-end AI Tutor JSON parsing when Groq API responds with valid structured JSON."""
    mock_llm_json = json.dumps({
        "source_text": "તમે કેમ છો?",
        "translated_text": "How are you?",
        "detected_language": "gu",
        "target_language": "en",
        "correction": None,
        "explanation": "This is a polite greeting commonly used in daily conversation.",
        "examples": [
            "How are you doing?",
            "How have you been?"
        ],
        "reply_text": "I am doing wonderful! How can I help your English today?",
        "pronunciation_guide": "How are you? (ha-oo ahr yoo)",
        "vocabulary_breakdown": [
            {"word": "How", "meaning": "કેમ / કેવી રીતે", "part_of_speech": "adverb", "example": "How are you?"}
        ],
        "conversation_mode": "learning"
    })

    transport = ASGITransport(app=app)
    headers = get_auth_headers()
    with patch.object(Settings, "is_groq_configured", return_value=True):
        with patch.object(GroqProvider, "chat_completion", new_callable=AsyncMock) as mock_chat:
            mock_chat.return_value = mock_llm_json

            async with AsyncClient(transport=transport, base_url="http://test") as client:
                res = await client.post(
                    "/api/v1/ai/tutor",
                    headers=headers,
                    json={
                        "user_message": "તમે કેમ છો?",
                        "native_language": "gu-IN",
                        "target_language": "en-US",
                        "proficiency_level": "beginner",
                        "character_id": "fox",
                    },
                )
                assert res.status_code == 200
                data = res.json()
                assert data["success"] is True
                assert data["data"]["translated_text"] == "How are you?"
                assert data["data"]["reply_text"] == "I am doing wonderful! How can I help your English today?"
                assert len(data["data"]["examples"]) == 2
                assert data["data"]["provider"] == "groq"
                assert data["data"]["model"] == "openai/gpt-oss-120b"


@pytest.mark.asyncio
async def test_groq_markdown_codefence_stripping():
    """Verify that if Groq returns JSON enclosed in ```json ... ``` code fences, it parses cleanly."""
    mock_fenced_json = """```json
    {
      "source_text": "I goes to school",
      "translated_text": "હું શાળાએ જાઉં છું",
      "detected_language": "en",
      "target_language": "gu",
      "correction": "I go to school",
      "explanation": "With the subject 'I', use the base form of the verb 'go', not 'goes'.",
      "examples": ["I go to the market", "I walk to school"],
      "reply_text": "Remember: 'I go', but 'he goes'!",
      "pronunciation_guide": "ai goh too skool",
      "vocabulary_breakdown": [],
      "conversation_mode": "learning"
    }
    ```"""

    transport = ASGITransport(app=app)
    headers = get_auth_headers()
    with patch.object(Settings, "is_groq_configured", return_value=True):
        with patch.object(GroqProvider, "chat_completion", new_callable=AsyncMock) as mock_chat:
            mock_chat.return_value = mock_fenced_json

            async with AsyncClient(transport=transport, base_url="http://test") as client:
                res = await client.post(
                    "/api/v1/ai/correct",
                    headers=headers,
                    json={
                        "sentence": "I goes to school",
                        "native_language": "gu-IN",
                        "target_language": "en-US",
                        "character_id": "cat",
                    },
                )
                assert res.status_code == 200
                data = res.json()
                assert data["success"] is True
                assert data["data"]["corrected_sentence"] == "I go to school"
                assert data["data"]["is_correct"] is False
                assert "base form" in data["data"]["explanation"]
