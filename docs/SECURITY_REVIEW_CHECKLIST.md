# Scholarship Wallet Security Review Checklist

## Important current limitation

Migration 001 masks existing linked-account and Withdraw Allowance account snapshots to
the last four digits, and its RPCs store only those digits. The base setup and
migrations are applied manually, so verify that migration 001 has been applied
to the target database. Account details are not bank-verified, and Withdraw
Allowance is simulated; no real money moves. Use fictional test account data
only.

Do not collect real bank, GCash, or Maya account numbers until a reviewed design is in place. Do not collect online banking passwords, PINs, or OTPs at any stage.

## Required work before real account linking

- Replace raw account-number storage with an approved provider authorization flow and provider-issued account reference where available.
- If a business requirement truly requires storing account data, define an approved encryption/key-management and retention design before collecting it. Do not put encryption keys in Flutter or ordinary database rows.
- Restrict read/write access with verified-user ownership policies and server-side authorization.
- Review every SECURITY DEFINER function for explicit role/ownership checks and a fixed safe search_path.
- Ensure Withdraw Allowance history is labeled simulated and cannot be mistaken
  for a bank-confirmed transfer.
- Remove or securely dispose of any real account details entered during testing, following the project's data-retention policy.

## Development checklist

- [ ] Review Supabase RLS policies for profiles, transactions, linked_accounts, withdrawals, funding_accounts, allowance_claims, and registration_reviews.
- [ ] Review all RPC grants and SECURITY DEFINER function bodies.
- [ ] Confirm Firebase JWT verification and Supabase user identity mapping.
- [ ] Add automated tests for ownership, role boundaries, duplicate payout confirmations, and duplicate allowance requests.
- [ ] Apply migration 006 and verify that role changes and admin deletion are
      blocked without transaction-local `app.allow_role_change = 'on'`, and
      that `profile_role_audit` is readable only by the database owner.
- [ ] Apply migration 007 and verify the private 2 MB JPEG/PNG bucket,
      `selfies_insert_own` and `selfies_admin_read` policies, protected selfie
      fields, the retake RPC, and the `SELFIE_REQUIRED` approval trigger.
- [ ] Apply migration 008 and verify unauthenticated listing returns active
      names, write RPCs are admin-only, no names are pre-filled, and entries
      are hidden rather than deleted. Confirm the legacy
      `scholarship_programs` table is untouched.
- [ ] Run the whole
      [Phase 8 SQL test](../supabase/tests/phase8_security_money_movement.sql)
      as the database owner. It runs in a transaction and ends with `ROLLBACK`;
      expect 9 PASS results. In a new SQL Editor tab, run the leftover check
      and confirm `leftover_profiles` is 0 and the allowance is back to its
      normal value:

      ```sql
      select (select count(*) from public.profiles where id like 'phase8-%')
               as leftover_profiles,
             (select allowance_amount from public.allowance_settings where id = 1)
               as allowance_amount;
      ```
- [ ] Keep UnionBank credentials in server-side secrets only.
- [ ] Use fictional data in local and Sandbox environments.
- [ ] Do not enable production transfers until provider approval, UAT, reconciliation, and operational controls are complete.
