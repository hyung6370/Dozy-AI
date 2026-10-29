-- ============================================================================
-- #95 APNs 푸시 — 공유 캘린더 파트너 알림
--
--   1) push_tokens        : 기기별 APNs 토큰. 본인 행만 읽기 · 삭제, 등록은 register_push_token RPC
--   2) register_push_token: 같은 기기에서 계정을 바꾸면 토큰 소유자를 옮겨야 하는데 RLS 로는 남의 행을
--                           고칠 수 없어 SECURITY DEFINER 로 auth.uid() 기준 처리 (authenticated 만 실행)
--   3) 트리거             : 공유 캘린더에 일정이 "공유될 때"만 Edge Function `send-push` 호출 (pg_net)
--                           - INSERT (shared_calendar_id not null)
--                           - UPDATE 로 shared_calendar_id 가 새로 채워짐 (개인 일정을 공유로 옮김)
--                           - 완료 체크 · 메모 · 고정 같은 일반 UPDATE 는 제외 (알림 폭주)
--                           - 외부 미러(external_source not null)는 제외 (캘린더 통째 미러링 스팸)
--   Function URL · 호출 비밀값은 Vault 에 둔다 (저장소 커밋 금지):
--     select vault.create_secret('<https://<ref>.supabase.co/functions/v1/send-push>', 'push_function_url');
--     select vault.create_secret('<무작위 문자열>', 'push_webhook_secret');
--   두 값이 없으면 트리거는 아무것도 하지 않는다 (일정 저장은 절대 막지 않는다).
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- ----------------------------------------------------------------------------
-- 1) push_tokens
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.push_tokens (
    token           text        PRIMARY KEY,
    user_id         uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    platform        text        NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios', 'macos')),
    environment     text        NOT NULL CHECK (environment IN ('sandbox', 'production')),
    shared_enabled  boolean     NOT NULL DEFAULT true,
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS push_tokens_user_id_idx ON public.push_tokens (user_id);

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

GRANT SELECT, DELETE ON public.push_tokens TO authenticated;
REVOKE ALL ON public.push_tokens FROM anon;

DROP POLICY IF EXISTS "push_tokens_select_own" ON public.push_tokens;
CREATE POLICY "push_tokens_select_own" ON public.push_tokens
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "push_tokens_delete_own" ON public.push_tokens;
CREATE POLICY "push_tokens_delete_own" ON public.push_tokens
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = user_id);

-- ----------------------------------------------------------------------------
-- 2) register_push_token
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.register_push_token(
    p_token          text,
    p_platform       text,
    p_environment    text,
    p_shared_enabled boolean
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
    END IF;
    IF p_token IS NULL OR length(p_token) < 32 OR length(p_token) > 512 THEN
        RAISE EXCEPTION 'invalid token' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.push_tokens (token, user_id, platform, environment, shared_enabled, updated_at)
    VALUES (p_token, v_uid, p_platform, p_environment, p_shared_enabled, now())
    ON CONFLICT (token) DO UPDATE
        SET user_id        = EXCLUDED.user_id,      -- 같은 기기에서 계정 전환 → 소유자 이전
            platform       = EXCLUDED.platform,
            environment    = EXCLUDED.environment,
            shared_enabled = EXCLUDED.shared_enabled,
            updated_at     = now();
END;
$$;

REVOKE ALL ON FUNCTION public.register_push_token(text, text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_push_token(text, text, text, boolean) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3) 공유 일정 → send-push
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.notify_shared_event_push()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_url    text;
    v_secret text;
BEGIN
    SELECT decrypted_secret INTO v_url    FROM vault.decrypted_secrets WHERE name = 'push_function_url';
    SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'push_webhook_secret';
    IF v_url IS NULL OR v_secret IS NULL THEN
        RETURN NEW;   -- 설정 전에는 조용히 건너뛴다
    END IF;

    PERFORM net.http_post(
        url     := v_url,
        body    := jsonb_build_object('event_id', NEW.id),
        headers := jsonb_build_object(
            'Content-Type',         'application/json',
            'x-dozy-push-secret',   v_secret
        ),
        timeout_milliseconds := 5000
    );
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- 푸시 실패가 일정 저장을 막으면 안 된다
    RAISE WARNING 'notify_shared_event_push failed: %', SQLERRM;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_shared_event_push() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS dozy_events_shared_push_insert ON public.dozy_events;
CREATE TRIGGER dozy_events_shared_push_insert
    AFTER INSERT ON public.dozy_events
    FOR EACH ROW
    WHEN (NEW.shared_calendar_id IS NOT NULL AND NEW.external_source IS NULL)
    EXECUTE FUNCTION public.notify_shared_event_push();

DROP TRIGGER IF EXISTS dozy_events_shared_push_share ON public.dozy_events;
CREATE TRIGGER dozy_events_shared_push_share
    AFTER UPDATE OF shared_calendar_id ON public.dozy_events
    FOR EACH ROW
    WHEN (NEW.shared_calendar_id IS NOT NULL
          AND OLD.shared_calendar_id IS DISTINCT FROM NEW.shared_calendar_id
          AND NEW.external_source IS NULL)
    EXECUTE FUNCTION public.notify_shared_event_push();
