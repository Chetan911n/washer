-- Local development seed only. These synthetic accounts have no usable credentials.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('10000000-0000-4000-8000-000000000001','authenticated','authenticated','customer@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000002','authenticated','authenticated','washer1@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000003','authenticated','authenticated','washer2@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000004','authenticated','authenticated','washer3@example.test','',now(),'{}','{}',now(),now())
on conflict (id) do nothing;

insert into public.societies (id, name, city, state, timezone, wash_time_windows)
values ('20000000-0000-4000-8000-000000000001','Pilot Society','Nashik','Maharashtra','Asia/Kolkata','[{"days":[1,2,3,4,5,6,0],"start":"07:00","end":"20:00"}]')
on conflict (id) do nothing;

insert into public.profiles (id, role, full_name, phone_e164, society_id, flat_number) values
 ('10000000-0000-4000-8000-000000000001','customer','Sample Customer',null,'20000000-0000-4000-8000-000000000001','A-101'),
 ('10000000-0000-4000-8000-000000000002','washer','Sample Washer 1',null,'20000000-0000-4000-8000-000000000001',null),
 ('10000000-0000-4000-8000-000000000003','washer','Sample Washer 2',null,'20000000-0000-4000-8000-000000000001',null),
 ('10000000-0000-4000-8000-000000000004','washer','Sample Washer 3',null,'20000000-0000-4000-8000-000000000001',null)
on conflict (id) do nothing;

insert into public.washers (profile_id, society_id, status, area, daily_cap, shift_hours) values
 ('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','approved','Pilot Society',5,'[{"days":[1,2,3,4,5,6,0],"start":"07:00","end":"14:00"}]'),
 ('10000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000001','approved','Pilot Society',5,'[{"days":[1,2,3,4,5,6,0],"start":"10:00","end":"18:00"}]'),
 ('10000000-0000-4000-8000-000000000004','20000000-0000-4000-8000-000000000001','approved','Pilot Society',5,'[{"days":[1,2,3,4,5,6,0],"start":"12:00","end":"20:00"}]')
on conflict (profile_id) do nothing;

insert into public.service_prices (society_id, car_type, wash_type, amount_paise, included_description) values
 ('20000000-0000-4000-8000-000000000001','hatchback','basic',19900,'{"en":"Exterior wash"}'),
 ('20000000-0000-4000-8000-000000000001','sedan','basic',24900,'{"en":"Exterior wash"}'),
 ('20000000-0000-4000-8000-000000000001','suv','basic',29900,'{"en":"Exterior wash"}'),
 ('20000000-0000-4000-8000-000000000001','hatchback','interior_vacuum',29900,'{"en":"Exterior wash and interior vacuum"}'),
 ('20000000-0000-4000-8000-000000000001','sedan','interior_vacuum',34900,'{"en":"Exterior wash and interior vacuum"}'),
 ('20000000-0000-4000-8000-000000000001','suv','interior_vacuum',39900,'{"en":"Exterior wash and interior vacuum"}'),
 ('20000000-0000-4000-8000-000000000001','hatchback','polish',99900,'{"en":"Exterior wash and polish"}'),
 ('20000000-0000-4000-8000-000000000001','sedan','polish',119900,'{"en":"Exterior wash and polish"}'),
 ('20000000-0000-4000-8000-000000000001','suv','polish',139900,'{"en":"Exterior wash and polish"}')
on conflict do nothing;

insert into public.app_config (key, value, description) values
 ('platform_fee_percent','15','Default platform fee percent'),
 ('duration_minutes','{"hatchback":25,"sedan":30,"suv":40,"basic":0,"interior_vacuum":15,"polish":30,"buffer":10}','Editable base durations, wash additions and buffer'),
 ('complaint_window_minutes','120','Complaint window after completion'),
 ('slot_hold_minutes','5','Payment hold duration'),
 ('dispatch_offer_seconds','120','Offer expiry before next washer'),
 ('backup_assignment_minutes','15','Backup dispatch before slot'),
 ('tips','{"window_hours":24,"minimum_paise":1000,"maximum_paise":50000,"washer_share_percent":100}','Tip limits and pass-through payout'),
 ('photo_retention_days','90','Job photo and selfie retention'),
 ('id_document_delete_days','30','ID removal deadline after account removal/deletion'),
 ('financial_retention_years','8','Placeholder pending accountant confirmation'),
 ('payout_day','"Monday"','Weekly payout day'),
 ('gps_fix_wait_seconds','20','Wait up to this many seconds for a GPS fix; then record no-location and flag for admin review'),
 ('minimum_app_version','{"android":"0.1.0+1"}','Minimum supported app versions'),
 ('otp_limits','{"phone_per_10_minutes":3,"phone_per_day":10,"device_per_hour":5}','OTP request limits')
on conflict (key) do nothing;
