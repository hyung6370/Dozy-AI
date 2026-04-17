-- ============================================================================
-- v1.1: Shared Calendars (2-person, invite-code based)
--
-- Design summary:
--   - 2-person limit enforced at RPC layer (not DB constraint, for future N-person)
--   - Both members can edit (last-write-wins via updated_at)
--   - AI summary excludes shared events (filtered in app layer)
--   - 6-char invite code, 24h TTL
--   - Join/create/regenerate go through SECURITY DEFINER RPCs for atomic ops
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Enum
-- ----------------------------------------------------------------------------

CREATE TYPE public.shared_calendar_role AS ENUM ('owner', 'member');

-- ----------------------------------------------------------------------------
-- Tables
-- ----------------------------------------------------------------------------

CREATE TABLE public.shared_calendars (
    id                     uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    name                   text        NOT NULL,
    invite_code            text        UNIQUE,
    invite_code_expires_at timestamptz,
    created_by             uuid        NOT NULL REFERENCES auth.users(id),
    created_at             timestamptz DEFAULT now(),
    updated_at             timestamptz DEFAULT now()
);

CREATE TABLE public.shared_calendar_members (
    shared_calendar_id uuid NOT NULL REFERENCES public.shared_calendars(id) ON DELETE CASCADE,
    user_id            uuid NOT NULL REFERENCES auth.users(id)              ON DELETE CASCADE,
    role               public.shared_calendar_role NOT NULL DEFAULT 'member',
    joined_at          timestamptz DEFAULT now(),
    PRIMARY KEY (shared_calendar_id, user_id)
);

-- Add shared_calendar_id to dozy_events (null = personal event)
ALTER TABLE public.dozy_events
    ADD COLUMN IF NOT EXISTS shared_calendar_id uuid
        REFERENCES public.shared_calendars(id) ON DELETE SET NULL;

-- ----------------------------------------------------------------------------
-- Indexes
-- ----------------------------------------------------------------------------

CREATE INDEX idx_shared_calendar_members_user
    ON public.shared_calendar_members (user_id);

CREATE INDEX idx_dozy_events_shared_calendar
    ON public.dozy_events (shared_calendar_id)
    WHERE shared_calendar_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- Helper function (avoids RLS recursion on shared_calendar_members)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_shared_calendar_member(p_calendar_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.shared_calendar_members
        WHERE shared_calendar_id = p_calendar_id
          AND user_id = auth.uid()
    );
$$;

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------

ALTER TABLE public.shared_calendars        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_calendar_members ENABLE ROW LEVEL SECURITY;

-- shared_calendars: members can read, only creator can mutate
CREATE POLICY shared_calendars_member_select ON public.shared_calendars
    FOR SELECT USING (public.is_shared_calendar_member(id));

CREATE POLICY shared_calendars_owner_insert ON public.shared_calendars
    FOR INSERT WITH CHECK (created_by = auth.uid());

CREATE POLICY shared_calendars_owner_update ON public.shared_calendars
    FOR UPDATE USING (created_by = auth.uid())
               WITH CHECK (created_by = auth.uid());

CREATE POLICY shared_calendars_owner_delete ON public.shared_calendars
    FOR DELETE USING (created_by = auth.uid());

-- shared_calendar_members: members can see membership, users can leave own row.
-- INSERT is intentionally allowed ONLY via join_shared_calendar RPC.
CREATE POLICY shared_calendar_members_read ON public.shared_calendar_members
    FOR SELECT USING (public.is_shared_calendar_member(shared_calendar_id));

CREATE POLICY shared_calendar_members_leave ON public.shared_calendar_members
    FOR DELETE USING (user_id = auth.uid());

-- Update dozy_events RLS: owner OR shared-calendar member
DROP POLICY IF EXISTS owner_all ON public.dozy_events;

CREATE POLICY dozy_events_access ON public.dozy_events
    FOR ALL
    USING (
        auth.uid() = user_id
        OR (
            shared_calendar_id IS NOT NULL
            AND public.is_shared_calendar_member(shared_calendar_id)
        )
    )
    WITH CHECK (
        auth.uid() = user_id
        OR (
            shared_calendar_id IS NOT NULL
            AND public.is_shared_calendar_member(shared_calendar_id)
        )
    );

-- ----------------------------------------------------------------------------
-- RPCs
-- ----------------------------------------------------------------------------

