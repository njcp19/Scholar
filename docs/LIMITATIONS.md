# Limitations and residual risks

- **No real money movement:** every Allocate Funds and Withdraw Allowance
  action is simulated. No bank or e-wallet is contacted, and no real money moves.
- **Selfie privacy and retention:** registration selfies are personal data
  subject to the Philippine Data Privacy Act. A retention and deletion policy
  still needs to be agreed with the school's Data Protection Officer (DPO).
  Deleting a profile does not delete its selfie file from Storage.
- **Scholarship catalog enforcement:** the catalog supplies names to the app,
  but the server does not validate `profiles.scholarship_name` against it.
  Direct API profile inserts can therefore supply a different non-empty name.
- **Biometrics are client-side:** device biometric matching stays on the device;
  the database's `biometric_registered` value is only a profile flag and a
  scholar can set it through the client. It is not server-side proof of a
  biometric check.
- **Roster verification is not server-attested:** `p_roster_checked` is supplied
  by the client. There is no server-side school roster integration.
- **Payout token expiry:** tokens are single-use, but there is no server-side
  expiry time.
- **Payout Event status:** a batch can remain `issued` after every payout is
  voided; voiding all payouts does not mark the batch complete.
- **Legacy database objects:** `application_reviews`, `scholarship_applications`,
  `scholarship_programs`, `record_application_review`, and `submit_application`
  are not defined in the checked-in setup or migrations, so their behavior and
  lifecycle are not managed here. Their presence in any deployed database has
  not been verified. Migration 008 leaves the legacy `scholarship_programs`
  table untouched.
- **Manual setup and drift:** SQL setup and migrations are applied manually.
  A database that differs from the checked-in scripts may behave differently;
  verify the target schema before applying changes.
- **Client distribution:** Firebase configuration and Supabase publishable/anon
  keys are client-side values. Security depends on correct Third-Party Auth
  configuration, database grants, policies, and RPC checks; never ship a
  service-role key.
