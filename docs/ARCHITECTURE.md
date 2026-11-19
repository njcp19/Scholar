# Architecture

Scholar Wallet is a Flutter client backed by Firebase Authentication and
Supabase Postgres.

- **Client:** Flutter UI, `AppState`/Provider, and services under `lib/services/`.
- **Identity:** Firebase Email/Password sign-in. The app supplies the Firebase
  ID token to Supabase; the Firebase UID is the `profiles.id`.
- **Authorization and data:** Supabase Third-Party Auth validates that token.
  Database policies and RPCs use the verified token subject (`wallet_uid()`),
  with admin checks based on `profiles.role`. The client uses the public
  publishable/anon key, never a service-role key.
- **Registration Verification:** sign-up creates a pending, inactive scholar.
  At sign-up step 3, the selfie is uploaded to private Storage and recorded
  through `submit_selfie`. An admin views it through a 60-second signed URL and
  can request a retake; the retake is available only after that request. Admin
  review and requested-information resubmission are handled by database
  functions.
- **Scholarship catalog:** the Sign up picker can list active names before
  login. Admins manage the catalog through its RPCs; the client submits the
  selected name as text during registration.
- **Allowance and Payout:** an admin issues a Payout Event through a database
  function. A scholar confirms a Payout through a single-use token; the
  database function validates ownership/status and updates the balance and
  ledger records.
- **Cash Out and funding:** database functions record simulated funding and
  Cash Out activity. No bank or e-wallet transfer is made.
- **Device biometrics:** the operating system handles the local prompt. The
  app stores a profile indicator, not biometric data.

The initial database definition is [supabase_setup.sql](../supabase_setup.sql);
follow it with the migrations in [DATABASE.md](DATABASE.md).
