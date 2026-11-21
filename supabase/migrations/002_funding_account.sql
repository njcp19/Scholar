-- 002: Funding account + fund ledger (simulated top-ups, last4 only).
-- Independent of 001; run order does not matter. Safe to run more than once (create if not exists / create or replace).
-- Whole file is one transaction: if anything fails, nothing is changed.
-- Rollback (manual): drop trigger trg_fund_ledger_claim on public.allowance_claims;
--   restore the previous issue_verified_payout definition (2-argument version); drop the 5 funding functions
--   and fund_ledger_on_claim; drop tables fund_ledger and funding_account.
begin;

-- 1) Tables --------------------------------------------------------------
create table if not exists public.funding_account (
  id int primary key default 1 check (id = 1),
  bank_name text not null,
  account_name text not null,
  account_last4 text not null,
  linked_by text,
  linked_at timestamptz not null default now()
);

create table if not exists public.fund_ledger (
  id bigserial primary key,
  kind text not null check (kind in ('topup','reserve','release','disburse')),
  amount numeric not null check (amount > 0),
  batch_id text,
  note text,
  created_by text,
  created_at timestamptz not null default now()
);

alter table public.funding_account enable row level security;
alter table public.fund_ledger enable row level security;
-- No policies on purpose: no direct access, only the RPCs below.

-- Supabase gives new public tables default grants to anon/authenticated. Remove them.
revoke all on table public.funding_account from public, anon, authenticated;
revoke all on table public.fund_ledger from public, anon, authenticated;
revoke all on sequence public.fund_ledger_id_seq from public, anon, authenticated;

-- 2) RPCs (admin only, checked inside) ------------------------------------
create or replace function public.link_funding_account(p_bank text, p_name text, p_number text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_digits text := regexp_replace(coalesce(p_number, ''), '\D', '', 'g');
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if length(trim(coalesce(p_bank, ''))) = 0
     or length(trim(coalesce(p_name, ''))) = 0
     or length(v_digits) < 6 or length(v_digits) > 20
    then raise exception 'INVALID_ACCOUNT'; end if;
  insert into public.funding_account(id, bank_name, account_name, account_last4, linked_by)
  values (1, trim(p_bank), trim(p_name), right(v_digits, 4), public.wallet_uid())
  on conflict (id) do update
    set bank_name = excluded.bank_name, account_name = excluded.account_name,
        account_last4 = excluded.account_last4, linked_by = excluded.linked_by,
        linked_at = now();
end; $$;

create or replace function public.get_funding_account() returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  return (select to_jsonb(f) from public.funding_account f where id = 1);
end; $$;

create or replace function public.fund_topup(p_amount numeric) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 or p_amount > 100000000
     or p_amount <> round(p_amount, 2) then
    raise exception 'INVALID_AMOUNT';
  end if;
  if not exists (select 1 from public.funding_account) then
    raise exception 'FUNDING_ACCOUNT_REQUIRED';
  end if;
  -- Serialize with payout issuing so balances are never read half-written.
  perform pg_advisory_xact_lock(hashtext('fund_ledger'));
  insert into public.fund_ledger(kind, amount, note, created_by)
  values ('topup', p_amount, 'Simulated top-up', public.wallet_uid());
end; $$;

create or replace function public.get_fund_summary() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t numeric; r numeric; rel numeric; d numeric;
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select coalesce(sum(amount) filter (where kind = 'topup'), 0),
         coalesce(sum(amount) filter (where kind = 'reserve'), 0),
         coalesce(sum(amount) filter (where kind = 'release'), 0),
         coalesce(sum(amount) filter (where kind = 'disburse'), 0)
    into t, r, rel, d from public.fund_ledger;
  return jsonb_build_object('available', t - r + rel, 'reserved', r - rel - d, 'disbursed', d);
end; $$;

create or replace function public.get_fund_activity(p_limit int default 30)
returns setof public.fund_ledger
language plpgsql security definer set search_path = '' as $$
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  return query
    select * from public.fund_ledger
     order by created_at desc, id desc
     limit least(greatest(coalesce(p_limit, 30), 1), 100);
end; $$;

-- 3) Trigger: received -> disburse, voided -> release -----------------------
-- Only for batches that actually reserved funds (older payouts issued before
-- this migration have no reserve row, so they must not create ledger rows).
create or replace function public.fund_ledger_on_claim() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'issued'
     and exists (select 1 from public.fund_ledger
                  where kind = 'reserve' and batch_id = new.batch_id) then
    if new.status = 'received' then
      insert into public.fund_ledger(kind, amount, batch_id, note)
      values ('disburse', new.amount, new.batch_id, 'Payout received');
    elsif new.status = 'voided' then
      insert into public.fund_ledger(kind, amount, batch_id, note)
      values ('release', new.amount, new.batch_id, 'Payout cancelled');
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists trg_fund_ledger_claim on public.allowance_claims;
create trigger trg_fund_ledger_claim
  after update of status on public.allowance_claims
  for each row execute function public.fund_ledger_on_claim();

-- 4) issue_verified_payout: funding-aware, 3-argument version used by the app ----
-- The live database still has the old 2-argument function, but the app sends
-- p_distribution_date. So this section (a) makes sure the distribution_date
-- columns exist (same as supabase_setup.sql), (b) drops the old 2-argument function
-- and (c) creates the 3-argument function with the funding checks.
alter table public.disbursements add column if not exists distribution_date date;
update public.disbursements set distribution_date = created_at::date where distribution_date is null;
alter table public.disbursements alter column distribution_date set default current_date;
alter table public.disbursements alter column distribution_date set not null;

