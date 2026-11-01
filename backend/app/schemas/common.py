from typing import Any, Optional
from pydantic import BaseModel


class APIResponse(BaseModel):
    success: bool
    data: Optional[Any] = None
    error: Optional[dict] = None
