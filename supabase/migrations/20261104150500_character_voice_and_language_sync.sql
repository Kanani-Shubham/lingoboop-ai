-- ==============================================================================
-- LingoBoop AI Supabase Migration
-- File: 20261104150500_character_voice_and_language_sync.sql
-- Description: Add voice preferences, conversation query optimization indexes,
--              and verify strict RLS policies.
-- ==============================================================================

-- 1. Safely add voice selection columns to public.user_preferences
ALTER TABLE public.user_preferences
    ADD COLUMN IF NOT EXISTS selected_voice_id TEXT NOT NULL DEFAULT 'Shivani',
    ADD COLUMN IF NOT EXISTS selected_voice_provider TEXT NOT NULL DEFAULT 'gnani',
    ADD COLUMN IF NOT EXISTS selected_voice_language TEXT NOT NULL DEFAULT 'en-IN';

-- 2. Add documentation comments
COMMENT ON COLUMN public.user_preferences.selected_voice_id IS 'Authoritative TTS voice character ID (e.g., Shivani, Devansh, Chetana, Yashraj)';
COMMENT ON COLUMN public.user_preferences.selected_voice_provider IS 'TTS provider identifier (e.g., gnani, groq)';
COMMENT ON COLUMN public.user_preferences.selected_voice_language IS 'Default language dialect code associated with the voice';

-- 3. Performance Indexes for Conversation History and Active Languages
CREATE INDEX IF NOT EXISTS idx_conversations_user_updated
    ON public.conversations(user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
    ON public.messages(conversation_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_user_languages_user_active
    ON public.user_languages(user_id, is_active);

-- 4. Verify Row Level Security on all affected tables
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_languages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- 5. Safe idempotent RLS policies verification
DO $$
BEGIN
    -- user_preferences ALL policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'user_preferences' AND policyname = 'user_preferences_all_own'
    ) THEN
        CREATE POLICY "user_preferences_all_own" ON public.user_preferences FOR ALL
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    -- conversations ALL policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'conversations' AND policyname = 'conversations_all_own'
    ) THEN
        CREATE POLICY "conversations_all_own" ON public.conversations FOR ALL
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    -- messages ALL policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'messages' AND policyname = 'messages_all_own'
    ) THEN
        CREATE POLICY "messages_all_own" ON public.messages FOR ALL
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    -- user_languages ALL policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'user_languages' AND policyname = 'user_languages_all_own'
    ) THEN
        CREATE POLICY "user_languages_all_own" ON public.user_languages FOR ALL
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

