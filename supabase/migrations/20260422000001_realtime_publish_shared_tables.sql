-- Realtime publication: attach shared-calendar tables
--
-- Supabase Realtime is driven by the `supabase_realtime` logical publication.
-- Without tables attached, postgres_changes subscriptions receive nothing, and
-- partner-device updates only flow via the app's initial fetch path on launch.
--
-- `REPLICA IDENTITY FULL` is required so UPDATE/DELETE events carry the full
-- old-row payload — SharedCalendarRealtimeService filters on shared_calendar_id
-- which isn't part of the default identity.
--
-- If this migration is re-run after manual fixes, wrap in idempotent guards.

do $$
begin
    if not exists (
        select 1 from pg_publication_tables
        where pubname    = 'supabase_realtime'
          and schemaname = 'public'
          and tablename  = 'dozy_events'
    ) then
        execute 'alter publication supabase_realtime add table public.dozy_events';
    end if;

    if not exists (
        select 1 from pg_publication_tables
        where pubname    = 'supabase_realtime'
          and schemaname = 'public'
          and tablename  = 'shared_calendar_members'
    ) then
        execute 'alter publication supabase_realtime add table public.shared_calendar_members';
    end if;
end
$$;

alter table public.dozy_events            replica identity full;
alter table public.shared_calendar_members replica identity full;
