-- ============================================================================
-- Baseline: Dozy AI v1.0.0 production schema
-- Captured: 2026-04-17 via MCP schema inspection
-- Source: zgjetfmfrgwzkjjrwrec (prod)
--
-- This file reflects the EXACT state of production at v1.0.0, including
-- duplicate constraints/policies that accumulated from direct dashboard edits.
-- Those duplicates are cleaned up in 20260417000001_cleanup_duplicates.sql.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tables
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.app_config (
    key         text PRIMARY KEY,
    value       text NOT NULL,
    updated_at  timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.dozy_events (
    id                          text PRIMARY KEY,
    user_id                     uuid NOT NULL REFERENCES auth.users(id),
    title                       text NOT NULL,
    start_date                  timestamptz NOT NULL,
    end_date                    timestamptz NOT NULL,
    is_all_day                  boolean     DEFAULT false,
    location                    text,
    notes                       text,
    color_hex                   text        DEFAULT '#007AFF'::text,
    recurrence_rule             text        DEFAULT 'none'::text,
    recurrence_end_date         timestamptz,
    notification_minutes_before integer     DEFAULT -1,
    is_completed                boolean     DEFAULT false,
    created_at                  timestamptz DEFAULT now(),
    updated_at                  timestamptz DEFAULT now(),
    memos                       text[]      DEFAULT '{}'::text[],
    priority                    integer     DEFAULT 0,
    is_pinned                   boolean     DEFAULT false,
    category                    text        DEFAULT '일반'::text
);

CREATE TABLE IF NOT EXISTS public.event_completions (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid        NOT NULL REFERENCES auth.users(id),
    event_id     text        NOT NULL,
    is_completed boolean     DEFAULT false,
    event_date   timestamptz NOT NULL,
    updated_at   timestamptz DEFAULT now(),
    CONSTRAINT event_completions_user_event_date_key
        UNIQUE (user_id, event_id, event_date),
    CONSTRAINT event_completions_user_id_event_id_event_date_key
        UNIQUE (user_id, event_id, event_date),
    CONSTRAINT uq_event_completions_user_event_date
        UNIQUE (user_id, event_id, event_date)
);

CREATE TABLE IF NOT EXISTS public.event_display_settings (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid        NOT NULL REFERENCES auth.users(id),
    event_id   text        NOT NULL,
    priority   integer     DEFAULT 0,
    is_pinned  boolean     DEFAULT false,
    category   text        DEFAULT '일반'::text,
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT event_display_settings_unique
        UNIQUE (user_id, event_id),
    CONSTRAINT event_display_settings_user_event_key
        UNIQUE (user_id, event_id),
    CONSTRAINT uq_event_display_settings_user_event
        UNIQUE (user_id, event_id)
);

CREATE TABLE IF NOT EXISTS public.user_categories (
    id         text PRIMARY KEY,
    user_id    uuid    NOT NULL REFERENCES auth.users(id),
    name       text    NOT NULL,
    emoji      text    NOT NULL DEFAULT '📌'::text,
    color_hex  text    NOT NULL DEFAULT '#8E8E93'::text,
    "order"    integer DEFAULT 0,
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.work_logs (
    id                    uuid        PRIMARY KEY,
    user_id               uuid        NOT NULL REFERENCES auth.users(id),
    date                  timestamptz NOT NULL,
    raw_event_titles      text[]      DEFAULT '{}'::text[],
    raw_event_details     text[]      DEFAULT '{}'::text[],
    completed_task_titles text[]      DEFAULT '{}'::text[],
    memos                 text[]      DEFAULT '{}'::text[],
    ai_summary            text        DEFAULT ''::text,
    highlights            text[]      DEFAULT '{}'::text[],
    next_actions          text[]      DEFAULT '{}'::text[],
    category              text        DEFAULT '일반'::text,
    productivity_score    double precision,
    created_at            timestamptz DEFAULT now(),
    updated_at            timestamptz DEFAULT now(),
    CONSTRAINT uq_work_logs_user_date     UNIQUE (user_id, date),
    CONSTRAINT work_logs_user_date_key    UNIQUE (user_id, date),
    CONSTRAINT work_logs_user_id_date_key UNIQUE (user_id, date)
);

-- ----------------------------------------------------------------------------
-- Non-unique indexes (supplementary to constraint-backed indexes)
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_dozy_events_user_dates
    ON public.dozy_events (user_id, start_date, end_date);

CREATE UNIQUE INDEX IF NOT EXISTS idx_event_completions_unique
    ON public.event_completions (user_id, event_id, event_date);

CREATE INDEX IF NOT EXISTS idx_event_completions_user_date
    ON public.event_completions (user_id, event_date);

CREATE UNIQUE INDEX IF NOT EXISTS idx_event_display_settings_unique
    ON public.event_display_settings (user_id, event_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_work_logs_user_date
    ON public.work_logs (user_id, date);

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------

ALTER TABLE public.app_config             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dozy_events            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_completions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_display_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_categories        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_logs              ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- RLS Policies (duplicates preserved from drift)
-- ----------------------------------------------------------------------------

-- app_config: public read
CREATE POLICY public_read ON public.app_config
    FOR SELECT TO anon USING (true);

-- dozy_events
CREATE POLICY owner_all ON public.dozy_events
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can manage own events" ON public.dozy_events
    FOR ALL USING (auth.uid() = user_id);

-- event_completions
CREATE POLICY owner_all ON public.event_completions
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can manage own completions" ON public.event_completions
    FOR ALL USING (auth.uid() = user_id);

-- event_display_settings
CREATE POLICY owner_all ON public.event_display_settings
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- user_categories
CREATE POLICY owner_all ON public.user_categories
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "사용자 본인 카테고리만 접근" ON public.user_categories
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- work_logs
CREATE POLICY owner_all ON public.work_logs
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can manage own logs" ON public.work_logs
    FOR ALL USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- Functions
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.delete_user_account()
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO 'public'
AS $function$
BEGIN
    DELETE FROM work_logs              WHERE user_id = auth.uid();
    DELETE FROM event_display_settings WHERE user_id = auth.uid();
    DELETE FROM event_completions      WHERE user_id = auth.uid();
    DELETE FROM user_categories        WHERE user_id = auth.uid();
    DELETE FROM dozy_events            WHERE user_id = auth.uid();
    DELETE FROM auth.users             WHERE id = auth.uid();
END;
$function$;
