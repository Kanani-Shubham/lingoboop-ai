# LingoBoom — Supabase Database Architecture & Schema Design

**Database Engine:** PostgreSQL 15+ (Supabase Managed Cloud)  
**Security Model:** Mandatory Row Level Security (RLS) on all user-facing tables  
**UUID Convention:** Supabase `auth.users` UUID as primary key for user profiles

---

## 1. Schema Entity Relationship Diagram

```
      +------------------------+
      |    auth.users (Auth)   |
      +------------------------+
                  | 1:1
                  v
      +------------------------+       1:N       +------------------------+
      |        profiles        | --------------< |   user_characters      |
      +------------------------+                 +------------------------+
                  |                                           |
                  | 1:N                                       v N:1
                  |                              +------------------------+
                  |                              |       characters       |
                  |                              +------------------------+
                  |
                  | 1:N
                  +----------------------------< +------------------------+
                  |                              |    learning_history    |
                  |                              +------------------------+
                  | 1:N
                  +----------------------------< +------------------------+
                  |                              |    vocabulary_items    |
                  |                              +------------------------+
                  | 1:1
                  +----------------------------< +------------------------+
                  |                              |      subscriptions     |
                  |                              +------------------------+
                  | 1:1
                  +----------------------------< +------------------------+
                                                 |    user_entitlements   |
                                                 +------------------------+
```

---

## 2. Table Definitions (PostgreSQL DDL)

### 2.1. `profiles` Table
Stores core user information linked directly to Supabase Authentication.
```sql
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    native_language_code TEXT NOT NULL DEFAULT 'gu',
    target_language_code TEXT NOT NULL DEFAULT 'en',
    active_character_id TEXT NOT NULL DEFAULT 'maru',
    streak_count INT NOT NULL DEFAULT 0,
    last_active_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);
```

### 2.2. `characters` Table
Catalog of all companion pets.
```sql
CREATE TABLE public.characters (
    id TEXT PRIMARY KEY, -- 'maru', 'mimi', 'pano', 'bun', 'pip', 'leo'
    display_name TEXT NOT NULL,
    animal_species TEXT NOT NULL,
    accent_color_hex TEXT NOT NULL,
    lore_description TEXT,
    is_premium_only BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.characters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read access to characters"
    ON public.characters FOR SELECT
    TO authenticated, anon
    USING (true);
```

### 2.3. `learning_history` Table
Stores recorded translations, user spoken transcripts, and pronunciation scores.
```sql
CREATE TABLE public.learning_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    character_id TEXT NOT NULL REFERENCES public.characters(id),
    source_language TEXT NOT NULL,
    target_language TEXT NOT NULL,
    spoken_text TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    audio_synthesis_url TEXT,
    pronunciation_score NUMERIC(5,2), -- e.g. 85.50%
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX idx_learning_history_user ON public.learning_history(user_id, created_at DESC);

ALTER TABLE public.learning_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can access own learning history"
    ON public.learning_history FOR ALL
    USING (auth.uid() = user_id);
```

### 2.4. `subscriptions` Table
Authoritative billing and entitlement record managed strictly by backend webhooks.
```sql
CREATE TABLE public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    gateway_name TEXT NOT NULL, -- 'razorpay' or 'google_play'
    gateway_subscription_id TEXT,
    gateway_customer_id TEXT,
    plan_tier TEXT NOT NULL DEFAULT 'free', -- 'free', 'monthly_9', 'yearly_49'
    status TEXT NOT NULL DEFAULT 'active', -- 'active', 'past_due', 'canceled', 'expired'
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can read their own subscription status
CREATE POLICY "Users can read own subscription"
    ON public.subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- Write access restricted strictly to backend service role (RLS blocks client mutations)
```

### 2.5. `user_entitlements` Table
Enforces daily quotas and feature gates.
```sql
CREATE TABLE public.user_entitlements (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    tier TEXT NOT NULL DEFAULT 'free',
    daily_speech_seconds_limit INT NOT NULL DEFAULT 120, -- 2 min/day for free
    daily_speech_seconds_used INT NOT NULL DEFAULT 0,
    unlocked_characters TEXT[] NOT NULL DEFAULT ARRAY['maru', 'mimi', 'bun'], -- free characters
    can_use_ai_tutor BOOLEAN NOT NULL DEFAULT FALSE, -- Premium feature
    quota_reset_date DATE NOT NULL DEFAULT CURRENT_DATE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.user_entitlements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own entitlements"
    ON public.user_entitlements FOR SELECT
    USING (auth.uid() = user_id);
```

