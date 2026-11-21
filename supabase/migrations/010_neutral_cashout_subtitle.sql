-- 010: Neutral wording for new Cash Out history lines (no "Simulated transfer (demo...)" text).
-- 1) request_withdrawal: IDENTICAL to 005 (same checks, same locking, same idempotency, same balance debit,
--    same 'simulated = true' flag). ONLY change: the transaction subtitle text.
--    New subtitle: 'Cash Out to linked account'.
-- 2) Existing history rows with the old subtitle get the same new subtitle (text only; amounts, balances,
--    status and dates are NOT touched). Remove step 2 if you want old rows unchanged.
-- Note: withdrawals.simulated stays true. The app still shows the prototype notice. No real money moves.
-- Depends on 005. One transaction: if anything fails, nothing changes.
-- Rollback (manual): rerun 005_cashout_idempotency_and_status.sql's function block (create or replace) and
--   update public.transactions set subtitle = 'Simulated transfer (demo, no real money)'
--   where subtitle = 'Cash Out to linked account' and type = 'debit'.
begin;

-- 1) Same function as 005, new subtitle ----------------------------------------
create or replace function public.request_withdrawal(
  p_account_id bigint,
  p_amount numeric,
  p_idempotency_key text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles;
  v_acc public.linked_accounts;
  v_existing public.withdrawals;
  v_key text := nullif(trim(p_idempotency_key), '');
  v_id bigint;
  v_label text;
begin
  -- Lock the scholar's profile first: requests from the same scholar run one at a time.
  select * into v_profile
    from public.profiles
   where id = public.wallet_uid()
   for update;
  if not found or v_profile.role <> 'scholar'
     or v_profile.verification_status <> 'approved'
     or not v_profile.is_active then
    raise exception 'SCHOLAR_NOT_VERIFIED';
  end if;

  -- Same key again = same request. Return the earlier result, change nothing.
  if p_idempotency_key is not null then
    if v_key is null or length(v_key) < 8 or length(v_key) > 100 then
      raise exception 'INVALID_KEY';
    end if;
    select * into v_existing
      from public.withdrawals
     where scholar_id = public.wallet_uid() and idempotency_key = v_key;
    if found then
      if v_existing.amount is distinct from p_amount then
        raise exception 'KEY_REUSED_WITH_DIFFERENT_REQUEST';
      end if;
      return v_existing.id;
    end if;
  end if;

  select * into v_acc
    from public.linked_accounts
   where id = p_account_id
     and scholar_id = public.wallet_uid()
   for share;
  if not found then
    raise exception 'ACCOUNT_NOT_FOUND';
  end if;
  if p_amount is null or p_amount = 'NaN'::numeric or p_amount < 100 then
    raise exception 'BELOW_MINIMUM';
  end if;
  if p_amount <> round(p_amount, 2) then
    raise exception 'BAD_AMOUNT';
  end if;
  if v_profile.balance < p_amount then
    raise exception 'INSUFFICIENT_BALANCE';
  end if;

  insert into public.withdrawals(
    scholar_id, amount, provider, bank_name, account_name, account_number,
    status, reference, processed_at, idempotency_key, simulated
  )
  values (
    public.wallet_uid(), p_amount, v_acc.provider, v_acc.bank_name,
    v_acc.account_name, right(v_acc.account_number, 4), 'completed',
    'SIM-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)),
    now(), v_key, true
  )
  returning id into v_id;

  update public.profiles
     set balance = balance - p_amount
   where id = public.wallet_uid();

  v_label := case v_acc.provider
    when 'gcash' then 'GCash'
    when 'maya' then 'Maya'
    else coalesce(nullif(v_acc.bank_name, ''), 'Bank')
  end;
  insert into public.transactions(
    scholar_id, title, subtitle, amount, type, status
  )
  values (
    public.wallet_uid(), 'Cash-out to ' || v_label,
    'Cash Out to linked account', -p_amount, 'debit', 'completed'
  );

  return v_id;
end;
$$;

revoke all on function public.request_withdrawal(bigint, numeric, text) from public;
grant execute on function public.request_withdrawal(bigint, numeric, text) to anon, authenticated;

-- 2) Old rows: text only --------------------------------------------------------
update public.transactions
   set subtitle = 'Cash Out to linked account'
 where subtitle = 'Simulated transfer (demo, no real money)';

-- Verification (fails and rolls everything back if something is off) --------------
do $$
begin
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
        and proname = 'request_withdrawal') <> 1 then
    raise exception 'request_withdrawal must have exactly one definition';
  end if;
  if not (select prosecdef from pg_proc where pronamespace = 'public'::regnamespace
            and proname = 'request_withdrawal') then
    raise exception 'request_withdrawal must be security definer';
  end if;
  if pg_get_functiondef('public.request_withdrawal(bigint,numeric,text)'::regprocedure) like '%Simulated transfer%' then
    raise exception 'old wording still in function';
  end if;
  if exists (select 1 from public.transactions where subtitle = 'Simulated transfer (demo, no real money)') then
    raise exception 'old subtitle rows remain';
  end if;
end
$$;

select
  (select count(*) from public.transactions where subtitle = 'Cash Out to linked account') as new_subtitle_rows,
  (select count(*) from public.transactions where subtitle like '%Simulated%') as old_rows_expected_0;

commit;