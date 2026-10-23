-- Run after `supabase db reset`, which loads the synthetic seed fixtures.
create extension if not exists pgtap with schema extensions;
begin;
set local search_path = public, extensions;
select plan(29);

-- Prepare isolated booking/photo fixtures using the deterministic seed identities.
insert into public.cars (id, customer_id, car_type, number_plate)
values ('30000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','hatchback','TEST-001');
insert into public.availability_slots (id, society_id, starts_at, ends_at, capacity)
values
 ('40000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','2030-01-01 09:00:00+00','2030-01-01 10:00:00+00',2),
 ('40000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','2030-01-01 09:30:00+00','2030-01-01 10:30:00+00',2);
insert into public.bookings (id, customer_id, car_id, society_id, washer_id, slot_id, wash_type, status, price_paise, job_starts_at, job_ends_at)
values ('50000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',(select id from public.washers where profile_id='10000000-0000-4000-8000-000000000002'),'40000000-0000-4000-8000-000000000001','basic','assigned',19900,'2030-01-01 09:00:00+00','2030-01-01 09:40:00+00');
select ok((select admin_review_required from public.bookings where id='50000000-0000-4000-8000-000000000001'), 'a washer’s probation jobs are flagged for admin review');
insert into public.audit_log (actor_type, actor_id, action, entity_type, entity_id) values ('system', null, 'test_fixture', 'test', 'audit');
insert into public.job_photos (booking_id, photo_type, side, storage_path, captured_at, location_status, gps_wait_seconds)
values ('50000000-0000-4000-8000-000000000001','after','bonnet','fixture/after/bonnet.jpg',now(),'no_location',20);
select ok((select admin_review_required from public.bookings where id='50000000-0000-4000-8000-000000000001'), 'no GPS photo after 20 seconds flags the booking for admin review');
insert into public.job_photos (id, booking_id, photo_type, side, storage_path, captured_at, latitude, longitude)
values ('60000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','before','front','fixture/before/front.jpg',now(),19.99,73.78);
insert into storage.objects (bucket_id, name)
values ('washer-ids','10000000-0000-4000-8000-000000000002/identity.jpg');

select ok(public.valid_shift_schedule('[{"days":[1,2,3,4,5,6],"start":"07:00","end":"14:00"}]'::jsonb), 'valid requested working hours are accepted');
select ok(not public.valid_shift_schedule('[{"days":[8],"start":"18:00","end":"07:00"}]'::jsonb), 'invalid requested working hours are rejected');
select ok(not has_function_privilege('authenticated','public.admin_review_washer_application(uuid,text,integer,jsonb,uuid)','EXECUTE'), 'only the trusted admin server can call the washer review function');

select ok(not has_column_privilege('authenticated','public.bookings','start_otp_hash','SELECT'), 'start OTP hash is not selectable by clients');

update public.washers set status='pending', daily_cap=0, shift_hours='[]'::jsonb where profile_id='10000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.bookings),0::bigint,'pending washer cannot read job data');
select is((select count(*) from public.profiles where id='10000000-0000-4000-8000-000000000001'),0::bigint,'washer cannot read customer profile or phone');
select is((select count(*) from storage.objects where bucket_id='washer-ids' and name='10000000-0000-4000-8000-000000000002/identity.jpg'),0::bigint,'washer cannot read their uploaded identity document');
select lives_ok($$update storage.objects set metadata='{"mimetype":"image/jpeg"}'::jsonb where bucket_id='washer-ids' and name='10000000-0000-4000-8000-000000000002/identity.jpg'$$,'pending washer can retry an interrupted ID upload');
update public.washers set status='approved', daily_cap=99 where profile_id='10000000-0000-4000-8000-000000000002';
select is((select status::text || ':' || daily_cap::text from public.washers where profile_id='10000000-0000-4000-8000-000000000002'),'pending:0','washer cannot approve itself or set its job cap');

reset role;
update public.washers set status='approved' where profile_id='10000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.job_photos where booking_id='50000000-0000-4000-8000-000000000001' and photo_type='before'),0::bigint,'customer cannot read before photos');
select throws_ok($$update public.audit_log set action='tampered' where id=1$$,'42501',NULL,'audit log cannot be updated');
select throws_ok($$delete from public.audit_log where id=1$$,'42501',NULL,'audit log cannot be deleted');
select throws_ok($$update public.profiles set role='washer' where id='10000000-0000-4000-8000-000000000001'$$,'P0001',NULL,'client cannot change its role');
select throws_ok($$insert into public.profiles(id,role,full_name) values ('10000000-0000-4000-8000-000000000001','customer','Changed')$$,'42501',NULL,'client cannot set account role/profile at insert');

reset role;
select throws_ok($$insert into public.bookings (customer_id,car_id,society_id,washer_id,slot_id,wash_type,status,price_paise,job_starts_at,job_ends_at) values ('10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',(select id from public.washers where profile_id='10000000-0000-4000-8000-000000000002'),'40000000-0000-4000-8000-000000000002','basic','assigned',19900,'2030-01-01 09:30:00+00','2030-01-01 10:10:00+00')$$,'23P01',NULL,'overlapping washer jobs are rejected');
update public.bookings set status='completed', completed_at=now() where id='50000000-0000-4000-8000-000000000001';
select is((select probation_jobs_count from public.washers where profile_id='10000000-0000-4000-8000-000000000002'),1,'completed probation jobs increment the washer count exactly once');
select ok(not has_function_privilege('authenticated','public.reserve_otp_request(text,text)','EXECUTE'),'clients cannot call the trusted OTP rate-limit reservation function');
select is(public.reserve_otp_request(repeat('a',64),repeat('f',64)),'ok','first phone OTP request is allowed');
select is(public.reserve_otp_request(repeat('a',64),repeat('f',64)),'ok','second phone OTP request is allowed');
select is(public.reserve_otp_request(repeat('a',64),repeat('f',64)),'ok','third phone OTP request is allowed');
select is(public.reserve_otp_request(repeat('a',64),repeat('f',64)),'phone_window','fourth phone OTP request in ten minutes is rejected');
select is(public.reserve_otp_request(repeat('1',64),repeat('9',64)),'ok','device rate-limit request one is allowed');
select is(public.reserve_otp_request(repeat('2',64),repeat('9',64)),'ok','device rate-limit request two is allowed');
select is(public.reserve_otp_request(repeat('3',64),repeat('9',64)),'ok','device rate-limit request three is allowed');
select is(public.reserve_otp_request(repeat('4',64),repeat('9',64)),'ok','device rate-limit request four is allowed');
select is(public.reserve_otp_request(repeat('5',64),repeat('9',64)),'ok','device rate-limit request five is allowed');
select is(public.reserve_otp_request(repeat('6',64),repeat('9',64)),'device_hour','sixth device OTP request in one hour is rejected');
select * from finish();
rollback;
