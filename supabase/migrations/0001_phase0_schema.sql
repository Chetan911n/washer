create extension if not exists pgcrypto;
create extension if not exists btree_gist;

create type public.account_role as enum ('customer', 'washer');
create type public.washer_status as enum ('pending', 'approved', 'rejected', 'removed');
create type public.car_type as enum ('hatchback', 'sedan', 'suv');
create type public.wash_type as enum ('basic', 'interior_vacuum', 'polish');
create type public.booking_status as enum ('held', 'payment_pending', 'confirmed', 'offered', 'assigned', 'arrived', 'in_progress', 'completed', 'complaint', 'cancelled', 'refunded');
create type public.payment_status as enum ('pending', 'paid', 'failed', 'partially_refunded', 'refunded');

create table public.societies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text not null default 'Nashik',
  state text not null default 'Maharashtra',
  timezone text not null default 'Asia/Kolkata',
  wash_time_windows jsonb not null default '[]'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.account_role not null,
  full_name text not null,
  phone_e164 text,
  avatar_path text,
  society_id uuid references public.societies(id),
  flat_number text,
  account_state text not null default 'active' check (account_state in ('active','deletion_requested','anonymized')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.cars (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id),
  car_type public.car_type not null,
  number_plate text not null,
  created_at timestamptz not null default now(),
  unique(customer_id, number_plate)
);

create table public.washers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id),
  society_id uuid not null references public.societies(id),
  status public.washer_status not null default 'pending',
  area text not null default '',
  daily_cap integer not null default 0 check (daily_cap >= 0),
  shift_hours jsonb not null default '[]'::jsonb,
  rating numeric(2,1) not null default 0 check (rating between 0 and 5),
  probation_jobs_count integer not null default 0 check (probation_jobs_count >= 0),
  cancellation_count integer not null default 0 check (cancellation_count >= 0),
  dispatch_priority numeric not null default 0,
  online boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.service_prices (
  id uuid primary key default gen_random_uuid(),
  society_id uuid references public.societies(id),
  car_type public.car_type not null,
  wash_type public.wash_type not null,
  amount_paise integer not null check (amount_paise > 0),
  included_description jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  unique nulls not distinct(society_id, car_type, wash_type)
);

create table public.app_config (
  key text primary key,
  value jsonb not null,
  description text not null default '',
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id)
);

create table public.availability_slots (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer not null default 0 check (capacity >= 0),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at),
  unique(society_id, starts_at)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id),
  car_id uuid not null references public.cars(id),
  society_id uuid not null references public.societies(id),
  washer_id uuid references public.washers(id),
  slot_id uuid not null references public.availability_slots(id),
  wash_type public.wash_type not null,
  status public.booking_status not null default 'held',
  parking_note text not null default '',
  customer_away boolean not null default false,
  price_paise integer not null check (price_paise >= 0),
  platform_fee_paise integer not null default 0 check (platform_fee_paise >= 0),
  washer_share_paise integer not null default 0 check (washer_share_paise >= 0),
  hold_expires_at timestamptz,
  start_otp_hash text,
  arrived_at timestamptz,
  completed_at timestamptz,
  complaint_deadline timestamptz,
  job_starts_at timestamptz,
  job_ends_at timestamptz,
  admin_review_required boolean not null default false,
  created_at timestamptz not null default now(),
  check ((job_starts_at is null and job_ends_at is null) or (job_starts_at is not null and job_ends_at > job_starts_at)),
  check (washer_id is null or (job_starts_at is not null and job_ends_at is not null))
);

create table public.slot_holds (
  id uuid primary key default gen_random_uuid(),
  slot_id uuid not null references public.availability_slots(id),
  customer_id uuid not null references public.profiles(id),
  booking_id uuid unique references public.bookings(id),
  expires_at timestamptz not null,
  released_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id),
  provider text not null default 'razorpay',
  razorpay_order_id text unique,
  razorpay_payment_id text unique,
  amount_paise integer not null check (amount_paise >= 0),
  status public.payment_status not null default 'pending',
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.job_offers (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id),
  washer_id uuid not null references public.washers(id),
  status text not null default 'offered' check (status in ('offered','accepted','declined','expired')),
  offered_at timestamptz not null default now(),
  expires_at timestamptz not null,
  responded_at timestamptz,
  unique(booking_id, washer_id, offered_at)
);

create table public.washer_selfies (
  id uuid primary key default gen_random_uuid(),
  washer_id uuid not null references public.washers(id),
  captured_at timestamptz not null,
  service_date date not null,
  storage_path text not null,
  created_at timestamptz not null default now(),
  unique(washer_id, service_date)
);

