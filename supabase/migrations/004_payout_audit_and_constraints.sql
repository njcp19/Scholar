-- 004: Payout audit trail + safety constraints.
-- 1) allowance_claims: who issued, when voided, who voided.
-- 2) Trigger stamps voided_at / voided_by automatically (no app change needed for void).
-- 3) fund_ledger entries created by the claim trigger now record who caused them.
-- 4) CHECK constraints: claim amount > 0, profile balance >= 0 (live data checked: 0 violations).
-- Depends on 002 (fund_ledger, issue_verified_payout 3-arg). One transaction.
-- Rollback (manual): drop trigger trg_claim_void_audit on public.allowance_claims;
--   drop function public.claim_void_audit(); drop the two constraints; drop the three new columns;
--   restore fund_ledger_on_claim() and issue_verified_payout() from 002_funding_account.sql.
begin;

-- 1) Columns --------------------------------------------------------------
alter table public.allowance_claims add column if not exists issued_by text;
alter table public.allowance_claims add column if not exists voided_at timestamptz;
alter table public.allowance_claims add column if not exists voided_by text;
-- Existing rows keep NULL: the real issuer/voider of older payouts is not known.

-- 2) Constraints (idempotent) ----------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'allowance_claims_amount_positive'
                    and conrelid = 'public.allowance_claims'::regclass) then
    alter table public.allowance_claims
      add constraint allowance_claims_amount_positive
      check (amount > 0 and amount <> 'NaN'::numeric);
  end if;
  if not exists (select 1 from pg_constraint
                  where conname = 'profiles_balance_nonnegative'
                    and conrelid = 'public.profiles'::regclass) then
    alter table public.profiles
      add constraint profiles_balance_nonnegative
      check (balance >= 0 and balance <> 'NaN'::numeric);
  end if;
end
$$;

-- 3) Void audit: stamp who and when, whatever path changed the status ------
create or replace function public.claim_void_audit() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'voided' and old.status is distinct from 'voided' then
    new.voided_at := now();
    new.voided_by := public.wallet_uid();
  end if;
  return new;
end; $$;

drop trigger if exists trg_claim_void_audit on public.allowance_claims;
create trigger trg_claim_void_audit
  before update of status on public.allowance_claims
  for each row execute function public.claim_void_audit();

-- 4) Ledger trigger: record the actor ------------------------------------------
-- disburse = the scholar who received it; release = the admin who cancelled it.
create or replace function public.fund_ledger_on_claim() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'issued'
     and exists (select 1 from public.fund_ledger
                  where kind = 'reserve' and batch_id = new.batch_id) then
    if new.status = 'received' then
      insert into public.fund_ledger(kind, amount, batch_id, note, created_by)
      values ('disburse', new.amount, new.batch_id, 'Payout received', new.scholar_id);
    elsif new.status = 'voided' then
      insert into public.fund_ledger(kind, amount, batch_id, note, created_by)
      values ('release', new.amount, new.batch_id, 'Payout cancelled', new.voided_by);
    end if;
  end if;
  return new;
end; $$;

-- 5) issue_verified_payout: same as 002, plus issued_by on every claim ---------
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
  perform pg_advisory_xact_lock(hashtext('fund_ledger'));
  if not exists (select 1 from public.funding_account) then
    raise exception 'FUNDING_ACCOUNT_REQUIRED';
  end if;
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
  insert into public.fund_ledger(kind, amount, batch_id, note, created_by)
    values ('reserve', v_amount * array_length(v_ids,1), v_batch,
            'Payout Event issued', public.wallet_uid());
  insert into public.allowance_claims(
    batch_id,batch_title,scholar_id,amount,token,status,distribution_date,issued_by
  )
    select v_batch,v_title,x,v_amount,replace(gen_random_uuid()::text,'-',''),
      'issued',coalesce(p_distribution_date,current_date),public.wallet_uid()
      from unnest(v_ids) x;
  select jsonb_agg(to_jsonb(c) || jsonb_build_object('scholar_name', p.full_name))
    into v_result from public.allowance_claims c join public.profiles p on p.id = c.scholar_id
    where c.batch_id = v_batch;
  return v_result;
end;
$$;

-- 6) Permissions (same model as before: checks are inside the functions) ----------
revoke all on function public.issue_verified_payout(text, text[], date) from public;
grant execute on function public.issue_verified_payout(text, text[], date) to anon, authenticated;
revoke all on function public.claim_void_audit() from public, anon, authenticated;
revoke all on function public.fund_ledger_on_claim() from public, anon, authenticated;

-- 7) Verification (fails and rolls everything back if something is off) -------------
do $$
begin
  if (select count(*) from information_schema.columns
       where table_schema = 'public' and table_name = 'allowance_claims'
         and column_name in ('issued_by','voided_at','voided_by')) <> 3 then
    raise exception 'allowance_claims audit columns missing';
  end if;
  if not exists (select 1 from pg_trigger
                  where tgname = 'trg_claim_void_audit'
                    and tgrelid = 'public.allowance_claims'::regclass) then
    raise exception 'void audit trigger missing';
  end if;
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
        and proname = 'issue_verified_payout') <> 1 then
    raise exception 'issue_verified_payout must have exactly one definition';
  end if;
  if not exists (select 1 from pg_constraint where conname = 'allowance_claims_amount_positive')
     or not exists (select 1 from pg_constraint where conname = 'profiles_balance_nonnegative') then
    raise exception 'constraints missing';
  end if;
end
$$;

select
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'allowance_claims'
      and column_name in ('issued_by','voided_at','voided_by')) as audit_columns_expected_3,
  (select count(*) from pg_constraint
    where conname in ('allowance_claims_amount_positive','profiles_balance_nonnegative')) as constraints_expected_2;

commit;