import sys
from pathlib import Path
import pytest
from httpx import ASGITransport, AsyncClient

backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.main import app


@pytest.mark.asyncio
async def test_translation_phrase_match():
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
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["original_text"] == "તમે કેમ છો?"
        assert data["data"]["translated_text"] == "How are you?"
        assert data["data"]["provider"] == "lingoboom_phrase_engine"


@pytest.mark.asyncio
async def test_translation_identity_when_same_language():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/translation/translate",
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
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/translation/translate",
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