create table public.job_photos (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id),
  photo_type text not null check (photo_type in ('before','after','plate','complaint')),
  side text not null,
  storage_path text not null,
  captured_at timestamptz not null,
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  location_status text not null default 'tagged' check (location_status in ('tagged','no_location')),
  gps_wait_seconds integer not null default 0 check (gps_wait_seconds between 0 and 20),
  check ((latitude is null and longitude is null and location_status='no_location' and gps_wait_seconds=20) or (latitude is not null and longitude is not null and location_status='tagged')), 
  upload_state text not null default 'queued' check (upload_state in ('queued','uploaded')),
  retake_number integer not null default 0 check (retake_number between 0 and 2),
  created_at timestamptz not null default now()
);

create or replace function public.flag_missing_photo_location() returns trigger
language plpgsql security definer set search_path = public
as $$ begin
  if new.location_status='no_location' then
    update public.bookings set admin_review_required=true where id=new.booking_id;
  end if;
  return new;
end $$;
create trigger job_photos_flag_missing_location after insert on public.job_photos
for each row execute function public.flag_missing_photo_location();

create table public.complaints (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id),
  customer_id uuid not null references public.profiles(id),
  required_photo_id uuid not null references public.job_photos(id),
  status text not null default 'open' check (status in ('open','redo','refund','rejected','resolved')),
  admin_decision text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id),
  customer_id uuid not null references public.profiles(id),
  washer_id uuid not null references public.washers(id),
  stars integer not null check (stars between 1 and 5),
  created_at timestamptz not null default now()
);

create table public.tips (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id),
  customer_id uuid not null references public.profiles(id),
  washer_id uuid not null references public.washers(id),
  amount_paise integer not null check (amount_paise > 0),
  razorpay_payment_id text unique,
  status public.payment_status not null default 'pending',
  created_at timestamptz not null default now()
);

create table public.customer_washer_blocks (
  customer_id uuid not null references public.profiles(id),
  washer_id uuid not null references public.washers(id),
  blocked_at timestamptz not null default now(),
  primary key(customer_id, washer_id)
);

create table public.payouts (
  id uuid primary key default gen_random_uuid(),
  washer_id uuid not null references public.washers(id),
  period_start date not null,
  period_end date not null,
  total_paise integer not null default 0,
  refund_balance_paise integer not null default 0,
  status text not null default 'draft' check (status in ('draft','approved','paid','written_off')),
  created_at timestamptz not null default now(),
  check (period_end >= period_start)
);

create table public.payout_items (
  id uuid primary key default gen_random_uuid(),
  payout_id uuid not null references public.payouts(id),
  booking_id uuid references public.bookings(id),
  tip_id uuid references public.tips(id),
  amount_paise integer not null,
  item_type text not null check (item_type in ('wash','tip','refund_deduction','adjustment')),
  created_at timestamptz not null default now()
);

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id),
  booking_id uuid references public.bookings(id),
  payment_id uuid references public.payments(id),
  category text not null,
  message text not null default '',
  status text not null default 'open' check (status in ('open','in_progress','resolved')),
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id),
  booking_id uuid references public.bookings(id),
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.dispatch_queue (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id),
  status text not null default 'pending' check (status in ('pending','processing','done','failed')),
  attempts integer not null default 0,
  available_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.otp_request_events (
  id bigint generated always as identity primary key,
  phone_hash text not null,
  device_hash text not null,
  requested_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_type text not null check (actor_type in ('user','admin','system')),
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Explicit safe projections omit start_otp_hash from all client-facing job records.
create view public.customer_bookings with (security_invoker = true) as
select id, customer_id, car_id, society_id, washer_id, slot_id, wash_type, status, parking_note, customer_away, price_paise, platform_fee_paise, washer_share_paise, hold_expires_at, arrived_at, completed_at, complaint_deadline, job_starts_at, job_ends_at, admin_review_required, created_at
from public.bookings;
create view public.washer_job_details with (security_invoker = true) as
select b.id as booking_id, b.washer_id, s.starts_at, b.parking_note, b.wash_type, c.car_type, c.number_plate, b.status
from public.bookings b join public.cars c on c.id=b.car_id join public.availability_slots s on s.id=b.slot_id;

-- A washer can never hold overlapping assigned jobs; enforce at the database layer.
create unique index one_washer_per_slot on public.bookings(washer_id, slot_id) where washer_id is not null and status not in ('cancelled','refunded');
alter table public.bookings add constraint washer_jobs_do_not_overlap exclude using gist (washer_id with =, tstzrange(job_starts_at, job_ends_at, '[)') with &&) where (washer_id is not null and job_starts_at is not null and job_ends_at is not null and status not in ('cancelled','refunded'));
create index bookings_customer_created on public.bookings(customer_id, created_at desc);
create index bookings_slot_status on public.bookings(slot_id, status);
create index offers_expiry on public.job_offers(status, expires_at);
create index photos_booking_type on public.job_photos(booking_id, photo_type);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce((auth.jwt()->'app_metadata'->>'role') = 'admin', false) $$;

create or replace function public.is_assigned_washer(target_booking uuid) returns boolean
language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.bookings b join public.washers w on w.id=b.washer_id where b.id=target_booking and w.profile_id=auth.uid() and w.status='approved') $$;

