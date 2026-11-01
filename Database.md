## Table `profiles`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `email` | `text` |  |
| `full_name` | `text` |  Nullable |
| `avatar_url` | `text` |  Nullable |
| `created_at` | `timestamptz` |  |
| `updated_at` | `timestamptz` |  |

## Table `user_preferences`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `user_id` | `uuid` | Primary |
| `active_character_id` | `text` |  |
| `audio_speed` | `numeric` |  |
| `overlay_auto_hide` | `bool` |  |
| `haptic_feedback` | `bool` |  |
| `daily_goal_minutes` | `int4` |  |
| `created_at` | `timestamptz` |  |
| `updated_at` | `timestamptz` |  |

## Table `user_languages`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `user_id` | `uuid` |  |
| `native_language_code` | `text` |  |
| `target_language_code` | `text` |  |
| `proficiency_level` | `text` |  |
| `is_active` | `bool` |  |
| `created_at` | `timestamptz` |  |
| `updated_at` | `timestamptz` |  |

## Table `conversations`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `user_id` | `uuid` |  |
| `character_id` | `text` |  |
| `title` | `text` |  |
| `source_language` | `text` |  |
| `target_language` | `text` |  |
| `created_at` | `timestamptz` |  |
| `updated_at` | `timestamptz` |  |

## Table `messages`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `conversation_id` | `uuid` |  |
| `user_id` | `uuid` |  |
| `sender_role` | `text` |  |
| `source_text` | `text` |  |
| `translated_text` | `text` |  Nullable |
| `audio_storage_path` | `text` |  Nullable |
| `pronunciation_score` | `numeric` |  Nullable |
| `created_at` | `timestamptz` |  |

## Table `learning_progress`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `user_id` | `uuid` |  |
| `target_language` | `text` |  |
| `word_phrase` | `text` |  |
| `translation` | `text` |  |
| `repetition_count` | `int4` |  |
| `mastery_score` | `numeric` |  |
| `last_reviewed_at` | `timestamptz` |  |
| `next_review_at` | `timestamptz` |  |

## Table `achievements`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `user_id` | `uuid` |  |
| `achievement_code` | `text` |  |
| `metadata` | `jsonb` |  |
| `earned_at` | `timestamptz` |  |

## Table `usage_records`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `user_id` | `uuid` |  |
| `operation_type` | `text` |  |
| `duration_seconds` | `numeric` |  |
| `character_count` | `int4` |  |
| `created_at` | `timestamptz` |  |

## Table `subscriptions`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `user_id` | `uuid` |  Unique |
| `tier` | `text` |  |
| `status` | `text` |  |
| `daily_speech_seconds_limit` | `int4` |  |
| `current_period_start` | `timestamptz` |  |
| `current_period_end` | `timestamptz` |  Nullable |
| `created_at` | `timestamptz` |  |
| `updated_at` | `timestamptz` |  |

## RLS Policies

### `profiles`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `profiles_select_own` | SELECT | public | PERMISSIVE | `(auth.uid() = id)` | — |
| `profiles_insert_own` | INSERT | public | PERMISSIVE | — | `(auth.uid() = id)` |
| `profiles_update_own` | UPDATE | public | PERMISSIVE | `(auth.uid() = id)` | `(auth.uid() = id)` |

### `user_preferences`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `user_preferences_all_own` | ALL | public | PERMISSIVE | `(auth.uid() = user_id)` | `(auth.uid() = user_id)` |

### `user_languages`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `user_languages_all_own` | ALL | public | PERMISSIVE | `(auth.uid() = user_id)` | `(auth.uid() = user_id)` |

### `conversations`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `conversations_all_own` | ALL | public | PERMISSIVE | `(auth.uid() = user_id)` | `(auth.uid() = user_id)` |

### `messages`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `messages_all_own` | ALL | public | PERMISSIVE | `(auth.uid() = user_id)` | `(auth.uid() = user_id)` |

### `learning_progress`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `learning_progress_all_own` | ALL | public | PERMISSIVE | `(auth.uid() = user_id)` | `(auth.uid() = user_id)` |

### `usage_records`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `usage_records_select_own` | SELECT | public | PERMISSIVE | `(auth.uid() = user_id)` | — |

### `subscriptions`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `subscriptions_select_own` | SELECT | public | PERMISSIVE | `(auth.uid() = user_id)` | — |

### `achievements`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `achievements_select_own` | SELECT | public | PERMISSIVE | `(auth.uid() = user_id)` | — |

