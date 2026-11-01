-- ==============================================================================
-- LingoBoom Corrective Security Hardening Migration
-- Migration: 20261101_002_security_hardening.sql
-- Target: PostgreSQL 15+ / Supabase Managed Cloud
-- Description:
--   1. Restricts achievements table writes strictly to trusted backend service_role.
--   2. Enforces composite foreign key on messages (conversation_id, user_id) to prevent cross-user conversation injection.
--   3. Hardens handle_new_user() with explicit search_path and fully-qualified identifiers.
--
-- Rollback Considerations:
--   - To revert composite FK:
--       ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS fk_messages_conversation_user;
--       ALTER TABLE public.messages ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;
--       ALTER TABLE public.conversations DROP CONSTRAINT IF EXISTS uq_conversations_id_user_id;
--   - To revert achievements permissions:
--       GRANT INSERT ON public.achievements TO authenticated;
--       CREATE POLICY "achievements_insert_own" ON public.achievements FOR INSERT WITH CHECK (auth.uid() = user_id);
--   - To revert function: re-run previous handle_new_user() without SET search_path.
-- ==============================================================================

-- ==============================================================================
-- 1. ACHIEVEMENTS: REMOVE CLIENT INSERT PERMISSION
-- Only trusted backend service_role operations may award achievements.
-- ==============================================================================
DROP POLICY IF EXISTS "achievements_insert_own" ON public.achievements;

REVOKE INSERT, UPDATE, DELETE ON public.achievements FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.achievements FROM anon;

-- Ensure SELECT policy remains active for client viewing
DROP POLICY IF EXISTS "achievements_select_own" ON public.achievements;
CREATE POLICY "achievements_select_own"
    ON public.achievements FOR SELECT
    USING (auth.uid() = user_id);

-- ==============================================================================
-- 2. MESSAGES & CONVERSATIONS: ENFORCE CONVERSATION/USER OWNERSHIP INTEGRITY
-- Enforce composite foreign key so a message's conversation_id and user_id MUST
-- belong to the identical user.
-- ==============================================================================
DO $$
BEGIN
    -- 2a. Add composite unique constraint on conversations(id, user_id) if not already present
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_conversations_id_user_id'
        AND conrelid = 'public.conversations'::regclass
    ) THEN
        ALTER TABLE public.conversations
            ADD CONSTRAINT uq_conversations_id_user_id UNIQUE (id, user_id);
    END IF;

    -- 2b. Drop legacy single-column foreign key if present
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'messages_conversation_id_fkey'
        AND conrelid = 'public.messages'::regclass
    ) THEN
        ALTER TABLE public.messages
            DROP CONSTRAINT messages_conversation_id_fkey;
    END IF;

    -- 2c. Add composite foreign key constraint
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_messages_conversation_user'
        AND conrelid = 'public.messages'::regclass
    ) THEN
        ALTER TABLE public.messages
            ADD CONSTRAINT fk_messages_conversation_user
            FOREIGN KEY (conversation_id, user_id)
            REFERENCES public.conversations(id, user_id)
            ON DELETE CASCADE;
    END IF;
END $$;

-- ==============================================================================
-- 3. HARDEN HANDLE_NEW_USER() FUNCTION
-- Explicitly lock down search_path to prevent search_path hijacking in SECURITY DEFINER
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