-- RLS is enabled on every application table. Admin access is server/owner-only.
do $$ declare t text; begin
  foreach t in array array['societies','profiles','cars','washers','service_prices','app_config','availability_slots','bookings','slot_holds','payments','job_offers','washer_selfies','job_photos','complaints','ratings','tips','customer_washer_blocks','payouts','payout_items','support_tickets','notifications','audit_log','otp_request_events','dispatch_queue'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

create policy profile_self_read on public.profiles for select using (id=auth.uid() or public.is_admin());
-- Profile creation is trusted server-side so clients cannot choose or elevate roles.

create policy profile_self_update on public.profiles for update using (id=auth.uid() or public.is_admin()) with check (id=auth.uid() or public.is_admin());
create policy society_member_read on public.societies for select using (exists(select 1 from public.profiles p where p.id=auth.uid() and p.society_id=societies.id) or public.is_admin());
create policy car_owner_read on public.cars for select using (customer_id=auth.uid() or public.is_admin() or exists(select 1 from public.bookings b join public.washers w on w.id=b.washer_id where b.car_id=cars.id and w.profile_id=auth.uid() and w.status='approved'));
create policy car_owner_all on public.cars for all using (public.is_admin() or (customer_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='customer'))) with check (public.is_admin() or (customer_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='customer')));
create policy washer_self_read on public.washers for select using (profile_id=auth.uid() or public.is_admin() or (status='approved' and society_id in(select society_id from public.profiles where id=auth.uid())));
create policy washer_self_insert on public.washers for insert with check (profile_id=auth.uid() and status='pending' and daily_cap=0 and probation_jobs_count=0 and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='washer'));
create policy washer_admin_update on public.washers for update using (public.is_admin()) with check (public.is_admin());
create policy prices_society_read on public.service_prices for select using (public.is_admin() or (auth.uid() is not null and active and exists(select 1 from public.profiles p where p.id=auth.uid() and p.society_id is not null) and (society_id is null or society_id in(select society_id from public.profiles where id=auth.uid()))));
create policy prices_admin_write on public.service_prices for all using (public.is_admin()) with check (public.is_admin());
create policy config_admin_only on public.app_config for all using (public.is_admin()) with check (public.is_admin());
create policy slots_member_read on public.availability_slots for select using (society_id in(select society_id from public.profiles where id=auth.uid()) or public.is_admin());
create policy bookings_customer_or_assigned_read on public.bookings for select using (customer_id=auth.uid() or public.is_assigned_washer(id) or public.is_admin());
create policy booking_admin_update on public.bookings for update using (public.is_admin()) with check (public.is_admin());
create policy holds_owner_read on public.slot_holds for select using (customer_id=auth.uid() or public.is_admin());
create policy payments_owner_read on public.payments for select using (public.is_admin() or exists(select 1 from public.bookings b where b.id=booking_id and b.customer_id=auth.uid()));
create policy offers_washer_or_admin_read on public.job_offers for select using (public.is_admin() or exists(select 1 from public.washers w where w.id=washer_id and w.profile_id=auth.uid() and w.status='approved'));
create policy selfies_scoped_read on public.washer_selfies for select using (public.is_admin() or washer_id in(select id from public.washers where profile_id=auth.uid()) or exists(select 1 from public.bookings b join public.availability_slots s on s.id=b.slot_id where b.washer_id=washer_selfies.washer_id and b.customer_id=auth.uid() and (s.starts_at at time zone 'Asia/Kolkata')::date=washer_selfies.service_date and b.status not in ('completed','cancelled','refunded')));
create policy photos_scoped_read on public.job_photos for select using (public.is_admin() or (photo_type='after' and exists(select 1 from public.bookings b where b.id=booking_id and b.customer_id=auth.uid())) or exists(select 1 from public.bookings b where b.id=booking_id and b.washer_id in(select id from public.washers where profile_id=auth.uid() and status='approved')));
create policy complaints_scoped_read on public.complaints for select using (customer_id=auth.uid() or public.is_admin());
create policy ratings_customer_read on public.ratings for select using (customer_id=auth.uid() or public.is_admin());
create policy tips_owner_read on public.tips for select using (customer_id=auth.uid() or public.is_admin() or washer_id in(select id from public.washers where profile_id=auth.uid()));
create policy blocks_owner_all on public.customer_washer_blocks for all using (customer_id=auth.uid() or public.is_admin()) with check (customer_id=auth.uid() or public.is_admin());
create policy payouts_owner_read on public.payouts for select using (public.is_admin() or washer_id in(select id from public.washers where profile_id=auth.uid()));
create policy payout_items_owner_read on public.payout_items for select using (public.is_admin() or exists(select 1 from public.payouts p join public.washers w on w.id=p.washer_id where p.id=payout_id and w.profile_id=auth.uid()));
create policy avatar_self_or_assigned_read on storage.objects for select to authenticated
using (bucket_id='avatars' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin() or exists (
 select 1 from public.washers w join public.bookings b on b.washer_id=w.id
 where w.profile_id::text=(storage.foldername(name))[1] and b.customer_id=auth.uid() and b.status not in ('completed','cancelled','refunded')
)));
create policy avatar_self_upload on storage.objects for insert to authenticated
with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy avatar_self_update on storage.objects for update to authenticated
using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text)
with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy tickets_owner_read on public.support_tickets for select using (customer_id=auth.uid() or public.is_admin());
create policy tickets_customer_create on public.support_tickets for insert with check (customer_id=auth.uid() and (booking_id is null or exists(select 1 from public.bookings b where b.id=booking_id and b.customer_id=auth.uid())) and (payment_id is null or exists(select 1 from public.payments p join public.bookings b on b.id=p.booking_id where p.id=payment_id and b.customer_id=auth.uid())));
create policy notifications_owner_read on public.notifications for select using (recipient_id=auth.uid() or public.is_admin());
create policy dispatch_queue_admin_read on public.dispatch_queue for select using (public.is_admin());
create policy otp_events_admin_read on public.otp_request_events for select using (public.is_admin());
create policy audit_admin_read on public.audit_log for select using (public.is_admin());

