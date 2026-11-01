from fastapi import FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.routers import health, stt, tts

app = FastAPI(
    title=settings.APP_NAME,
    description="LingoBoom Production Backend: Gnani AI Speech Gateway & Entitlements Service",
    version="1.0.0",
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
)

# CORS configuration for mobile clients & web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global safe exception handler: prevents secret or traceback leaks
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    detail = exc.detail
    if isinstance(detail, dict):
        code = detail.get("error_code", "HTTP_ERROR")
        msg = detail.get("message", "An error occurred")
    else:
        code = "HTTP_ERROR"
        msg = str(detail)

    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": {
                "code": code,
                "message": msg,
                "status_code": exc.status_code
            }
        }
    )

@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # Log securely without printing secrets
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": "An unexpected server error occurred. Please try again later.",
                "status_code": 500
            }
        }
    )

# Include API Routers
app.include_router(health.router)
app.include_router(stt.router)
app.include_router(tts.router)
