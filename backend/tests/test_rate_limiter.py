import pytest
from fastapi import HTTPException
from app.core.rate_limiter import InMemoryRateLimiter


def test_rate_limiter_allows_under_limit():
    limiter = InMemoryRateLimiter(max_requests_per_minute=5)
    for _ in range(5):
        limiter.check_rate_limit("user_test_1")


def test_rate_limiter_blocks_over_limit():
    limiter = InMemoryRateLimiter(max_requests_per_minute=3)
    limiter.check_rate_limit("user_test_2")
    limiter.check_rate_limit("user_test_2")
    limiter.check_rate_limit("user_test_2")

    with pytest.raises(HTTPException) as exc_info:
        limiter.check_rate_limit("user_test_2")

    assert exc_info.value.status_code == 429
    assert exc_info.value.detail["error_code"] == "RATE_LIMIT_EXCEEDED"


def test_usage_tracking():
    limiter = InMemoryRateLimiter()
    u1 = limiter.record_audio_usage("user_test_3", 5.5)
    assert u1 == 5.5
    u2 = limiter.record_audio_usage("user_test_3", 4.5)
    assert u2 == 10.0
    assert limiter.get_user_usage("user_test_3") == 10.0

