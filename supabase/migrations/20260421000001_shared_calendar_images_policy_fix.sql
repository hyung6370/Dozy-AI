-- 기존 INSERT/UPDATE/DELETE 정책은 서브쿼리 내 unqualified `name`이
-- public.shared_calendars.name (캘린더 이름 컬럼) 으로 쉐도잉되어
-- 항상 거부되는 버그가 있었음.
-- → 서브쿼리 안에서 `name`을 참조하지 않고, outer에서 storage.objects.name을 먼저
--   split_part + uuid 캐스팅 후 IN 서브쿼리로 비교.

drop policy if exists "shared_calendar_images_owner_insert" on storage.objects;
drop policy if exists "shared_calendar_images_owner_update" on storage.objects;
drop policy if exists "shared_calendar_images_owner_delete" on storage.objects;

create policy "shared_calendar_images_owner_insert"
on storage.objects for insert to authenticated
with check (
    bucket_id = 'shared-calendar-images'
    and split_part(name, '/', 1)::uuid in (
        select c.id from public.shared_calendars c
        where c.created_by = auth.uid()
    )
);

create policy "shared_calendar_images_owner_update"
on storage.objects for update to authenticated
using (
    bucket_id = 'shared-calendar-images'
    and split_part(name, '/', 1)::uuid in (
        select c.id from public.shared_calendars c
        where c.created_by = auth.uid()
    )
)
with check (
    bucket_id = 'shared-calendar-images'
    and split_part(name, '/', 1)::uuid in (
        select c.id from public.shared_calendars c
        where c.created_by = auth.uid()
    )
);

create policy "shared_calendar_images_owner_delete"
on storage.objects for delete to authenticated
using (
    bucket_id = 'shared-calendar-images'
    and split_part(name, '/', 1)::uuid in (
        select c.id from public.shared_calendars c
        where c.created_by = auth.uid()
    )
);
