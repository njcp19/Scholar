# Scholarship Wallet Security Notes

## Important current limitation

The current demo schema stores payout account numbers in plaintext in both `linked_accounts.account_number` and the withdrawal snapshot `withdrawals.account_number`. These values are not bank-verified, and the current cash-out RPC is a simulation. The app should be used with fictional test account data only.

Do not collect real bank, GCash, or Maya account numbers until a reviewed design is in place. Do not collect online banking passwords, PINs, or OTPs at any stage.

## Required work before real account linking

- Replace raw account-number storage with an approved provider authorization flow and provider-issued account reference where available.
- If a business requirement truly requires storing account data, define an approved encryption/key-management and retention design before collecting it. Do not put encryption keys in Flutter or ordinary database rows.
- Restrict read/write access with verified-user ownership policies and server-side authorization.
- Review every SECURITY DEFINER function for explicit role/ownership checks and a fixed safe search_path.
- Ensure withdrawal history is labeled simulated and cannot be mistaken for a bank-confirmed transfer.
- Remove or securely dispose of any real account details entered during testing, following the project's data-retention policy.

## Development checklist

- [ ] Review Supabase RLS policies for profiles, transactions, linked_accounts, withdrawals, funding_accounts, allowance_claims, and registration_reviews.
- [ ] Review all RPC grants and SECURITY DEFINER function bodies.
- [ ] Confirm Firebase JWT verification and Supabase user identity mapping.
- [ ] Add automated tests for ownership, role boundaries, duplicate claims, and duplicate withdrawal requests.
- [ ] Keep UnionBank credentials in server-side secrets only.
- [ ] Use fictional data in local and Sandbox environments.
- [ ] Do not enable production transfers until provider approval, UAT, reconciliation, and operational controls are complete.
