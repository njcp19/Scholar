# UnionBank Integration Readiness

## Current implementation status

The current Scholarship Wallet Withdraw Allowance flow records a simulated
allowance request. Linked payout account details are stored by the app; it does
not authenticate a UnionBank customer or initiate a bank transfer. No real money
moves.

Do not describe a simulated Withdraw Allowance request as a completed bank
transfer. Do not use real student or bank credentials while testing.

## Safe integration boundary

- Flutter must call a trusted server-side function for bank operations.
- UnionBank client secrets and partner credentials must never be included in the Flutter bundle, client-side configuration, or public tables.
- Use the UnionBank Sandbox while developing and testing. Sandbox operations use test data and do not move real funds.
- UAT/Production access depends on UnionBank onboarding, API product access, agreements, and approval.
- Keep in-app allowance credits and recorded allowance requests distinct from any external bank account balance or transaction.
- Never request or store a student's UnionBank online banking password, PIN, or OTP in this application.
- Store only the minimum account-linking information permitted by the approved API and user consent. Prefer provider-issued references and masked display values.

## Planned integration sequence

1. Confirm the scholarship program's authorized funding and payout model.
2. Confirm with UnionBank which API product and customer/partner OAuth flow is applicable.
3. Create server-side Supabase Edge Functions for OAuth callback handling and provider API calls.
4. Store credentials only in server-side secrets; validate redirect state and OAuth responses.
5. Add a bank-link status model with pending, linked, revoked, and failed states.
6. Implement idempotent transfer requests and provider reference reconciliation.
7. Add audit events without logging secrets, tokens, full account numbers, or authentication codes.
8. Test failure, timeout, duplicate-request, cancellation, and reconciliation scenarios in Sandbox.
9. Seek UAT/Production onboarding and authorization before enabling real-money operations.

## Current safe development milestone

Preserve the existing Flutter UI and Supabase data model while auditing
authorization policies and the simulated Withdraw Allowance path. No production
banking calls should be made from the mobile client.
