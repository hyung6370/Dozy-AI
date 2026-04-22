-- Reduce Realtime egress / message volume
--
-- Prior migration set REPLICA IDENTITY FULL on shared tables so that
-- UPDATE/DELETE payloads included the full old row for client-side filtering.
-- That inflates Realtime egress past the 5 GB free-tier limit.
--
-- This migration:
--   1. Reverts REPLICA IDENTITY to DEFAULT (primary-key-only old-row payload)
--      - Trade-off: DELETE events for `dozy_events` no longer flow via Realtime.
--        The app compensates via a foreground-resync path in
--        SharedCalendarRealtimeService.fetchAndSyncExistingEvents which diffs
--        local vs remote and deletes orphans.
--   2. Removes `shared_calendar_members` from the Realtime publication —
--      partner-left detection is now polled on foreground resume instead of
--      subscribed in realtime.
--
-- `dozy_events` stays in the publication so INSERT/UPDATE still stream live.

alter table public.dozy_events            replica identity default;
alter table public.shared_calendar_members replica identity default;

do $$
begin
    if exists (
        select 1 from pg_publication_tables
        where pubname    = 'supabase_realtime'
          and schemaname = 'public'
          and tablename  = 'shared_calendar_members'
    ) then
        execute 'alter publication supabase_realtime drop table public.shared_calendar_members';
    end if;
end
$$;
