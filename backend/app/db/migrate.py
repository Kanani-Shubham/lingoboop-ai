import asyncio
import sys
from pathlib import Path

# Ensure backend root is on sys.path
backend_dir = Path(__file__).resolve().parent.parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.db.connection import db_manager


async def apply_migrations(target_file: str = None):
    print("=" * 60)
    print("LingoBoom Supabase Database Migration Runner")
    print("=" * 60)

    migrations_dir = Path(__file__).resolve().parent.parent.parent.parent / "supabase" / "migrations"
    if not migrations_dir.exists():
        print(f"[ERROR] Migrations directory not found at: {migrations_dir}")
        return False

    if target_file:
        migration_files = [migrations_dir / target_file]
    else:
        migration_files = sorted(migrations_dir.glob("*.sql"))

    if not migration_files:
        print("[NOTICE] No migration files found to apply.")
        return True

    print("[CONNECT] Establishing connection to Supabase PostgreSQL...")
    conn = await db_manager.get_connection()

    try:
        for mf in migration_files:
            if not mf.exists():
                print(f"[ERROR] Migration file does not exist: {mf.name}")
                return False

            print(f"\n[APPLYING] {mf.name} ...")
            sql_content = mf.read_text(encoding="utf-8")
            await conn.execute(sql_content)
            print(f"[SUCCESS] Applied {mf.name}")

        # Verify created tables and RLS
        tables = await conn.fetch("""
            SELECT tablename, rowsecurity
            FROM pg_tables
            WHERE schemaname = 'public'
            ORDER BY tablename;
        """)

        print("\n--- Verified Public Tables & Row Level Security Status ---")
        for row in tables:
            tname = row["tablename"]
            rls_enabled = row["rowsecurity"]
            status_str = "ENABLED (Secure)" if rls_enabled else "DISABLED"
            print(f"  • Table: {tname.ljust(22)} RLS: {status_str}")

        # Verify RLS policies
        policies = await conn.fetch("""
            SELECT tablename, policyname, cmd
            FROM pg_policies
            WHERE schemaname = 'public'
            ORDER BY tablename, policyname;
        """)

        print("\n--- Verified Active RLS Policies ---")
        for p in policies:
            print(f"  [{p['cmd'].ljust(6)}] {p['tablename'].ljust(20)} -> {p['policyname']}")

        # Verify Constraints on messages
        constraints = await conn.fetch("""
            SELECT conname, contype
            FROM pg_constraint
            WHERE conrelid = 'public.messages'::regclass;
        """)
        print("\n--- Verified Constraints on public.messages ---")
        for c in constraints:
            print(f"  Constraint: {c['conname']} (type: {c['contype']})")

        return True

    except Exception as e:
        print(f"[ERROR] Migration failed: {type(e).__name__} - {e}")
        return False
    finally:
        await conn.close()


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "20261101_002_security_hardening.sql"
    success = asyncio.run(apply_migrations(target))
    sys.exit(0 if success else 1)
