-- Keep a review flag on each of a new washer's first ten completed jobs.
-- `probation_jobs_count` advances only when the booking first completes, so
-- duplicate status updates cannot consume extra probation jobs.
create or replace function public.flag_washer_probation_job()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  completed_jobs integer;
begin
  if new.washer_id is not null and new.status = 'assigned'
     and (tg_op = 'INSERT' or old.status is distinct from new.status or old.washer_id is distinct from new.washer_id) then
    select probation_jobs_count into completed_jobs
    from public.washers
    where id = new.washer_id;

    if completed_jobs < 10 then
      new.admin_review_required := true;
    end if;
  end if;
  return new;
end;
$$;

create trigger booking_probation_review_flag
before insert or update of status, washer_id on public.bookings
for each row execute function public.flag_washer_probation_job();

create or replace function public.count_completed_washer_job()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is distinct from 'completed'::public.booking_status
     and new.status = 'completed'::public.booking_status
     and new.washer_id is not null then
    update public.washers
    set probation_jobs_count = probation_jobs_count + 1
    where id = new.washer_id;
  end if;
  return new;
end;
$$;

create trigger booking_increment_washer_probation
after update of status on public.bookings
for each row execute function public.count_completed_washer_job();
