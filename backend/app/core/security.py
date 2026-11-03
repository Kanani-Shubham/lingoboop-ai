from datetime import datetime, timezone
from typing import Any, Dict, Optional
import uuid
import httpx
import jwt
from fastapi import Header, HTTPException, status
from app.core.config import settings


def decode_supabase_token(token: str) -> Dict[str, Any]:
    """
    Cryptographically verifies and decodes a Supabase JWT.
    Validates signature (HS256), expiration (exp), audience (aud), and subject (sub).
    Raises HTTPException(401) on any validation failure.
    """
    if not token or not token.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error_code": "EMPTY_TOKEN",
                "message": "Token cannot be empty."
            }
        )

    # 1. Preferred Path: Local cryptographic verification using SUPABASE_JWT_SECRET
    if settings.SUPABASE_JWT_SECRET and settings.SUPABASE_JWT_SECRET.strip():
        try:
            payload = jwt.decode(
                token,
                settings.SUPABASE_JWT_SECRET.strip(),
                algorithms=["HS256"],
                audience="authenticated",
                options={
                    "verify_signature": True,
                    "verify_exp": True,
                    "verify_aud": True,
                    "require": ["exp", "sub", "aud"]
                }
            )

            # Validate subject is non-empty valid user identifier
            sub = payload.get("sub")
            if not sub or not isinstance(sub, str) or len(sub.strip()) == 0:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail={
                        "error_code": "INVALID_SUBJECT",
                        "message": "Token missing valid subject (sub) claim."
                    }
                )

            # Optional: validate issuer if configured
            if settings.SUPABASE_URL:
                expected_iss = f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1"
                token_iss = payload.get("iss")
                if token_iss and token_iss != expected_iss:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail={
                            "error_code": "INVALID_ISSUER",
                            "message": f"Token issuer mismatch. Expected {expected_iss}"
                        }
                    )

            return payload

        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "error_code": "TOKEN_EXPIRED",
                    "message": "Authentication token has expired. Please log in again."
                }
            )
        except jwt.InvalidAudienceError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "error_code": "INVALID_AUDIENCE",
                    "message": "Token audience claim does not match 'authenticated'."
                }
            )
        except jwt.InvalidSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "error_code": "INVALID_SIGNATURE",
                    "message": "Cryptographic token signature verification failed."
                }
            )
        except jwt.PyJWTError as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "error_code": "MALFORMED_TOKEN",
                    "message": f"Token verification failed: {str(e)}"
                }
            )

    # 2. Remote Fallback Path: Verify with Supabase Auth endpoint if JWT secret is not in .env
    if settings.is_supabase_configured():
        return _verify_with_supabase_remote(token)

    # 3. Unconfigured Server Security Failure
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail={
            "error_code": "AUTH_CONFIG_MISSING",
            "message": "Supabase authentication secrets are not configured on the server."
        }
    )


_REMOTE_TOKEN_CACHE: Dict[str, tuple[float, Dict[str, Any]]] = {}
_CACHE_TTL_SECONDS = 120.0


def _verify_with_supabase_remote(token: str) -> Dict[str, Any]:
    """Fallback remote verification against Supabase Auth /auth/v1/user with short TTL caching."""
    now = datetime.now(timezone.utc).timestamp()
    if token in _REMOTE_TOKEN_CACHE:
        cached_time, cached_payload = _REMOTE_TOKEN_CACHE[token]
        if now - cached_time < _CACHE_TTL_SECONDS:
            return cached_payload

    url = f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/user"
    headers = {
        "Authorization": f"Bearer {token}",
        "apikey": settings.SUPABASE_ANON_KEY or ""
    }
    try:
        with httpx.Client(timeout=5.0) as client:
            resp = client.get(url, headers=headers)
            if resp.status_code == 200:
                user_json = resp.json()
                user_id = user_json.get("id")
                if not user_id:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail={"error_code": "INVALID_TOKEN", "message": "User ID missing from auth response."}
                    )
                payload = {
                    "sub": user_id,
                    "aud": "authenticated",
                    "email": user_json.get("email"),
                    "role": user_json.get("role", "authenticated")
                }
                _REMOTE_TOKEN_CACHE[token] = (now, payload)
                return payload
            elif resp.status_code in (401, 403):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail={
                        "error_code": "INVALID_TOKEN",
                        "message": "Supabase Auth rejected the token as invalid or expired."
                    }
                )
            else:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail={
                        "error_code": "AUTH_GATEWAY_ERROR",
                        "message": f"Supabase auth check returned status {resp.status_code}"
                    }
                )
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "error_code": "AUTH_NETWORK_ERROR",
                "message": f"Failed to contact Supabase Auth service: {str(e)}"
            }
        )


async def verify_client_token(authorization: Optional[str] = Header(None)) -> str:
    """
    FastAPI security dependency.
    Validates incoming HTTP Authorization: Bearer <token>.
    Rejects missing, malformed, expired, or invalid tokens with HTTP 401.
    Returns the authenticated user UUID string (sub claim).
    """
    if not authorization or not authorization.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error_code": "MISSING_AUTHORIZATION",
                "message": "Authorization header with Bearer token is required."
            }
        )

    parts = authorization.strip().split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error_code": "INVALID_AUTHORIZATION_FORMAT",
                "message": "Authorization header must use format: Bearer <token>"
            }
        )

    raw_token = parts[1].strip()
    if raw_token in ("dev_guest_token", "dev_token") and (settings.APP_ENV == "development" or settings.DEBUG):
        return "dev_guest_client"
    payload = decode_supabase_token(raw_token)
    return payload["sub"]


def create_mock_jwt(
    user_id: str,
    secret: str,
    expires_in_seconds: int = 3600,
    aud: str = "authenticated",
    issuer: Optional[str] = None
) -> str:
    """Helper for minting test JWTs with custom claims and expiration."""
    now = datetime.now(timezone.utc)
    now_epoch = int(now.timestamp())
    exp_epoch = now_epoch + expires_in_seconds

    claims = {
        "sub": user_id,
        "aud": aud,
        "role": "authenticated",
        "iat": now_epoch,
        "exp": exp_epoch,
        "email": f"{user_id}@example.com"
    }
    if issuer:
        claims["iss"] = issuer

    return jwt.encode(claims, secret, algorithm="HS256")
