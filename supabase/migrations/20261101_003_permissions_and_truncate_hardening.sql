-- ==============================================================================
-- LingoBoom Migration 003: Permissions and TRUNCATE Security Hardening
-- Migration: 20261101_003_permissions_and_truncate_hardening.sql
-- Target: PostgreSQL 15+ / Supabase Managed Cloud
-- Description:
--   1. Revokes TRUNCATE on all existing public application tables from authenticated, anon, and PUBLIC.
--   2. Alters DEFAULT PRIVILEGES in public schema to prevent TRUNCATE exposure on future tables.
--   3. Revokes direct table-level INSERT, UPDATE, DELETE on subscriptions and usage_records from authenticated and anon.
--   4. Grants ALL privileges on subscriptions and usage_records to trusted backend service_role.
--   5. Hardens public.handle_new_user() with SET search_path = '' and fully qualified object references.
--   6. Revokes EXECUTE on public.handle_new_user() from PUBLIC, anon, and authenticated.
--   7. Grants EXECUTE on public.handle_new_user() to postgres, supabase_auth_admin, and service_role.
--
-- Rollback Considerations:
--   - To restore TRUNCATE:
--       GRANT TRUNCATE ON ALL TABLES IN SCHEMA public TO authenticated, anon;
--   - To restore subscriptions & usage write grants:
--       GRANT INSERT, UPDATE, DELETE ON public.subscriptions TO authenticated;
--       GRANT INSERT, UPDATE, DELETE ON public.usage_records TO authenticated;
--   - To restore function permissions and search_path:
--       GRANT EXECUTE ON FUNCTION public.handle_new_user() TO PUBLIC;
--       ALTER FUNCTION public.handle_new_user() SET search_path = public, pg_temp;
-- ==============================================================================

-- 1. REVOKE TRUNCATE PRIVILEGES ON EXISTING APPLICATION TABLES
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM authenticated, anon, PUBLIC;

-- 2. ALTER DEFAULT PRIVILEGES FOR FUTURE TABLES
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    REVOKE TRUNCATE ON TABLES FROM authenticated, anon, PUBLIC;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public 
    REVOKE TRUNCATE ON TABLES FROM authenticated, anon, PUBLIC;

-- 3. HARDEN TABLE-LEVEL GRANTS ON SUBSCRIPTIONS AND USAGE_RECORDS
REVOKE INSERT, UPDATE, DELETE ON public.subscriptions FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.usage_records FROM authenticated, anon;

-- Ensure service_role retains full management privileges
GRANT ALL ON public.subscriptions TO service_role;
GRANT ALL ON public.usage_records TO service_role;

-- 4. HARDEN HANDLE_NEW_USER FUNCTION WITH EMPTY SEARCH_PATH
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Insert profile
    INSERT INTO public.profiles (id, email, full_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;

    -- Insert default preferences
    INSERT INTO public.user_preferences (user_id, active_character_id)
    VALUES (NEW.id, 'maru')
    ON CONFLICT (user_id) DO NOTHING;

    -- Insert default free subscription
    INSERT INTO public.subscriptions (user_id, tier, status, daily_speech_seconds_limit)
    VALUES (NEW.id, 'free', 'active', 120)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$;

-- 5. RESTRICT FUNCTION EXECUTION TO SYSTEM ROLES ONLY
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, supabase_auth_admin, service_role;

