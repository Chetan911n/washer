-- W6: washer applications begin pending. Their requested hours are separate
-- from the approved shift and cap, which only an owner can set.
create or replace function public.valid_shift_schedule(schedule jsonb)
returns boolean
language sql
immutable
set search_path = public
as $$
  select case
    when jsonb_typeof(schedule) = 'array' then
      jsonb_array_length(schedule) between 1 and 7
      and not exists (
        select 1
        from jsonb_array_elements(schedule) as shift
        where case
              when jsonb_typeof(shift -> 'days') = 'array'
                then jsonb_array_length(shift -> 'days') not between 1 and 7
                     or exists (
                       select 1
                       from jsonb_array_elements_text(shift -> 'days') as day_value
                       where day_value !~ '^[0-6]$'
                     )
              else true
              end
           or not coalesce((shift ->> 'start') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$', false)
           or not coalesce((shift ->> 'end') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$', false)
           or (shift ->> 'start') >= (shift ->> 'end')
      )
    else false
  end;
$$;

-- A manually created email-only owner may not have a mobile profile row.
alter table public.audit_log drop constraint audit_log_actor_id_fkey;
alter table public.audit_log
  add constraint audit_log_actor_id_fkey foreign key (actor_id) references auth.users(id);

alter table public.washers
  add column requested_shift_hours jsonb not null default '[]'::jsonb,
  add constraint washer_requested_shift_valid
    check (requested_shift_hours = '[]'::jsonb or public.valid_shift_schedule(requested_shift_hours));

-- A signed-in applicant must be able to choose an active society before their
-- profile has a society_id. This exposes only the directory fields already in
-- the society table, not resident or booking data.
drop policy society_member_read on public.societies;
create policy active_societies_for_registration on public.societies
  for select to authenticated
  using (active or public.is_admin());

-- Allow a new applicant to retry an interrupted upload and a pending applicant
-- to replace an image before the owner reviews it. Approved IDs stay frozen.
create policy washer_id_retry_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'washer-ids'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not exists (
      select 1 from public.washers w
      where w.profile_id = auth.uid() and w.status <> 'pending'
    )
  )
  with check (
    bucket_id = 'washer-ids'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not exists (
      select 1 from public.washers w
      where w.profile_id = auth.uid() and w.status <> 'pending'
    )
  );

drop policy washer_self_insert on public.washers;
create policy washer_self_insert on public.washers
  for insert to authenticated
  with check (
    profile_id = auth.uid()
    and status = 'pending'
    and daily_cap = 0
    and shift_hours = '[]'::jsonb
    and probation_jobs_count = 0
    and public.valid_shift_schedule(requested_shift_hours)
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'washer'
    )
  );

create or replace function public.prevent_profile_role_change() returns trigger
language plpgsql set search_path = public
as $$ begin
  if new.role is distinct from old.role then
    raise exception 'Account role cannot be changed';
  end if;
  if new.account_state is distinct from old.account_state and not public.is_admin() then
    raise exception 'Account state can only be changed by the owner';
  end if;
  return new;
end $$;

create or replace function public.admin_review_washer_application(
  target_washer_id uuid,
  decision text,
  approved_daily_cap integer,
  approved_shift_hours jsonb,
  reviewing_admin_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_status public.washer_status;
begin
  if not exists (
    select 1 from auth.users u
    where u.id = reviewing_admin_id
      and u.raw_app_meta_data ->> 'role' = 'admin'
  ) then
    raise exception 'Owner authorization required' using errcode = '42501';
  end if;

  if decision not in ('approve', 'reject') then
    raise exception 'Decision must be approve or reject';
  end if;

  if decision = 'approve' and (
    approved_daily_cap not between 1 and 100
    or not public.valid_shift_schedule(approved_shift_hours)
  ) then
    raise exception 'Approved cap and shift schedule are invalid';
  end if;

  select status into current_status
  from public.washers
  where id = target_washer_id
  for update;

  if current_status is distinct from 'pending'::public.washer_status then
    raise exception 'Washer application is no longer pending';
  end if;

  update public.washers
  set status = case when decision = 'approve' then 'approved'::public.washer_status
                    else 'rejected'::public.washer_status end,
      daily_cap = case when decision = 'approve' then approved_daily_cap else 0 end,
      shift_hours = case when decision = 'approve' then approved_shift_hours else '[]'::jsonb end
  where id = target_washer_id;

  insert into public.audit_log(actor_type, actor_id, action, entity_type, entity_id, details)
  values (
    'admin', reviewing_admin_id,
    case when decision = 'approve' then 'approve_washer' else 'reject_washer' end,
    'washer', target_washer_id::text,
    case when decision = 'approve'
      then jsonb_build_object('daily_cap', approved_daily_cap, 'shift_hours', approved_shift_hours)
      else '{}'::jsonb end
  );
end;
$$;

revoke all on function public.admin_review_washer_application(uuid, text, integer, jsonb, uuid) from public, anon, authenticated;
grant execute on function public.admin_review_washer_application(uuid, text, integer, jsonb, uuid) to service_role;
