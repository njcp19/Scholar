# Limitations and residual risks

- **No real money movement:** every funding top-up and Cash Out is simulated.
  No bank or e-wallet is contacted.
- **Biometrics are client-side:** device biometric matching stays on the device;
  the database's `biometric_registered` value is only a profile flag and a
  scholar can set it through the client. It is not server-side proof of a
  biometric check.
- **Roster verification is not server-attested:** `p_roster_checked` is supplied
  by the client. There is no server-side school roster integration.
- **Payout token expiry:** tokens are single-use, but there is no server-side
  expiry time.
- **Payout Event status:** a batch can remain `issued` after every claim is
  voided; voiding all claims does not mark the batch complete.
- **Legacy database objects:** the live database is reported to contain
  `application_reviews`, `scholarship_applications`, and `scholarship_programs`,
  plus `record_application_review` and `submit_application`. They are not
  defined in this repository, so their behavior and lifecycle are not managed
  here.
- **Manual setup and drift:** SQL setup and migrations are applied manually.
  A database that differs from the checked-in scripts may behave differently;
  verify the target schema before applying changes.
- **Client distribution:** Firebase configuration and Supabase publishable/anon
  keys are client-side values. Security depends on correct Third-Party Auth
  configuration, database grants, policies, and RPC checks; never ship a
  service-role key.
