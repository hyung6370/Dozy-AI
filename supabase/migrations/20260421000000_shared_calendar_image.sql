-- shared_calendars 이미지 지원
--   - shared_calendars.image_path: storage.objects.name 경로 (URL 아님)
--   - 'shared-calendar-images' public 버킷 + RLS 정책 (owner만 쓰기, 누구나 읽기)

alter table public.shared_calendars
    add column if not exists image_path text;

insert into storage.buckets (id, name, public)
values ('shared-calendar-images', 'shared-calendar-images', true)
on conflict (id) do nothing;

-- SELECT: 누구나
drop policy if exists "shared_calendar_images_public_read" on storage.objects;
create policy "shared_calendar_images_public_read"
on storage.objects for select
using (bucket_id = 'shared-calendar-images');

-- INSERT/UPDATE/DELETE: 해당 캘린더의 owner (경로 첫 세그먼트 = calendar_id)
drop policy if exists "shared_calendar_images_owner_insert" on storage.objects;
create policy "shared_calendar_images_owner_insert"
on storage.objects for insert
with check (
    bucket_id = 'shared-calendar-images'
    and exists (
        select 1 from public.shared_calendars c
        where c.id::text = split_part(name, '/', 1)
          and c.created_by = auth.uid()
    )
);

drop policy if exists "shared_calendar_images_owner_update" on storage.objects;
create policy "shared_calendar_images_owner_update"
on storage.objects for update
using (
    bucket_id = 'shared-calendar-images'
    and exists (
        select 1 from public.shared_calendars c
        where c.id::text = split_part(name, '/', 1)
          and c.created_by = auth.uid()
    )
)
with check (
    bucket_id = 'shared-calendar-images'
    and exists (
        select 1 from public.shared_calendars c
        where c.id::text = split_part(name, '/', 1)
          and c.created_by = auth.uid()
    )
);

drop policy if exists "shared_calendar_images_owner_delete" on storage.objects;
create policy "shared_calendar_images_owner_delete"
on storage.objects for delete
using (
    bucket_id = 'shared-calendar-images'
    and exists (
        select 1 from public.shared_calendars c
        where c.id::text = split_part(name, '/', 1)
          and c.created_by = auth.uid()
    )
);
