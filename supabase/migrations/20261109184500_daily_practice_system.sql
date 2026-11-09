-- Migration: 20261109184500_daily_practice_system.sql
-- Description: Adds dedicated, relational tables for dynamic daily practice sessions, items, and attempts.
-- Ensures strict session ownership, composite foreign keys, RLS security, and historical attempt preservation.
-- Does NOT touch or drop existing profiles, user_preferences, conversations, messages, or subscriptions.

-- 1. Daily Practice Sessions
CREATE TABLE IF NOT EXISTS public.daily_practice_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    native_language_code TEXT NOT NULL,
    target_language_code TEXT NOT NULL,
    proficiency_level TEXT NOT NULL DEFAULT 'beginner',
    total_sentences INTEGER NOT NULL DEFAULT 14,
    completed_sentences INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'abandoned')),
    average_pronunciation_score NUMERIC(5, 2) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ NULL,
    CONSTRAINT unique_user_daily_session UNIQUE (user_id, session_date, native_language_code, target_language_code),
    CONSTRAINT uq_session_user_pair UNIQUE (id, user_id)
);

-- 2. Daily Practice Items (Sentences assigned to a session)
CREATE TABLE IF NOT EXISTS public.daily_practice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sequence_number INTEGER NOT NULL CHECK (sequence_number >= 1),
    category TEXT NOT NULL DEFAULT 'General',
    target_text TEXT NOT NULL,
    native_translation TEXT NOT NULL,
    pronunciation_guide TEXT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'attempted', 'passed', 'review')),
    best_pronunciation_score NUMERIC(5, 2) NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    first_attempted_at TIMESTAMPTZ NULL,
    passed_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Database-level ownership guarantee: item must belong to the exact user who owns the session
    CONSTRAINT fk_item_session_user FOREIGN KEY (session_id, user_id) 
        REFERENCES public.daily_practice_sessions(id, user_id) ON DELETE CASCADE,
    CONSTRAINT unique_session_sequence UNIQUE (session_id, sequence_number),
    CONSTRAINT uq_item_user_pair UNIQUE (id, user_id)
);

-- 3. Daily Practice Attempts (Detailed history of every speech attempt)
CREATE TABLE IF NOT EXISTS public.daily_practice_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL,
    session_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    attempt_number INTEGER NOT NULL CHECK (attempt_number >= 1),
    recognized_transcript TEXT NOT NULL,
    expected_target TEXT NOT NULL,
    pronunciation_score NUMERIC(5, 2) NOT NULL,
    is_passed BOOLEAN NOT NULL DEFAULT FALSE,
    feedback_notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Strict ownership constraints
    CONSTRAINT fk_attempt_item_user FOREIGN KEY (item_id, user_id) 
        REFERENCES public.daily_practice_items(id, user_id) ON DELETE CASCADE,
    CONSTRAINT fk_attempt_session_user FOREIGN KEY (session_id, user_id) 
        REFERENCES public.daily_practice_sessions(id, user_id) ON DELETE CASCADE
);

-- 4. High-Performance Indexes
CREATE INDEX IF NOT EXISTS idx_practice_sessions_user_date 
    ON public.daily_practice_sessions(user_id, session_date, native_language_code, target_language_code);
CREATE INDEX IF NOT EXISTS idx_practice_items_session_seq 
    ON public.daily_practice_items(session_id, sequence_number);
CREATE INDEX IF NOT EXISTS idx_practice_attempts_item 
    ON public.daily_practice_attempts(item_id, attempt_number);
CREATE INDEX IF NOT EXISTS idx_practice_attempts_user_created 
    ON public.daily_practice_attempts(user_id, created_at DESC);

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.daily_practice_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_practice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_practice_attempts ENABLE ROW LEVEL SECURITY;

-- 6. Strict User-Isolated RLS Policies
DO $$
BEGIN
    -- Sessions Policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'daily_practice_sessions' AND policyname = 'daily_practice_sessions_all_own'
    ) THEN
        CREATE POLICY daily_practice_sessions_all_own ON public.daily_practice_sessions
            FOR ALL TO authenticated
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    -- Items Policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'daily_practice_items' AND policyname = 'daily_practice_items_all_own'
    ) THEN
        CREATE POLICY daily_practice_items_all_own ON public.daily_practice_items
            FOR ALL TO authenticated
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    -- Attempts Policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'daily_practice_attempts' AND policyname = 'daily_practice_attempts_all_own'
    ) THEN
        CREATE POLICY daily_practice_attempts_all_own ON public.daily_practice_attempts
            FOR ALL TO authenticated
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

