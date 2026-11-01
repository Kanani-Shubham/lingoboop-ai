-- ==============================================================================
-- LingoBoom Initial Database Schema & Row Level Security (RLS) Policies
-- Migration: 20261101_001_initial_schema.sql
-- Target: PostgreSQL 15+ / Supabase Managed Cloud
-- Security Model: Strict User Isolation via auth.uid()
-- ==============================================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 1. PROFILES TABLE
-- 1:1 mapping with auth.users
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ==============================================================================
-- 2. USER PREFERENCES TABLE
-- UI, character choices, audio playback defaults
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.user_preferences (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    active_character_id TEXT NOT NULL DEFAULT 'maru',
    audio_speed NUMERIC(3,2) NOT NULL DEFAULT 1.00 CHECK (audio_speed BETWEEN 0.50 AND 2.00),
    overlay_auto_hide BOOLEAN NOT NULL DEFAULT FALSE,
    haptic_feedback BOOLEAN NOT NULL DEFAULT TRUE,
    daily_goal_minutes INT NOT NULL DEFAULT 10 CHECK (daily_goal_minutes BETWEEN 1 AND 120),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_preferences_all_own" ON public.user_preferences;
CREATE POLICY "user_preferences_all_own" ON public.user_preferences FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ==============================================================================
-- 3. USER LANGUAGES TABLE
-- Native and target language pairings
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.user_languages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    native_language_code TEXT NOT NULL,
    target_language_code TEXT NOT NULL,
    proficiency_level TEXT NOT NULL DEFAULT 'beginner' CHECK (proficiency_level IN ('beginner', 'intermediate', 'advanced')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_user_language_pair UNIQUE (user_id, native_language_code, target_language_code)
);

CREATE INDEX IF NOT EXISTS idx_user_languages_user ON public.user_languages(user_id, is_active);

ALTER TABLE public.user_languages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_languages_all_own" ON public.user_languages;
CREATE POLICY "user_languages_all_own" ON public.user_languages FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ==============================================================================
-- 4. CONVERSATIONS TABLE
-- Chat sessions between user and AI character companion
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    character_id TEXT NOT NULL DEFAULT 'maru',
    title TEXT NOT NULL DEFAULT 'Practice Session',
    source_language TEXT NOT NULL DEFAULT 'gu-IN',
    target_language TEXT NOT NULL DEFAULT 'en-IN',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_conversations_user_updated ON public.conversations(user_id, updated_at DESC);

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conversations_all_own" ON public.conversations;
CREATE POLICY "conversations_all_own" ON public.conversations FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ==============================================================================
-- 5. MESSAGES TABLE
-- Individual transcript, translation, and feedback entries
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('user', 'assistant', 'system')),
    source_text TEXT NOT NULL,
    translated_text TEXT,
    audio_storage_path TEXT, -- Populated ONLY with explicit user retention consent
    pronunciation_score NUMERIC(5,2) CHECK (pronunciation_score IS NULL OR (pronunciation_score >= 0.00 AND pronunciation_score <= 100.00)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_messages_user_created ON public.messages(user_id, created_at DESC);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_all_own" ON public.messages;
CREATE POLICY "messages_all_own" ON public.messages FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ==============================================================================
-- 6. LEARNING PROGRESS TABLE
-- Spaced Repetition System (SRS) word mastery tracking
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.learning_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_language TEXT NOT NULL,
    word_phrase TEXT NOT NULL,
    translation TEXT NOT NULL,
    repetition_count INT NOT NULL DEFAULT 1,
    mastery_score NUMERIC(5,2) NOT NULL DEFAULT 0.00 CHECK (mastery_score BETWEEN 0.00 AND 100.00),
    last_reviewed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    next_review_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_user_word_progress UNIQUE (user_id, target_language, word_phrase)
);

CREATE INDEX IF NOT EXISTS idx_learning_progress_due ON public.learning_progress(user_id, next_review_at ASC);

ALTER TABLE public.learning_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "learning_progress_all_own" ON public.learning_progress;
CREATE POLICY "learning_progress_all_own" ON public.learning_progress FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ==============================================================================
-- 7. ACHIEVEMENTS TABLE
-- Milestone rewards, streak celebrations, and pet dance triggers
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    achievement_code TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    earned_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_user_achievement UNIQUE (user_id, achievement_code)
);

CREATE INDEX IF NOT EXISTS idx_achievements_user ON public.achievements(user_id, earned_at DESC);

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;

-- Users can read their own achievements
DROP POLICY IF EXISTS "achievements_select_own" ON public.achievements;
CREATE POLICY "achievements_select_own" ON public.achievements FOR SELECT
    USING (auth.uid() = user_id);

-- Only backend service-role or user claiming authorized milestone can insert
DROP POLICY IF EXISTS "achievements_insert_own" ON public.achievements;
CREATE POLICY "achievements_insert_own" ON public.achievements FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- ==============================================================================
-- 8. USAGE RECORDS TABLE
-- Speech seconds consumed, STT/TTS API metering
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    operation_type TEXT NOT NULL CHECK (operation_type IN ('stt', 'tts', 'tutor_chat')),
    duration_seconds NUMERIC(8,2) NOT NULL DEFAULT 0.00,
    character_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_usage_records_user_date ON public.usage_records(user_id, created_at DESC);

ALTER TABLE public.usage_records ENABLE ROW LEVEL SECURITY;

-- Users may only view their own usage records
DROP POLICY IF EXISTS "usage_records_select_own" ON public.usage_records;
CREATE POLICY "usage_records_select_own" ON public.usage_records FOR SELECT
    USING (auth.uid() = user_id);

-- Writes are restricted strictly to backend service-role (No direct client INSERT/UPDATE)

-- ==============================================================================
-- 9. SUBSCRIPTIONS TABLE
-- Authoritative billing state and daily quota limits
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    tier TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'monthly_9', 'yearly_49')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'past_due', 'canceled', 'expired')),
    daily_speech_seconds_limit INT NOT NULL DEFAULT 120, -- Free tier: 120s/day; Premium: 1800s/day
    current_period_start TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    current_period_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Users may only read their own subscription state
DROP POLICY IF EXISTS "subscriptions_select_own" ON public.subscriptions;
CREATE POLICY "subscriptions_select_own" ON public.subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- Writes are restricted strictly to backend service-role (Clients CANNOT alter subscription tier)

-- ==============================================================================
-- 10. AUTOMATED TRIGGER: USER PROFILE CREATION
-- Automatically provisions profile and free subscription on auth.users sign up
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Create profile
    INSERT INTO public.profiles (id, email, full_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;

    -- Create default preferences
    INSERT INTO public.user_preferences (user_id, active_character_id)
    VALUES (NEW.id, 'maru')
    ON CONFLICT (user_id) DO NOTHING;

    -- Create default free subscription
    INSERT INTO public.subscriptions (user_id, tier, status, daily_speech_seconds_limit)
    VALUES (NEW.id, 'free', 'active', 120)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger firing on every new user sign up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 11. ROLE GRANTS FOR SUPABASE ROLES
-- Grants standard table permissions so RLS policies can evaluate
-- ==============================================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO service_role;

-- Authenticated users receive standard CRUD privileges, gated strictly by RLS
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Anonymous users only have read permissions (further restricted by RLS)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