alter table public.allowance_claims add column if not exists distribution_date date;
update public.allowance_claims c
   set distribution_date = d.distribution_date
  from public.disbursements d
 where c.batch_id = d.id and c.distribution_date is null;

drop function if exists public.issue_verified_payout(text, text[]);
create or replace function public.issue_verified_payout(
  p_title text,
  p_recipients text[],
  p_distribution_date date default current_date
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_batch text := gen_random_uuid()::text; v_amount numeric; v_title text;
  v_ids text[]; v_id text; v_profile public.profiles; v_result jsonb;
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select array_agg(distinct x order by x) into v_ids from unnest(p_recipients) x;
  if coalesce(array_length(v_ids,1),0) = 0 then raise exception 'RECIPIENTS_REQUIRED'; end if;
  select allowance_amount, coalesce(nullif(trim(p_title),''),label)
    into v_amount,v_title from public.allowance_settings where id = 1 for share;
  if v_amount is null or v_amount <= 0 then raise exception 'INVALID_ALLOWANCE'; end if;
  -- FUNDING: one payout at a time may read and reserve funds.
  perform pg_advisory_xact_lock(hashtext('fund_ledger'));
  -- FUNDING: a linked funding account is required.
  if not exists (select 1 from public.funding_account) then
    raise exception 'FUNDING_ACCOUNT_REQUIRED';
  end if;
  -- FUNDING: available fund must cover every recipient.
  if (select coalesce(sum(case kind when 'topup' then amount when 'release' then amount
                                    when 'reserve' then -amount else 0 end), 0)
        from public.fund_ledger) < v_amount * array_length(v_ids,1) then
    raise exception 'INSUFFICIENT_FUNDS';
  end if;
  foreach v_id in array v_ids loop
    select * into v_profile from public.profiles where id = v_id for update;
    if not found or v_profile.role <> 'scholar' or
      v_profile.verification_status <> 'approved' or not v_profile.is_active then
      raise exception 'SCHOLAR_NOT_VERIFIED';
    end if;
  end loop;
  insert into public.disbursements(
    id,title,amount_per_scholar,recipient_count,status,distribution_date
  )
    values(
      v_batch,v_title,v_amount,array_length(v_ids,1),'issued',
      coalesce(p_distribution_date,current_date)
    );
  -- FUNDING: reserve the money for this Payout Event.
  insert into public.fund_ledger(kind, amount, batch_id, note, created_by)
    values ('reserve', v_amount * array_length(v_ids,1), v_batch,
            'Payout Event issued', public.wallet_uid());
  insert into public.allowance_claims(
    batch_id,batch_title,scholar_id,amount,token,status,distribution_date
  )
    select v_batch,v_title,x,v_amount,replace(gen_random_uuid()::text,'-',''),
      'issued',coalesce(p_distribution_date,current_date)
      from unnest(v_ids) x;
  select jsonb_agg(to_jsonb(c) || jsonb_build_object('scholar_name', p.full_name))
    into v_result from public.allowance_claims c join public.profiles p on p.id = c.scholar_id
    where c.batch_id = v_batch;
  return v_result;
end;
$$;

-- 5) Function permissions (same model as the existing RPCs: checks are inside) --
revoke all on function public.link_funding_account(text, text, text) from public;
revoke all on function public.get_funding_account() from public;
revoke all on function public.fund_topup(numeric) from public;
revoke all on function public.get_fund_summary() from public;
revoke all on function public.get_fund_activity(int) from public;
revoke all on function public.fund_ledger_on_claim() from public, anon, authenticated;

grant execute on function public.link_funding_account(text, text, text) to anon, authenticated;
grant execute on function public.get_funding_account() to anon, authenticated;
grant execute on function public.fund_topup(numeric) to anon, authenticated;
grant execute on function public.get_fund_summary() to anon, authenticated;
grant execute on function public.get_fund_activity(int) to anon, authenticated;
revoke all on function public.issue_verified_payout(text, text[], date) from public;
grant execute on function public.issue_verified_payout(text, text[], date) to anon, authenticated;

-- 6) Verification (fails and rolls everything back if something is off) -----
do $$
begin
  if to_regclass('public.funding_account') is null or to_regclass('public.fund_ledger') is null then
    raise exception 'Funding tables missing';
  end if;
  if not (select relrowsecurity from pg_class where oid = 'public.funding_account'::regclass)
     or not (select relrowsecurity from pg_class where oid = 'public.fund_ledger'::regclass) then
    raise exception 'RLS not enabled on funding tables';
  end if;
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
        and proname = 'issue_verified_payout') <> 1 then
    raise exception 'issue_verified_payout must have exactly one definition';
  end if;
  if has_table_privilege('anon', 'public.fund_ledger', 'select')
     or has_table_privilege('authenticated', 'public.fund_ledger', 'select')
     or has_table_privilege('anon', 'public.funding_account', 'select')
     or has_table_privilege('authenticated', 'public.funding_account', 'select') then
    raise exception 'Funding tables are still readable directly';
  end if;
end
$$;

select
  (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
     and proname in ('link_funding_account','get_funding_account','fund_topup',
                     'get_fund_summary','get_fund_activity','fund_ledger_on_claim')) as funding_functions_expected_6,
  to_regclass('public.funding_account') as funding_account_table,
  to_regclass('public.fund_ledger') as fund_ledger_table;

commit;
