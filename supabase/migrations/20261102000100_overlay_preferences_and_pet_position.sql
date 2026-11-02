-- ==============================================================================
-- LingoBoom Supabase Migration
-- File: 20261102000100_overlay_preferences_and_pet_position.sql
-- Description: Add overlay_enabled and normalized pet position coordinates to user_preferences
-- ==============================================================================

-- 1. Safely add columns to public.user_preferences if they do not exist
ALTER TABLE public.user_preferences
    ADD COLUMN IF NOT EXISTS overlay_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS overlay_position_x NUMERIC(5,4) DEFAULT 0.5000 
        CHECK (overlay_position_x IS NULL OR (overlay_position_x >= 0.0000 AND overlay_position_x <= 1.0000)),
    ADD COLUMN IF NOT EXISTS overlay_position_y NUMERIC(5,4) DEFAULT 0.7000 
        CHECK (overlay_position_y IS NULL OR (overlay_position_y >= 0.0000 AND overlay_position_y <= 1.0000));

-- 2. Add documentation comments
COMMENT ON COLUMN public.user_preferences.overlay_enabled IS 'Controls whether the Android system floating overlay companion is enabled';
COMMENT ON COLUMN public.user_preferences.overlay_position_x IS 'Normalized X coordinate (0.0000 = left edge, 1.0000 = right edge) of the companion';
COMMENT ON COLUMN public.user_preferences.overlay_position_y IS 'Normalized Y coordinate (0.0000 = top edge, 1.0000 = bottom edge) of the companion';

-- 3. Verify existing RLS remains active (no changes to existing user_preferences_all_own policy)
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