-- Audit is append-only even for admins; inserts are made by trusted server code.
create policy audit_admin_insert on public.audit_log for insert with check (public.is_admin());
revoke update, delete on public.audit_log from authenticated;
revoke select on public.bookings from authenticated;
grant select (id, customer_id, car_id, society_id, washer_id, slot_id, wash_type, status, parking_note, customer_away, price_paise, platform_fee_paise, washer_share_paise, hold_expires_at, arrived_at, completed_at, complaint_deadline, job_starts_at, job_ends_at, admin_review_required, created_at) on public.bookings to authenticated;
grant select on public.customer_bookings, public.washer_job_details to authenticated;

-- Account role is immutable after registration.
create or replace function public.prevent_profile_role_change() returns trigger
language plpgsql set search_path = public
as $$ begin
  if new.role is distinct from old.role then raise exception 'Account role cannot be changed'; end if;
  return new;
end $$;
create trigger profiles_role_immutable before update on public.profiles
for each row execute function public.prevent_profile_role_change();

-- Private storage. A washer may upload an ID but can never read it back through the bucket.
insert into storage.buckets (id, name, public) values
 ('washer-ids','washer-ids',false), ('job-photos','job-photos',false), ('washer-selfies','washer-selfies',false), ('avatars','avatars',false)
on conflict (id) do nothing;
create policy washer_id_upload_own on storage.objects for insert to authenticated
with check (bucket_id='washer-ids' and (storage.foldername(name))[1]=auth.uid()::text);
create policy washer_id_admin_read on storage.objects for select to authenticated
using (bucket_id='washer-ids' and public.is_admin());
create policy job_photo_admin_read on storage.objects for select to authenticated
using (bucket_id='job-photos' and public.is_admin());
create policy job_photo_customer_after_read on storage.objects for select to authenticated
using (bucket_id='job-photos' and (storage.foldername(name))[2]='after' and exists (
 select 1 from public.bookings b where b.id::text=(storage.foldername(name))[1] and b.customer_id=auth.uid()
));
create policy job_photo_assigned_washer_read on storage.objects for select to authenticated
using (bucket_id='job-photos' and exists (
 select 1 from public.bookings b join public.washers w on w.id=b.washer_id
 where b.id::text=(storage.foldername(name))[1] and w.profile_id=auth.uid()
));
create policy selfie_admin_read on storage.objects for select to authenticated
using (bucket_id='washer-selfies' and public.is_admin());
create policy selfie_washer_read_own on storage.objects for select to authenticated
using (bucket_id='washer-selfies' and (storage.foldername(name))[1] in (select id::text from public.washers where profile_id=auth.uid()));
create policy selfie_booked_customer_read on storage.objects for select to authenticated
using (bucket_id='washer-selfies' and exists (
 select 1 from public.washers w join public.bookings b on b.washer_id=w.id
 where w.id::text=(storage.foldername(name))[1] and b.customer_id=auth.uid()
 and exists (select 1 from public.washer_selfies ws where ws.washer_id=w.id and ws.storage_path=storage.objects.name and ws.service_date=(select (s.starts_at at time zone 'Asia/Kolkata')::date from public.availability_slots s where s.id=b.slot_id))
 and b.status not in ('completed','cancelled','refunded')
));
