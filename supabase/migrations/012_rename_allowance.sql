-- 012 Rename "Monthly Allowance" to "Allowance" in stored titles (text only).
--
-- What it changes (words only, no amounts, balances, statuses or ids):
--   * allowance_settings.label         -> used as the title of NEW payout events
--   * allowance_settings.label default -> default for a new settings row
--   * disbursements.title              -> Payout Events list
--   * allowance_claims.batch_title     -> My Payouts / Activity Log
--   * transactions.title               -> Transaction History
--
-- It does NOT touch status columns, so the claim and ledger triggers do not fire.
-- Run in a NEW blank SQL editor tab with nothing highlighted.
--
-- Rollback (manual): run the same updates with the two words swapped
--   (replace 'Allowance' back to 'Monthly Allowance' only on rows you want back).

begin;

update public.allowance_settings
   set label = replace(label, 'Monthly Allowance', 'Allowance')
 where label like '%Monthly Allowance%';

alter table public.allowance_settings
  alter column label set default 'Allowance';

update public.disbursements
   set title = replace(title, 'Monthly Allowance', 'Allowance')
 where title like '%Monthly Allowance%';

update public.allowance_claims
   set batch_title = replace(batch_title, 'Monthly Allowance', 'Allowance')
 where batch_title like '%Monthly Allowance%';

update public.transactions
   set title = replace(title, 'Monthly Allowance', 'Allowance')
 where title like '%Monthly Allowance%';

commit;

-- Verify: run in a NEW tab. Every "left_*" value must be 0.
-- select
--   (select count(*) from public.allowance_settings where label like '%Monthly Allowance%')    as left_settings_expected_0,
--   (select count(*) from public.disbursements     where title like '%Monthly Allowance%')     as left_events_expected_0,
--   (select count(*) from public.allowance_claims  where batch_title like '%Monthly Allowance%') as left_claims_expected_0,
--   (select count(*) from public.transactions      where title like '%Monthly Allowance%')     as left_transactions_expected_0,
--   (select label from public.allowance_settings where id = 1)                                  as current_label;