import asyncio
from typing import Optional
from urllib.parse import urlparse
import asyncpg
from app.core.config import settings


class DatabaseManager:
    """
    Manages asynchronous PostgreSQL connections to Supabase.
    Automatically resolves IPv4 connection pooler when direct IPv6 is unroutable.
    """
    def __init__(self):
        self._pool: Optional[asyncpg.Pool] = None

    def get_connection_parameters(self) -> dict:
        """Parse database parameters, supporting direct and IPv4 pooler connection."""
        if not settings.DATABASE_URL:
            raise ValueError("DATABASE_URL is not configured in backend/.env")

        p = urlparse(settings.DATABASE_URL)
        hostname = p.hostname or ""

        # Check if hostname is direct Supabase db (IPv6-only on many networks)
        # Format: db.<project_ref>.supabase.co
        if hostname.startswith("db.") and hostname.endswith(".supabase.co"):
            project_ref = hostname.split(".")[1]
            # Use Supabase IPv4 Pooler for ap-south-1 (Mumbai)
            return {
                "user": f"postgres.{project_ref}",
                "password": p.password,
                "database": p.path.lstrip("/") or "postgres",
                "host": "aws-0-ap-south-1.pooler.supabase.com",
                "port": 5432,
                "ssl": "require",
                "timeout": 10.0
            }

        return {
            "user": p.username,
            "password": p.password,
            "database": p.path.lstrip("/") or "postgres",
            "host": hostname,
            "port": p.port or 5432,
            "ssl": "require",
            "timeout": 10.0
        }

    async def get_connection(self) -> asyncpg.Connection:
        """Create and return a single direct connection."""
        params = self.get_connection_parameters()
        return await asyncpg.connect(**params)

    async def test_connection(self) -> dict:
        """Perform a test query to verify database connectivity without leaking credentials."""
        conn = await self.get_connection()
        try:
            ver = await conn.fetchval("SELECT version();")
            current_db = await conn.fetchval("SELECT current_database();")
            return {
                "connected": True,
                "engine": ver.split(",")[0] if ver else "PostgreSQL",
                "database": current_db
            }
        finally:
            await conn.close()


db_manager = DatabaseManager()

