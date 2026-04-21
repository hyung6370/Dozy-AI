-- v1.1.1: dozy_events external-source tracking for Apple/Google mirroring
--
-- Design:
--   - external_source / external_event_id: origin identifiers for a mirrored event.
--     A NULL external_source marks a native Dozy event (current behavior).
--   - external_last_synced_at: last successful reconciliation with origin (Phase D).
--   - external_deleted: set when the origin is no longer reachable on the owner's
--     device so the partner can see "원본 삭제됨" without losing the snapshot.
--   - (user_id, external_source, external_event_id) must be unique when present,
--     so re-sharing the same external event is idempotent instead of duplicating.

alter table public.dozy_events
    add column if not exists external_source         text,
    add column if not exists external_event_id       text,
    add column if not exists external_last_synced_at timestamptz,
    add column if not exists external_deleted        boolean not null default false;

-- Prevents duplicate snapshots of the same Apple/Google event by the same user.
create unique index if not exists idx_dozy_events_external_origin
    on public.dozy_events (user_id, external_source, external_event_id)
    where external_source is not null and external_event_id is not null;

-- Supports "load my mirrors for sync reconciliation" queries (Phase D).
create index if not exists idx_dozy_events_external_mirror_user
    on public.dozy_events (user_id, external_source)
    where external_source is not null;
