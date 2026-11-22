# Database

For a new database, apply [supabase_setup.sql](../supabase_setup.sql) first.
It creates the base tables, functions, grants, and row-level security policies.
Then apply the numbered changes below in order. These SQL scripts are manual
database changes; the app does not apply them automatically.

| Order | File | Purpose |
|---|---|---|
| 001 | [001_store_account_last4_only.sql](../supabase/migrations/001_store_account_last4_only.sql) | Reduces saved account numbers in linked-account and Withdraw Allowance records to the last four digits; updates account-linking and allowance-transfer functions accordingly. Full digits discarded by this change cannot be recovered. |
| 002 | [002_funding_account.sql](../supabase/migrations/002_funding_account.sql) | Adds the funding account and restricted fund ledger, admin-only funding RPCs and payout-receipt accounting; updates `issue_verified_payout` to reserve funds. |
| 003 | [003_resubmit_registration_fields.sql](../supabase/migrations/003_resubmit_registration_fields.sql) | Extends `resubmit_registration` to accept student number, university, program, and year level. |
| 004 | [004_payout_audit_and_constraints.sql](../supabase/migrations/004_payout_audit_and_constraints.sql) | Adds Payout issuer/void audit fields and trigger, records ledger actors, and constrains payout amounts and profile balances. Depends on 002. |
| 005 | [005_cashout_idempotency_and_status.sql](../supabase/migrations/005_cashout_idempotency_and_status.sql) | Adds Withdraw Allowance idempotency and simulated flags, expands statuses, and updates `request_withdrawal`. Depends on 001. |
| 006 | [006_protect_admin_role.sql](../supabase/migrations/006_protect_admin_role.sql) | Adds `profile_role_audit`, `trg_profile_role_guard`, and `trg_profile_admin_delete_guard`. Role changes and admin deletions raise `ROLE_CHANGE_BLOCKED` and `ADMIN_DELETE_BLOCKED` unless that transaction first sets `app.allow_role_change` to `on`. Sign up creates scholars; admins are promoted with owner-run SQL. |
| 007 | [007_registration_selfie.sql](../supabase/migrations/007_registration_selfie.sql) | Adds protected selfie profile fields, the private `selfies` Storage bucket and its insert/read policies, `submit_selfie` and `request_selfie_retake`, and the `SELFIE_REQUIRED` approval trigger. A file uploaded without a successful `submit_selfie` can remain orphaned. |
| 008 | [008_scholarship_catalog.sql](../supabase/migrations/008_scholarship_catalog.sql) | Adds `scholarship_catalog` and `list_scholarship_catalog`, `add_scholarship_program`, `rename_scholarship_program`, and `set_scholarship_program_active`. No names are pre-filled; entries are hidden rather than deleted. The legacy `scholarship_programs` table is untouched. |

The numeric order is the recommended deployment order even though 002 and 003
are independent of each other and 001. Do not skip ahead: 004 requires 002,
005 requires the last-four-digit account representation from 001, and 006
through 008 are each marked independent of the earlier migrations in their SQL
files. Apply all migrations in numeric order. Confirm the expected base schema
and review each script before applying it to any database.

### Migration 006 role protection

The two profile triggers block changing a role or deleting an admin unless the
same transaction first runs `set local app.allow_role_change = 'on';`. For an
intentional role change, run the SQL as the database owner, inspect the returned
row, then commit:

```sql
begin;
set local app.allow_role_change = 'on';
update public.profiles
set role = 'admin'
where id = '<Firebase UID>'
  and role = 'scholar'
returning id, email, role;
commit;
```

The same transaction-local setting is required to delete an admin profile.
Read the audit as the database owner; `anon` and `authenticated` have no direct
access:

```sql
select profile_id, email, old_role, new_role, changed_by, db_user, app_name,
       changed_at
from public.profile_role_audit
order by changed_at desc;
```

The app's Sign up path assigns the scholar role. Admin promotion is an
intentional owner-run SQL operation protected by the migration's trigger.

### Migration 007 registration selfie

The migration adds `profiles.selfie_path`, `selfie_submitted_at`, and
`selfie_retake_allowed`. A guard trigger allows their changes only through the
selfie RPC flow. The private `selfies` bucket is limited to 2 MB and JPEG/PNG;
`selfies_insert_own` restricts uploads to the scholar's own folder, and
`selfies_admin_read` permits admin reads. `submit_selfie` records an uploaded
file, while the admin-only `request_selfie_retake` enables a retake. The
approval trigger raises `SELFIE_REQUIRED` when approval is attempted without a
selfie; already-approved scholars are not affected by that transition check.
An uploaded file for which `submit_selfie` never succeeds can remain as an
orphan private file.

### Migration 008 scholarship catalog

`list_scholarship_catalog` returns active entries to unauthenticated callers;
an admin can request inactive entries too. The admin-only write RPCs add,
rename, or hide/show entries. The migration does not seed scholarship names
and does not delete catalog entries or modify the legacy
`scholarship_programs` table.

The repository's [Phase 8 SQL test](../supabase/tests/phase8_security_money_movement.sql)
is a separate, manually run verification script, not a migration.
