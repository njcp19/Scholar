# Database

For a new database, apply [supabase_setup.sql](../supabase_setup.sql) first.
It creates the base tables, functions, grants, and row-level security policies.
Then apply the numbered changes below in order. These SQL scripts are manual
database changes; the app does not apply them automatically.

| Order | File | Purpose |
|---|---|---|
| 001 | [001_store_account_last4_only.sql](../supabase/migrations/001_store_account_last4_only.sql) | Reduces saved account numbers in linked-account and Cash Out records to the last four digits; updates account-linking and Cash Out functions accordingly. Full digits discarded by this change cannot be recovered. |
| 002 | [002_funding_account.sql](../supabase/migrations/002_funding_account.sql) | Adds the funding account and restricted fund ledger, admin-only funding RPCs and claim-trigger accounting; updates `issue_verified_payout` to reserve funds. |
| 003 | [003_resubmit_registration_fields.sql](../supabase/migrations/003_resubmit_registration_fields.sql) | Extends `resubmit_registration` to accept student number, university, program, and year level. |
| 004 | [004_payout_audit_and_constraints.sql](../supabase/migrations/004_payout_audit_and_constraints.sql) | Adds Payout issuer/void audit fields and trigger, records ledger actors, and constrains claim amounts and profile balances. Depends on 002. |
| 005 | [005_cashout_idempotency_and_status.sql](../supabase/005_cashout_idempotency_and_status.sql) | Adds Cash Out idempotency and simulated flags, expands statuses, and updates `request_withdrawal`. Depends on 001. This file is currently in `supabase/`, not `supabase/migrations/`. |

The numeric order is the recommended deployment order even though 002 and 003
are independent of each other and 001. Do not skip ahead: 004 requires 002,
and 005 requires the last-four-digit account representation from 001. Confirm
the expected base schema and review each script before applying it to any
database.

The repository's [Phase 8 SQL test](../supabase/tests/phase8_security_money_movement.sql)
is a separate, manually run verification script, not a migration.
