-- ============================================================================
-- Align & Cleanup: reconcile prod/dev drift and establish canonical schema
--
-- Problem:
--   - Prod accumulated duplicate UNIQUE constraints and RLS policies from
--     direct dashboard edits.
--   - Dev never received the UNIQUE constraints or supplementary indexes at
--     all (only PK/FK present).
--
-- This migration is idempotent: each statement is a no-op when the target
-- state is already achieved, so both environments converge to the same
-- canonical schema after running it.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Drop duplicate UNIQUE constraints (prod-only cleanup)
--   Keep: uq_* prefix as canonical
--   Drop: other duplicates
-- ----------------------------------------------------------------------------

ALTER TABLE public.event_completions
    DROP CONSTRAINT IF EXISTS event_completions_user_event_date_key;
ALTER TABLE public.event_completions
    DROP CONSTRAINT IF EXISTS event_completions_user_id_event_id_event_date_key;

ALTER TABLE public.event_display_settings
    DROP CONSTRAINT IF EXISTS event_display_settings_unique;
ALTER TABLE public.event_display_settings
    DROP CONSTRAINT IF EXISTS event_display_settings_user_event_key;

ALTER TABLE public.work_logs
    DROP CONSTRAINT IF EXISTS work_logs_user_date_key;
ALTER TABLE public.work_logs
    DROP CONSTRAINT IF EXISTS work_logs_user_id_date_key;

-- ----------------------------------------------------------------------------
-- Drop redundant standalone unique indexes (same cols as canonical constraint)
-- ----------------------------------------------------------------------------

DROP INDEX IF EXISTS public.idx_event_completions_unique;
DROP INDEX IF EXISTS public.idx_event_display_settings_unique;
DROP INDEX IF EXISTS public.idx_work_logs_user_date;

-- ----------------------------------------------------------------------------
-- Drop duplicate RLS policies (keep owner_all as canonical)
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "users can manage own events"      ON public.dozy_events;
DROP POLICY IF EXISTS "users can manage own completions" ON public.event_completions;
DROP POLICY IF EXISTS "users can manage own logs"        ON public.work_logs;
DROP POLICY IF EXISTS "사용자 본인 카테고리만 접근"           ON public.user_categories;

-- ----------------------------------------------------------------------------
-- Ensure canonical UNIQUE constraints exist (dev-only backfill)
-- ----------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_event_completions_user_event_date'
          AND conrelid = 'public.event_completions'::regclass
    ) THEN
        ALTER TABLE public.event_completions
            ADD CONSTRAINT uq_event_completions_user_event_date
            UNIQUE (user_id, event_id, event_date);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_event_display_settings_user_event'
          AND conrelid = 'public.event_display_settings'::regclass
    ) THEN
        ALTER TABLE public.event_display_settings
            ADD CONSTRAINT uq_event_display_settings_user_event
            UNIQUE (user_id, event_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_work_logs_user_date'
          AND conrelid = 'public.work_logs'::regclass
    ) THEN
        ALTER TABLE public.work_logs
            ADD CONSTRAINT uq_work_logs_user_date
            UNIQUE (user_id, date);
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- Ensure supplementary indexes exist (dev-only backfill)
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_dozy_events_user_dates
    ON public.dozy_events (user_id, start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_event_completions_user_date
    ON public.event_completions (user_id, event_date);
