-- 005: Cash Out (simulated) hardening.
-- 1) Idempotency key: a repeated request with the same key returns the same Cash Out and does NOT debit again.
-- 2) 'simulated' flag: every demo transfer is stored as "Completed (simulated)" by the server.
-- 3) Status model widened to: pending, processing, completed, failed, cancelled.
--    Old 'rejected' rows become 'failed'. Only 'completed' is used until a real processor exists (Phase 7).
-- 4) request_withdrawal: locks the linked account row, rejects NaN amounts, accepts an optional idempotency key.
-- Depends on 001 (last4 snapshot). One transaction: if anything fails, nothing changes.
-- Rollback (manual): drop index withdrawals_scholar_idempotency_key and withdrawals_reference_unique;
--   update status 'failed' -> 'rejected'; restore constraint withdrawals_status_check
--   (pending, completed, rejected, cancelled); drop columns idempotency_key and simulated;
--   drop the 3-argument request_withdrawal and recreate the 2-argument one from 001_store_account_last4_only.sql.
begin;

-- 1) Columns ------------------------------------------------------------------
alter table public.withdrawals add column if not exists idempotency_key text;
alter table public.withdrawals add column if not exists simulated boolean not null default true;
comment on column public.withdrawals.simulated is
  'true = demo transfer, no real money moved. Every Cash Out is simulated until a real processor is integrated.';

create unique index if not exists withdrawals_scholar_idempotency_key
  on public.withdrawals (scholar_id, idempotency_key)
  where idempotency_key is not null;

create unique index if not exists withdrawals_reference_unique
  on public.withdrawals (reference)
  where reference <> '';

-- 2) Status model -------------------------------------------------------------
alter table public.withdrawals drop constraint if exists withdrawals_status_check;
update public.withdrawals set status = 'failed' where status = 'rejected';
alter table public.withdrawals
  add constraint withdrawals_status_check
  check (status in ('pending', 'processing', 'completed', 'failed', 'cancelled'));

-- 3) request_withdrawal (3 arguments; the key is optional so older calls still work) ---
drop function if exists public.request_withdrawal(bigint, numeric);

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
    'Simulated transfer (demo, no real money)', -p_amount, 'debit', 'completed'
  );

  return v_id;
end;
$$;

-- 4) Permissions (same model as the other RPCs: checks are inside) ----------------
revoke all on function public.request_withdrawal(bigint, numeric, text) from public;
grant execute on function public.request_withdrawal(bigint, numeric, text) to anon, authenticated;

-- 5) Verification (fails and rolls everything back if something is off) ---------
do $$
begin
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
        and proname = 'request_withdrawal') <> 1 then
    raise exception 'request_withdrawal must have exactly one definition';
  end if;
  if (select count(*) from information_schema.columns
       where table_schema = 'public' and table_name = 'withdrawals'
         and column_name in ('idempotency_key', 'simulated')) <> 2 then
    raise exception 'withdrawals columns missing';
  end if;
  if exists (select 1 from public.withdrawals
              where status not in ('pending','processing','completed','failed','cancelled')) then
    raise exception 'withdrawals has an unknown status';
  end if;
  if not (select prosecdef from pg_proc where pronamespace = 'public'::regnamespace
            and proname = 'request_withdrawal') then
    raise exception 'request_withdrawal must be security definer';
  end if;
end
$$;

select
  (select pg_get_function_identity_arguments(oid) from pg_proc
    where pronamespace = 'public'::regnamespace and proname = 'request_withdrawal') as request_withdrawal_args,
  (select count(*) from public.withdrawals where simulated) as simulated_rows,
  (select count(*) from public.withdrawals) as total_rows;

commit;