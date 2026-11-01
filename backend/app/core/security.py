from typing import Optional
from fastapi import Header, HTTPException, status


async def verify_client_token(authorization: Optional[str] = Header(None)) -> str:
    """
    Placeholder client token verification hook for Supabase JWTs.
    In Phase 2, this will decode and verify Supabase Auth tokens.
    For Phase 1 development, permits guest/dev calls while establishing the security layer.
    """
    if not authorization:
        # Development fallback / anonymous guest session
        return "dev_guest_user"
    
    parts = authorization.split(" ")
    if len(parts) == 2 and parts[0].lower() == "bearer":
        return parts[1]  # Return user token/id
    
    return "dev_guest_user"
