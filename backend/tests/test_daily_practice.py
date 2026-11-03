import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.ai.schemas.ai_schemas import DailyPracticeRequest
from app.ai.services.ai_service import AIService
from app.core.config import settings
from tests.test_jwt_security import create_mock_jwt, TEST_JWT_SECRET

@pytest.fixture(autouse=True)
def setup_test_jwt(monkeypatch):
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", TEST_JWT_SECRET)
    monkeypatch.setattr(settings, "SUPABASE_URL", "https://test-project.supabase.co")

@pytest.mark.asyncio
async def test_ai_service_generates_daily_practice():
    svc = AIService()
    req = DailyPracticeRequest(
        native_language="gu-IN",
        target_language="en-US",
        proficiency_level="beginner",
        count=5
    )
    res = await svc.generate_daily_practice(req)
    assert res is not None
    assert len(res.sentences) == 5
    for s in res.sentences:
        assert s.target_sentence
        assert s.native_translation
        assert s.category

@pytest.mark.asyncio
async def test_daily_practice_endpoint_authenticated():
    token = create_mock_jwt(user_id="e5b12345-0000-0000-0000-000000000001", secret=TEST_JWT_SECRET)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/ai/daily-practice",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "native_language": "gu-IN",
                "target_language": "en-US",
                "proficiency_level": "beginner",
                "count": 5
            }
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["success"] is True
        sentences = data["data"]["sentences"]
        assert len(sentences) == 5

@pytest.mark.asyncio
async def test_daily_practice_endpoint_rejects_unauthenticated():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/ai/daily-practice",
            json={
                "native_language": "gu-IN",
                "target_language": "en-US",
                "count": 5
            }
        )
        assert resp.status_code == 401
