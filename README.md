# Society Wash MVP

Flutter Android app and Supabase backend foundation for a single-society car wash pilot in Nashik. Money is INR; timestamps are stored as UTC and displayed in IST. Admin access is web-only.

## Current build status

Phase 0 establishes the shared Flutter theme, Supabase schema, RLS, seed data and private Storage policies. Phase 1 adds customer/washer register and login choices, phone OTP verification, hashed phone/device OTP request limits and a minimum-version gate. Phase 2 starts W6: washers submit a profile photo, private ID document, society, area and preferred hours; applications stay pending with zero job capacity until an owner approves them. The owner review console is in `apps/admin`; later W2–W12 workflows remain in progress.

Prerequisites: Flutter/Dart, Node.js for the future admin app, Docker, and the Supabase CLI. From `apps/mobile`, run `flutter pub get` and `flutter run`. For backend local development, run `supabase start`, apply migrations with `supabase db reset`, then run the SQL security suite with `supabase test db` and inspect the local database and Storage policies. The schema and seed data are in `supabase/migrations/0001_phase0_schema.sql` and `supabase/seed.sql`.

The seed creates one Nashik society, three synthetic approved washers, a sample customer, sample prices and configuration. Synthetic accounts have no usable credentials. Do not apply this seed to production.

## Provider setup for later phases

- **Supabase:** create a project, enable phone OTP, configure the SMS provider, apply migrations and set private Storage buckets/policies for ID documents, job photos and selfies.
- **Razorpay:** create test-mode credentials. Keep secret keys and webhook secrets only in Supabase Edge Function environment variables; never put them in the mobile app or admin bundle. Configure the payment webhook URL and verify its signature server-side.
- **SMS:** configure the selected provider in Supabase Auth. The app requests codes through `request-phone-otp`; its server-side limits are 3 requests per phone per 10 minutes, 10 per phone per day, and 5 per installation per hour. The function hashes phone and installation identifiers before storing rate-limit events. Configure the Edge Function secret `OTP_RATE_LIMIT_PEPPER` with a long random value and keep it private. Supabase Auth's own send limits should also be configured as a backstop.

No production credentials belong in this repository. Payment creation, webhook verification, reconciliation, dispatch, cancellation/reschedule, refunds and payouts are introduced in their corresponding phases.

## Scope notes

Booking reminders remain **Proposals (not implemented)**. The app uses the locked workflow and decisions, including the GPS exception in the schema: wait up to 20 seconds, then accept a no-location photo and flag that booking for admin review.

## Mac prerequisites and commands

For local database checks install **Flutter SDK** (Android support), **Docker Desktop**, and **Supabase CLI**. Also install Android Studio and its Android SDK, then create an Android emulator or enable USB debugging on an Android device. The Flutter target for this product is Android; do not use Chrome as the validation target.

Install Xcode Command Line Tools if missing with `xcode-select --install`. If Homebrew is not installed, install it from its official script, then add the Apple Silicon prefix to your shell:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install --cask flutter docker
brew install supabase/tap/supabase
```

Install Android Studio, then use its SDK Manager to install an Android SDK platform, platform-tools and an emulator image. Create and start an Android Virtual Device, or connect an Android phone with USB debugging enabled. Accept any Android SDK licenses with `flutter doctor --android-licenses`.

Start Docker Desktop and wait until it reports that the engine is running. Then from the project root run:

```sh
supabase start
supabase db reset
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

In a second terminal at the project root, serve the OTP Edge Function locally:

```sh
supabase functions serve request-phone-otp --env-file supabase/.env.local
```

The database security suite is in `supabase/tests/phase0_security.test.sql` and can be run with `supabase test db` once the local stack is healthy.

Copy `supabase/.env.example` to `supabase/.env.local` and replace the placeholder pepper with a long random value. Keep `.env.local` out of version control. In a second terminal, run the app on an Android emulator with the local Supabase URL and publishable key:

```sh
cd apps/mobile
flutter run -d <device-id> --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=<local-publishable-key> --dart-define=APP_VERSION=0.1.0+1
```

For a physical device, replace `10.0.2.2` with the Mac's LAN IP. Get the local publishable key from `supabase status`. The Supabase Auth SMS provider must be configured for actual SMS delivery. `flutter test` runs the current widget test suite.

For production SMS in India, ask the chosen SMS provider to confirm the applicable TRAI DLT steps before launch. TRAI’s sender guidance lists Principal Entity registration, header assignment and content-template registration among the requirements for applicable messages: [TRAI Advice to Senders](https://trai.gov.in/advice-to-senders).

## Owner account and washer review

Create the owner account manually in Supabase Auth with email and password; do not add a phone number. In Supabase Auth, enable and verify a TOTP authenticator factor. Set the account's `app_metadata.role` to `admin` using the Supabase dashboard or trusted SQL; never accept an admin role from user-editable metadata. The review Edge Function checks both that owner claim and the session's AAL2 assurance before returning applicant details or accepting a decision.

The static review console is `apps/admin/public`. It uses the public anon key and calls `review-washer-application`; the Supabase service-role key stays inside the Edge Function runtime. To deploy the console as a separate Vercel project, set its Root Directory to `apps/admin`. On first visit, enter the Supabase project URL and public anon key, then sign in with the email account and TOTP code. The console creates short-lived signed links for ID documents and profile photos. Approval sets the daily cap and approved shift; rejection is recorded in the append-only audit log.