-- Create calendar + add creator as owner member (atomic)
CREATE OR REPLACE FUNCTION public.create_shared_calendar(p_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id     uuid := auth.uid();
    v_calendar_id uuid;
    v_code        text;
    v_expires_at  timestamptz := now() + interval '24 hours';
    v_attempts    int := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('error', 'not_authenticated');
    END IF;

    IF p_name IS NULL OR length(trim(p_name)) = 0 THEN
        RETURN jsonb_build_object('error', 'invalid_name');
    END IF;

    LOOP
        -- 6-char alphanumeric code (uppercase, no ambiguous chars like 0/O 1/I)
        v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.shared_calendars WHERE invite_code = v_code
        );
        v_attempts := v_attempts + 1;
        IF v_attempts > 10 THEN
            RETURN jsonb_build_object('error', 'code_generation_failed');
        END IF;
    END LOOP;

    INSERT INTO public.shared_calendars (name, invite_code, invite_code_expires_at, created_by)
    VALUES (trim(p_name), v_code, v_expires_at, v_user_id)
    RETURNING id INTO v_calendar_id;

    INSERT INTO public.shared_calendar_members (shared_calendar_id, user_id, role)
    VALUES (v_calendar_id, v_user_id, 'owner');

    RETURN jsonb_build_object(
        'success',                true,
        'calendar_id',            v_calendar_id,
        'invite_code',            v_code,
        'invite_code_expires_at', v_expires_at
    );
END;
$$;

-- Join via invite code (enforces 2-person limit + expiry)
CREATE OR REPLACE FUNCTION public.join_shared_calendar(p_invite_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id      uuid := auth.uid();
    v_calendar_id  uuid;
    v_expires_at   timestamptz;
    v_member_count int;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('error', 'not_authenticated');
    END IF;

    SELECT id, invite_code_expires_at INTO v_calendar_id, v_expires_at
    FROM public.shared_calendars
    WHERE invite_code = upper(trim(p_invite_code));

    IF v_calendar_id IS NULL THEN
        RETURN jsonb_build_object('error', 'invalid_code');
    END IF;

    IF v_expires_at IS NOT NULL AND v_expires_at < now() THEN
        RETURN jsonb_build_object('error', 'expired_code');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.shared_calendar_members
        WHERE shared_calendar_id = v_calendar_id
          AND user_id = v_user_id
    ) THEN
        RETURN jsonb_build_object(
            'error', 'already_member',
            'calendar_id', v_calendar_id
        );
    END IF;

    SELECT COUNT(*) INTO v_member_count
    FROM public.shared_calendar_members
    WHERE shared_calendar_id = v_calendar_id;

    -- 2-person limit (app-level, easy to lift for v1.2 N-person)
    IF v_member_count >= 2 THEN
        RETURN jsonb_build_object('error', 'calendar_full');
    END IF;

    INSERT INTO public.shared_calendar_members (shared_calendar_id, user_id, role)
    VALUES (v_calendar_id, v_user_id, 'member');

    RETURN jsonb_build_object(
        'success',     true,
        'calendar_id', v_calendar_id
    );
END;
$$;

-- Regenerate invite code (owner only)
CREATE OR REPLACE FUNCTION public.regenerate_shared_calendar_invite_code(p_calendar_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id    uuid := auth.uid();
    v_code       text;
    v_expires_at timestamptz := now() + interval '24 hours';
    v_attempts   int := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('error', 'not_authenticated');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.shared_calendars
        WHERE id = p_calendar_id AND created_by = v_user_id
    ) THEN
        RETURN jsonb_build_object('error', 'not_owner');
    END IF;

    LOOP
        v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.shared_calendars WHERE invite_code = v_code
        );
        v_attempts := v_attempts + 1;
        IF v_attempts > 10 THEN
            RETURN jsonb_build_object('error', 'code_generation_failed');
        END IF;
    END LOOP;

    UPDATE public.shared_calendars
    SET invite_code            = v_code,
        invite_code_expires_at = v_expires_at,
        updated_at             = now()
    WHERE id = p_calendar_id;

    RETURN jsonb_build_object(
        'success',                true,
        'invite_code',            v_code,
        'invite_code_expires_at', v_expires_at
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_shared_calendar(text)                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_shared_calendar(text)                            TO authenticated;
GRANT EXECUTE ON FUNCTION public.regenerate_shared_calendar_invite_code(uuid)          TO authenticated;

-- ----------------------------------------------------------------------------
-- Update delete_user_account to cascade shared calendars owned by user
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.delete_user_account()
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO 'public'
AS $function$
BEGIN
    DELETE FROM work_logs              WHERE user_id    = auth.uid();
    DELETE FROM event_display_settings WHERE user_id    = auth.uid();
    DELETE FROM event_completions      WHERE user_id    = auth.uid();
    DELETE FROM user_categories        WHERE user_id    = auth.uid();
    DELETE FROM dozy_events            WHERE user_id    = auth.uid();
    -- Cascades: shared_calendar_members, and nulls dozy_events.shared_calendar_id
    DELETE FROM shared_calendars       WHERE created_by = auth.uid();
    DELETE FROM auth.users             WHERE id         = auth.uid();
END;
$function$;
