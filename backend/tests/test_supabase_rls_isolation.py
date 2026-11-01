import sys
from pathlib import Path
import uuid
import pytest
import asyncpg

# Add backend directory to sys.path so app modules import cleanly standalone and in IDE
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.db.connection import db_manager


@pytest.mark.asyncio
async def test_supabase_tables_exist_and_rls_enabled():
    """Verify all 9 core tables exist in Supabase and have Row Level Security enabled."""
    conn = await db_manager.get_connection()
    try:
        rows = await conn.fetch("""
            SELECT tablename, rowsecurity
            FROM pg_tables
            WHERE schemaname = 'public'
            AND tablename IN (
                'profiles', 'user_preferences', 'user_languages',
                'conversations', 'messages', 'learning_progress',
                'achievements', 'usage_records', 'subscriptions'
            );
        """)

        found_tables = {r["tablename"]: r["rowsecurity"] for r in rows}
        expected_tables = [
            "profiles", "user_preferences", "user_languages",
            "conversations", "messages", "learning_progress",
            "achievements", "usage_records", "subscriptions"
        ]

        for t in expected_tables:
            assert t in found_tables, f"Table {t} missing from database"
            assert found_tables[t] is True, f"RLS is NOT enabled on table {t}"
    finally:
        await conn.close()


@pytest.mark.asyncio
async def test_rls_user_isolation_conversations():
    """
    Verify cross-user isolation:
    User A cannot read User B's conversations, and anonymous users see nothing.
    """
    user_a = str(uuid.uuid4())
    user_b = str(uuid.uuid4())

    conn = await db_manager.get_connection()
    try:
        async with conn.transaction():
            # Create auth users
            await conn.execute("""
                INSERT INTO auth.users (id, email)
                VALUES ($1, 'usera@example.com'), ($2, 'userb@example.com')
                ON CONFLICT (id) DO NOTHING;
            """, uuid.UUID(user_a), uuid.UUID(user_b))

            # Simulate User A session
            await conn.execute("SET LOCAL ROLE authenticated;")
            await conn.execute(f"SET LOCAL \"request.jwt.claim.sub\" = '{user_a}';")

            # User A inserts a conversation
            conv_id = await conn.fetchval("""
                INSERT INTO public.conversations (user_id, character_id, title)
                VALUES ($1, 'maru', 'User A Secret Conversation')
                RETURNING id;
            """, uuid.UUID(user_a))

            # User A can read their own conversation
            user_a_rows = await conn.fetch("SELECT * FROM public.conversations WHERE id = $1;", conv_id)
            assert len(user_a_rows) == 1
            assert user_a_rows[0]["title"] == "User A Secret Conversation"

            # Switch context to User B
            await conn.execute(f"SET LOCAL \"request.jwt.claim.sub\" = '{user_b}';")

            # User B MUST NOT be able to see User A's conversation
            user_b_rows = await conn.fetch("SELECT * FROM public.conversations WHERE id = $1;", conv_id)
            assert len(user_b_rows) == 0, "SECURITY BREACH: User B could read User A's conversation!"

            # Anonymous role sees nothing
            await conn.execute("SET LOCAL ROLE anon;")
            anon_rows = await conn.fetch("SELECT * FROM public.conversations WHERE id = $1;", conv_id)
            assert len(anon_rows) == 0, "SECURITY BREACH: Anonymous user could read conversation!"

            raise asyncpg.exceptions.TransactionRollbackError("Rollback cleanly")
    except asyncpg.exceptions.TransactionRollbackError:
        pass
    finally:
        await conn.close()


