# Owner review console

This is a static, dependency-free approval console for W6 washer applications. It is hosted separately from the Flutter preview and calls the `review-washer-application` Supabase Edge Function. That function checks the owner `app_metadata.role` claim and AAL2 before accessing private ID photos or changing an application. Only the function has the service-role key.

## Configure an owner

1. In Supabase Auth, create an owner user with email and password. Do not add a phone number.
2. Enroll and verify a TOTP authenticator factor for that account.
3. In the Supabase SQL editor, set the server-managed owner claim for that exact account:

   ```sql
   update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
   where email = 'owner@example.com';
   ```

4. Deploy the `review-washer-application` Edge Function with the project-managed `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` environment values. Keep the service-role key in function secrets only.
5. Deploy `apps/admin` as a separate Vercel project with Root Directory `apps/admin`. Open the site, enter the Supabase project URL and public anon key, then sign in and enter the current authenticator code.

The project URL and public anon key are saved in that browser's local storage. No admin access token is persisted. Signed photo URLs expire after five minutes. The owner can set an approved daily job cap and shift or decline an application. Booking reminders remain parked and are not part of this console.
