import uuid
from datetime import datetime, timezone
import pytest
import jwt
from fastapi import HTTPException
from app.core.config import settings
from app.core.security import (
    create_mock_jwt,
    decode_supabase_token,
    verify_client_token,
)


TEST_JWT_SECRET = "super-secret-supabase-jwt-key-for-test-32chars"
USER_A_ID = str(uuid.uuid4())
USER_B_ID = str(uuid.uuid4())


@pytest.fixture(autouse=True)
def setup_test_jwt_secret(monkeypatch):
    """Ensure settings has test JWT secret configured for unit testing."""
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", TEST_JWT_SECRET)
    monkeypatch.setattr(settings, "SUPABASE_URL", "https://test-project.supabase.co")


@pytest.mark.asyncio
async def test_verify_client_token_valid():
    """Valid token decodes and extracts user UUID cleanly."""
    token = create_mock_jwt(
        user_id=USER_A_ID,
        secret=TEST_JWT_SECRET,
        expires_in_seconds=3600,
        aud="authenticated",
    )
    auth_header = f"Bearer {token}"
    verified_user = await verify_client_token(auth_header)
    assert verified_user == USER_A_ID


@pytest.mark.asyncio
async def test_verify_client_token_missing():
    """Missing Authorization header raises 401 MISSING_AUTHORIZATION."""
    with pytest.raises(HTTPException) as exc:
        await verify_client_token(None)
    assert exc.value.status_code == 401
    assert exc.value.detail["error_code"] == "MISSING_AUTHORIZATION"


@pytest.mark.asyncio
async def test_verify_client_token_malformed_header():
    """Malformed header (e.g. Basic instead of Bearer) raises 401."""
    with pytest.raises(HTTPException) as exc:
        await verify_client_token("Basic dXNlcjpwYXNz")
    assert exc.value.status_code == 401
    assert exc.value.detail["error_code"] == "INVALID_AUTHORIZATION_FORMAT"


@pytest.mark.asyncio
async def test_verify_client_token_expired():
    """Expired token raises 401 TOKEN_EXPIRED."""
    expired_token = create_mock_jwt(
        user_id=USER_A_ID,
        secret=TEST_JWT_SECRET,
        expires_in_seconds=-60,  # Expired 1 minute ago
    )
    with pytest.raises(HTTPException) as exc:
        await verify_client_token(f"Bearer {expired_token}")
    assert exc.value.status_code == 401
    assert exc.value.detail["error_code"] == "TOKEN_EXPIRED"


@pytest.mark.asyncio
async def test_verify_client_token_invalid_signature():
    """Token signed with wrong key raises 401 INVALID_SIGNATURE."""
    forged_token = create_mock_jwt(
        user_id=USER_A_ID,
        secret="attacker-wrong-secret-key-32chars",
    )
    with pytest.raises(HTTPException) as exc:
        await verify_client_token(f"Bearer {forged_token}")
    assert exc.value.status_code == 401
    assert exc.value.detail["error_code"] == "INVALID_SIGNATURE"


@pytest.mark.asyncio
async def test_verify_client_token_wrong_audience():
    """Token with invalid audience raises 401 INVALID_AUDIENCE."""
    wrong_aud_token = create_mock_jwt(
        user_id=USER_A_ID,
        secret=TEST_JWT_SECRET,
        aud="anon_public_only",
    )
    with pytest.raises(HTTPException) as exc:
        await verify_client_token(f"Bearer {wrong_aud_token}")
    assert exc.value.status_code == 401
    assert exc.value.detail["error_code"] == "INVALID_AUDIENCE"


@pytest.mark.asyncio
async def test_verify_client_token_missing_sub_claim():
    """Token missing subject claim raises 401."""
    now_epoch = int(datetime.now(timezone.utc).timestamp())
    claims = {
        "aud": "authenticated",
        "role": "authenticated",
        "exp": now_epoch + 3600,
    }
    token_no_sub = jwt.encode(claims, TEST_JWT_SECRET, algorithm="HS256")
    with pytest.raises(HTTPException) as exc:
        await verify_client_token(f"Bearer {token_no_sub}")
    assert exc.value.status_code == 401
    assert exc.value.detail["error_code"] in ("MALFORMED_TOKEN", "INVALID_SUBJECT")


@pytest.mark.asyncio
async def test_cross_user_isolation():
    """User A's token cannot authenticate as User B."""
    token_a = create_mock_jwt(user_id=USER_A_ID, secret=TEST_JWT_SECRET)
    token_b = create_mock_jwt(user_id=USER_B_ID, secret=TEST_JWT_SECRET)

    verified_a = await verify_client_token(f"Bearer {token_a}")
    verified_b = await verify_client_token(f"Bearer {token_b}")

    assert verified_a == USER_A_ID
    assert verified_b == USER_B_ID
    assert verified_a != USER_B_ID
    assert verified_b != USER_A_ID