@pytest.mark.asyncio
async def test_message_ownership_violation_blocked_by_composite_fk():
    """
    Verify Message & Conversation Ownership Integrity:
    A message cannot be inserted into another user's conversation.
    Enforced by composite foreign key fk_messages_conversation_user (conversation_id, user_id).
    """
    user_a = str(uuid.uuid4())
    user_b = str(uuid.uuid4())

    conn = await db_manager.get_connection()
    try:
        async with conn.transaction():
            # Setup users
            await conn.execute("""
                INSERT INTO auth.users (id, email)
                VALUES ($1, 'usera_conv@example.com'), ($2, 'userb_conv@example.com')
                ON CONFLICT (id) DO NOTHING;
            """, uuid.UUID(user_a), uuid.UUID(user_b))

            # User A creates a conversation
            await conn.execute("SET LOCAL ROLE authenticated;")
            await conn.execute(f"SET LOCAL \"request.jwt.claim.sub\" = '{user_a}';")
            conv_id = await conn.fetchval("""
                INSERT INTO public.conversations (user_id, character_id, title)
                VALUES ($1, 'maru', 'User A Private Session')
                RETURNING id;
            """, uuid.UUID(user_a))

            # Case 1: User B tries to insert a message with their own user_id into User A's conversation
            # This violates the composite FK (conversations does not contain (conv_id, user_b))
            await conn.execute(f"SET LOCAL \"request.jwt.claim.sub\" = '{user_b}';")
            with pytest.raises(asyncpg.exceptions.ForeignKeyViolationError):
                async with conn.transaction():
                    await conn.execute("""
                        INSERT INTO public.messages (conversation_id, user_id, sender_role, source_text)
                        VALUES ($1, $2, 'user', 'Injected message into User A conversation');
                    """, conv_id, uuid.UUID(user_b))

            # Case 2: User B tries to spoof user_id = user_a to bypass the composite FK
            # This is strictly blocked by RLS WITH CHECK (auth.uid() = user_id)
            with pytest.raises(asyncpg.exceptions.InsufficientPrivilegeError):
                async with conn.transaction():
                    await conn.execute("""
                        INSERT INTO public.messages (conversation_id, user_id, sender_role, source_text)
                        VALUES ($1, $2, 'user', 'Spoofed message');
                    """, conv_id, uuid.UUID(user_a))

            raise asyncpg.exceptions.TransactionRollbackError("Rollback cleanly")
    except asyncpg.exceptions.TransactionRollbackError:
        pass
    finally:
        await conn.close()


@pytest.mark.asyncio
async def test_achievement_self_insertion_blocked_for_client():
    """
    Verify that authenticated clients CANNOT self-award achievements.
    Direct INSERT/UPDATE must be rejected. Only trusted service_role can award achievements.
    """
    user_test = str(uuid.uuid4())
    conn = await db_manager.get_connection()
    try:
        async with conn.transaction():
            await conn.execute("""
                INSERT INTO auth.users (id, email)
                VALUES ($1, 'user_achieve@example.com')
                ON CONFLICT (id) DO NOTHING;
            """, uuid.UUID(user_test))

            # Authenticated client role
            await conn.execute("SET LOCAL ROLE authenticated;")
            await conn.execute(f"SET LOCAL \"request.jwt.claim.sub\" = '{user_test}';")

            # Client attempts to insert a badge for themselves
            with pytest.raises(asyncpg.exceptions.InsufficientPrivilegeError):
                async with conn.transaction():
                    await conn.execute("""
                        INSERT INTO public.achievements (user_id, achievement_code)
                        VALUES ($1, 'fake_super_badge');
                    """, uuid.UUID(user_test))

            # But service_role (backend superuser context) CAN award achievements
            await conn.execute("SET LOCAL ROLE service_role;")
            await conn.execute("""
                INSERT INTO public.achievements (user_id, achievement_code)
                VALUES ($1, 'legitimate_earned_badge');
            """, uuid.UUID(user_test))

            # Client CAN view their legitimate badge
            await conn.execute("SET LOCAL ROLE authenticated;")
            await conn.execute(f"SET LOCAL \"request.jwt.claim.sub\" = '{user_test}';")
            earned = await conn.fetch("SELECT * FROM public.achievements WHERE user_id = $1;", uuid.UUID(user_test))
            assert len(earned) == 1
            assert earned[0]["achievement_code"] == "legitimate_earned_badge"

            raise asyncpg.exceptions.TransactionRollbackError("Rollback cleanly")
    except asyncpg.exceptions.TransactionRollbackError:
        pass
    finally:
        await conn.close()


@pytest.mark.asyncio
async def test_signup_trigger_hardened_behavior():
    """
    Verify public.handle_new_user() trigger with hardened search_path:
    Creating a new user in auth.users automatically provisions:
    1. public.profiles
    2. public.user_preferences (character='maru')
    3. public.subscriptions (tier='free', 120s limit)
    """
    new_user_id = str(uuid.uuid4())
    conn = await db_manager.get_connection()
    try:
        async with conn.transaction():
            # Insert into auth.users simulating a sign-up event
            await conn.execute("""
                INSERT INTO auth.users (id, email, raw_user_meta_data)
                VALUES ($1, 'trigger_test@example.com', '{"full_name": "Test Learner"}'::jsonb);
            """, uuid.UUID(new_user_id))

            # Verify profile was provisioned by trigger
            profile = await conn.fetchrow("SELECT * FROM public.profiles WHERE id = $1;", uuid.UUID(new_user_id))
            assert profile is not None
            assert profile["email"] == "trigger_test@example.com"
            assert profile["full_name"] == "Test Learner"

            # Verify preferences was provisioned
            prefs = await conn.fetchrow("SELECT * FROM public.user_preferences WHERE user_id = $1;", uuid.UUID(new_user_id))
            assert prefs is not None
            assert prefs["active_character_id"] == "maru"

            # Verify free subscription was provisioned
            sub = await conn.fetchrow("SELECT * FROM public.subscriptions WHERE user_id = $1;", uuid.UUID(new_user_id))
            assert sub is not None
            assert sub["tier"] == "free"
            assert sub["daily_speech_seconds_limit"] == 120

            raise asyncpg.exceptions.TransactionRollbackError("Rollback cleanly")
    except asyncpg.exceptions.TransactionRollbackError:
        pass
    finally:
        await conn.close()


