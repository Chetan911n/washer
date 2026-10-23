-- Create a profile only after Supabase Auth has verified the phone OTP.
-- The only client-selectable account roles are customer and washer; admin
-- accounts are created manually and receive their role in app_metadata.
create or replace function public.create_profile_after_phone_verification()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  requested_role text := new.raw_user_meta_data ->> 'role';
begin
  if new.phone is null or new.phone_confirmed_at is null then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if old.phone_confirmed_at is not null
       and new.phone_confirmed_at is not distinct from old.phone_confirmed_at then
      return new;
    end if;
  end if;

  if requested_role not in ('customer', 'washer') then
    raise exception 'Choose Customer or Washer to create an account';
  end if;

  insert into public.profiles (id, role, full_name, phone_e164)
  values (new.id, requested_role::public.account_role, 'New member', new.phone)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger auth_user_profile_after_verified_phone
after insert or update on auth.users
for each row execute function public.create_profile_after_phone_verification();

-- The minimum version is the sole app_config value readable without an
-- authenticated admin claim. All other configuration remains admin-only.
create or replace function public.minimum_android_app_version()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(value ->> 'android', '0.1.0+1')
  from public.app_config
  where key = 'minimum_app_version'
$$;
revoke all on function public.minimum_android_app_version() from public;
grant execute on function public.minimum_android_app_version() to anon, authenticated;

-- Atomically enforce the product OTP limits before the mobile client asks
-- Supabase Auth to send an SMS. Raw phone numbers and device IDs are never
-- stored in the rate-limit ledger.
create or replace function public.reserve_otp_request(
  requested_phone_hash text,
  requested_device_hash text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  phone_10m integer;
  phone_day integer;
  device_hour integer;
  otp_limits jsonb;
begin
  if requested_phone_hash !~ '^[0-9a-f]{64}$'
     or requested_device_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid OTP rate-limit hashes';
  end if;

  perform pg_advisory_xact_lock(99001, hashtext(requested_phone_hash));
  perform pg_advisory_xact_lock(99002, hashtext(requested_device_hash));

  select value into otp_limits
    from public.app_config
   where key = 'otp_limits';

  select count(*) filter (where requested_at > now() - interval '10 minutes'),
         count(*) filter (where requested_at > now() - interval '1 day')
    into phone_10m, phone_day
    from public.otp_request_events
   where phone_hash = requested_phone_hash;
  if phone_10m >= coalesce((otp_limits ->> 'phone_per_10_minutes')::integer, 3) then
    return 'phone_window';
  end if;
  if phone_day >= coalesce((otp_limits ->> 'phone_per_day')::integer, 10) then
    return 'phone_day';
  end if;

  select count(*) into device_hour
    from public.otp_request_events
   where device_hash = requested_device_hash
     and requested_at > now() - interval '1 hour';
  if device_hour >= coalesce((otp_limits ->> 'device_per_hour')::integer, 5) then
    return 'device_hour';
  end if;

  insert into public.otp_request_events(phone_hash, device_hash)
  values (requested_phone_hash, requested_device_hash);
  return 'ok';
end;
$$;
revoke all on function public.reserve_otp_request(text, text) from public, anon, authenticated;
grant execute on function public.reserve_otp_request(text, text) to service_role;
