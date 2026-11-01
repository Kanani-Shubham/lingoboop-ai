import time
from typing import Dict, Tuple
from fastapi import HTTPException, status
from app.core.config import settings


class InMemoryRateLimiter:
    """
    Sliding-window in-memory rate limiter and usage tracker.
    Prevents abuse and quota exhaustion on upstream AI providers.
    """
    def __init__(self, max_requests_per_minute: int = 60):
        self.max_requests = max_requests_per_minute
        # user_id -> list of timestamps
        self._request_history: Dict[str, list] = {}
        # user_id -> total_audio_seconds_used
        self._usage_tracker: Dict[str, float] = {}

    def check_rate_limit(self, client_id: str) -> None:
        now = time.time()
        window_start = now - 60.0

        if client_id not in self._request_history:
            self._request_history[client_id] = []

        # Filter out timestamps older than 60s
        self._request_history[client_id] = [
            t for t in self._request_history[client_id] if t > window_start
        ]

        if len(self._request_history[client_id]) >= self.max_requests:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error_code": "RATE_LIMIT_EXCEEDED",
                    "message": f"Rate limit exceeded ({self.max_requests} req/min). Please slow down."
                }
            )

        self._request_history[client_id].append(now)

    def record_audio_usage(self, client_id: str, duration_seconds: float) -> float:
        """Track cumulative audio duration used for speech quotas."""
        current = self._usage_tracker.get(client_id, 0.0)
        updated = current + duration_seconds
        self._usage_tracker[client_id] = updated
        return updated

    def get_user_usage(self, client_id: str) -> float:
        return self._usage_tracker.get(client_id, 0.0)


# Singleton rate limiter instance
rate_limiter = InMemoryRateLimiter(
    max_requests_per_minute=settings.RATE_LIMIT_REQUESTS_PER_MINUTE
)