@pytest.mark.asyncio
async def test_truncate_privilege_revoked_from_client_roles():
    """
    Migration 003 Hardening:
    Verify that neither 'authenticated' nor 'anon' possess TRUNCATE privileges
    on ANY of the 9 application tables.
    """
    tables = [
        "profiles", "user_preferences", "user_languages",
        "conversations", "messages", "learning_progress",
        "achievements", "usage_records", "subscriptions"
    ]
    conn = await db_manager.get_connection()
    try:
        for tbl in tables:
            can_trunc_auth = await conn.fetchval(
                f"SELECT has_table_privilege('authenticated', 'public.{tbl}', 'TRUNCATE');"
            )
            can_trunc_anon = await conn.fetchval(
                f"SELECT has_table_privilege('anon', 'public.{tbl}', 'TRUNCATE');"
            )
            assert not can_trunc_auth, f"SECURITY VULNERABILITY: authenticated can TRUNCATE public.{tbl}!"
            assert not can_trunc_anon, f"SECURITY VULNERABILITY: anon can TRUNCATE public.{tbl}!"
    finally:
        await conn.close()


@pytest.mark.asyncio
async def test_subscriptions_and_usage_records_write_privileges_revoked():
    """
    Migration 003 Hardening:
    Verify that table-level INSERT, UPDATE, DELETE are revoked from 'authenticated'
    and 'anon' on sensitive billing/metering tables: 'subscriptions' and 'usage_records'.
    Verify that 'service_role' retains full management access.
    """
    tables = ["subscriptions", "usage_records"]
    conn = await db_manager.get_connection()
    try:
        for tbl in tables:
            for op in ["INSERT", "UPDATE", "DELETE"]:
                can_auth = await conn.fetchval(
                    f"SELECT has_table_privilege('authenticated', 'public.{tbl}', '{op}');"
                )
                can_anon = await conn.fetchval(
                    f"SELECT has_table_privilege('anon', 'public.{tbl}', '{op}');"
                )
                assert not can_auth, f"SECURITY VULNERABILITY: authenticated can {op} public.{tbl}!"
                assert not can_anon, f"SECURITY VULNERABILITY: anon can {op} public.{tbl}!"

            # service_role must retain management access
            for op in ["SELECT", "INSERT", "UPDATE", "DELETE"]:
                can_srv = await conn.fetchval(
                    f"SELECT has_table_privilege('service_role', 'public.{tbl}', '{op}');"
                )
                assert can_srv, f"ERROR: service_role lost {op} on public.{tbl}!"
    finally:
        await conn.close()


@pytest.mark.asyncio
async def test_handle_new_user_hardened_search_path_and_execution_permissions():
    """
    Migration 003 Hardening:
    Verify public.handle_new_user():
    1. Direct EXECUTE is REVOKED from PUBLIC, anon, and authenticated.
    2. EXECUTE is granted to postgres, supabase_auth_admin, and service_role.
    3. search_path is configured to empty string (''): proconfig = ['search_path='].
    """
    conn = await db_manager.get_connection()
    try:
        # Check execution privileges
        can_exec_anon = await conn.fetchval(
            "SELECT has_function_privilege('anon', 'public.handle_new_user()', 'EXECUTE');"
        )
        can_exec_auth = await conn.fetchval(
            "SELECT has_function_privilege('authenticated', 'public.handle_new_user()', 'EXECUTE');"
        )
        can_exec_srv = await conn.fetchval(
            "SELECT has_function_privilege('service_role', 'public.handle_new_user()', 'EXECUTE');"
        )

        assert not can_exec_anon, "SECURITY VULNERABILITY: anon can EXECUTE handle_new_user() directly!"
        assert not can_exec_auth, "SECURITY VULNERABILITY: authenticated can EXECUTE handle_new_user() directly!"
        assert can_exec_srv, "ERROR: service_role cannot EXECUTE handle_new_user()!"

        # Check search_path configuration in pg_proc
        settings = await conn.fetchval("""
            SELECT p.proconfig
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public' AND p.proname = 'handle_new_user';
        """)
        assert settings is not None, "proconfig settings missing for handle_new_user"
        assert any(s.strip() in ('search_path=""', 'search_path=') for s in settings), (
            f"Expected empty search_path (search_path=\"\" or search_path=), found: {settings}"
        )
    finally:
        await conn.close()


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))

