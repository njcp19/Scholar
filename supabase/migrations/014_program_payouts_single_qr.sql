-- 014: Payout per scholarship program + ONE admin-only QR per payout event.
-- * Amount comes from scholarship_catalog.allowance_amount of the chosen program.
-- * Each program has a total budget (program_budget, optional). Payouts draw it down; voids give it back.
--   NULL budget = no limit set.
-- * Roster = approved + active scholars whose profiles.scholarship_name = program.
-- * One event QR (token) is stored in a table nobody can read directly; only admin RPCs return it.
-- * Scholar claims by scanning that QR: claim_event_allowance(event_token, own id).
-- * Legacy per-scholar tokens are refused for program events (claim_allowance -> CLAIM_USE_EVENT_QR).
-- Old issue_verified_payout (3 args) is left untouched. One transaction; fails and rolls back on any problem.
-- Rollback (manual): drop the 5 new functions, drop table public.payout_event_tokens,
--   drop column disbursements.program_name, restore claim_allowance from its previous definition.
begin;

-- 0) Preconditions ---------------------------------------------------------
do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema='public' and table_name='profiles' and column_name='scholarship_name') then
    raise exception 'profiles.scholarship_name not found - send me the real column name';
  end if;
  if not exists (select 1 from information_schema.columns
                  where table_schema='public' and table_name='scholarship_catalog' and column_name='allowance_amount') then
    raise exception 'scholarship_catalog.allowance_amount missing (013 not applied?)';
  end if;
end $$;

-- 1) Storage ------------------------------------------------------------------
alter table public.disbursements add column if not exists program_name text;
alter table public.scholarship_catalog add column if not exists program_budget numeric;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'scholarship_budget_nonnegative'
                  and conrelid = 'public.scholarship_catalog'::regclass) then
    alter table public.scholarship_catalog add constraint scholarship_budget_nonnegative
      check (program_budget is null or (program_budget >= 0 and program_budget <> 'NaN'::numeric));
  end if;
end $$;

create table if not exists public.payout_event_tokens (
  batch_id text primary key,
  token text not null unique,
  created_at timestamptz not null default now()
);
alter table public.payout_event_tokens enable row level security;   -- no policies = nobody reads it directly
revoke all on public.payout_event_tokens from public, anon, authenticated;

-- 1b) Admin: set a program's total budget (NULL clears it) -------------------------
create or replace function public.set_program_budget(p_program text, p_budget numeric)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if p_budget is not null and (p_budget < 0 or p_budget = 'NaN'::numeric) then
    raise exception 'INVALID_BUDGET';
  end if;
  update public.scholarship_catalog set program_budget = p_budget where name = p_program;
  if not found then raise exception 'NOT_FOUND'; end if;
end; $$;

-- 1c) Admin: budget, used and remaining per program ----------------------------------
-- used = every non-voided claim of events issued for that program (issued + received).
create or replace function public.get_program_budgets()
returns table(program_name text, program_budget numeric, budget_used numeric, budget_remaining numeric)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  return query
    select c.name, c.program_budget,
           coalesce(u.used, 0),
           case when c.program_budget is null then null else c.program_budget - coalesce(u.used, 0) end
      from public.scholarship_catalog c
      left join (select d.program_name as pn, sum(a.amount) as used
                   from public.disbursements d
                   join public.allowance_claims a on a.batch_id = d.id
                  where d.program_name is not null and a.status <> 'voided'
                  group by d.program_name) u on u.pn = c.name
     order by c.name;
end; $$;

-- 2) Admin: roster of a program --------------------------------------------------
create or replace function public.list_program_roster(p_program text)
returns table(id text, full_name text, scholarship_name text)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  return query
    select p.id, p.full_name, p.scholarship_name
      from public.profiles p
     where p.role = 'scholar' and p.verification_status = 'approved' and p.is_active
       and p.scholarship_name = p_program
     order by p.full_name;
end; $$;

-- 3) Admin: approved scholars who match NO active catalog program -------------------
create or replace function public.list_unassigned_scholars()
returns table(id text, full_name text, scholarship_name text)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  return query
    select p.id, p.full_name, p.scholarship_name
      from public.profiles p
     where p.role = 'scholar' and p.verification_status = 'approved' and p.is_active
       and not exists (select 1 from public.scholarship_catalog c where c.name = p.scholarship_name)
     order by p.full_name;
end; $$;

-- 4) Admin: issue a payout event for one program ----------------------------------------
create or replace function public.issue_program_payout(
  p_program text,
  p_title text,
  p_recipients text[],
  p_distribution_date date default current_date
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_batch text := gen_random_uuid()::text; v_amount numeric; v_title text;
  v_ids text[]; v_id text; v_profile public.profiles; v_token text; v_claims jsonb;
  v_budget numeric; v_used numeric;
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select allowance_amount, program_budget into v_amount, v_budget
    from public.scholarship_catalog where name = p_program for share;
  if not found then raise exception 'PROGRAM_NOT_FOUND'; end if;
  if v_amount is null or v_amount <= 0 then raise exception 'PROGRAM_ALLOWANCE_NOT_SET'; end if;
  select array_agg(distinct x order by x) into v_ids from unnest(p_recipients) x;
  if coalesce(array_length(v_ids,1),0) = 0 then raise exception 'RECIPIENTS_REQUIRED'; end if;
  v_title := coalesce(nullif(trim(p_title),''), p_program);
  perform pg_advisory_xact_lock(hashtext('fund_ledger'));
  if not exists (select 1 from public.funding_account) then raise exception 'FUNDING_ACCOUNT_REQUIRED'; end if;
  if v_budget is not null then
    select coalesce(sum(a.amount), 0) into v_used
      from public.disbursements d join public.allowance_claims a on a.batch_id = d.id
     where d.program_name = p_program and a.status <> 'voided';
    if v_budget - v_used < v_amount * array_length(v_ids,1) then
      raise exception 'PROGRAM_BUDGET_EXCEEDED';
    end if;
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
    if v_profile.scholarship_name is distinct from p_program then
      raise exception 'SCHOLAR_NOT_IN_PROGRAM';
    end if;
  end loop;

  insert into public.disbursements(id,title,amount_per_scholar,recipient_count,status,distribution_date,program_name)
    values (v_batch, v_title, v_amount, array_length(v_ids,1), 'issued',
            coalesce(p_distribution_date,current_date), p_program);
  insert into public.fund_ledger(kind, amount, batch_id, note, created_by)
    values ('reserve', v_amount * array_length(v_ids,1), v_batch, 'Payout Event issued', public.wallet_uid());
  insert into public.allowance_claims(batch_id,batch_title,scholar_id,amount,token,status,distribution_date,issued_by)
    select v_batch, v_title, x, v_amount, replace(gen_random_uuid()::text,'-',''),
           'issued', coalesce(p_distribution_date,current_date), public.wallet_uid()
      from unnest(v_ids) x;
  v_token := replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
  insert into public.payout_event_tokens(batch_id, token) values (v_batch, v_token);

  select jsonb_agg(jsonb_build_object('scholar_id', c.scholar_id, 'scholar_name', p.full_name,
                                      'amount', c.amount, 'status', c.status))
    into v_claims
    from public.allowance_claims c join public.profiles p on p.id = c.scholar_id
   where c.batch_id = v_batch;
  return jsonb_build_object('batch_id', v_batch, 'program', p_program, 'title', v_title,
                            'amount_per_scholar', v_amount, 'recipient_count', array_length(v_ids,1),
                            'event_token', v_token, 'recipients', v_claims);
end; $$;

-- 5) Admin: show the QR of an existing event again -------------------------------------------
create or replace function public.get_payout_event_token(p_batch_id text)
returns text language plpgsql security definer set search_path = '' as $$
declare v_token text;
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select token into v_token from public.payout_event_tokens where batch_id = p_batch_id;
  if v_token is null then raise exception 'EVENT_NOT_FOUND'; end if;
  return v_token;
end; $$;

-- 6) Scholar: scan the admin's event QR ----------------------------------------------------------
create or replace function public.claim_event_allowance(p_event_token text, p_scholar_id text)
returns numeric language plpgsql security definer set search_path = '' as $$
declare v_batch text; v_claim public.allowance_claims; v_profile public.profiles;
begin
  if public.wallet_uid() is null or p_scholar_id is distinct from public.wallet_uid() then
    raise exception 'CLAIM_WRONG_SCHOLAR';
  end if;
  select * into v_profile from public.profiles where id = public.wallet_uid() for update;
  if not found or v_profile.role <> 'scholar' or
     v_profile.verification_status <> 'approved' or not v_profile.is_active then
    raise exception 'SCHOLAR_NOT_VERIFIED';
  end if;
  select batch_id into v_batch from public.payout_event_tokens where token = p_event_token;
  if v_batch is null then raise exception 'CLAIM_NOT_FOUND'; end if;
  select * into v_claim from public.allowance_claims
   where batch_id = v_batch and scholar_id = public.wallet_uid() for update;
  if not found then raise exception 'CLAIM_NOT_IN_ROSTER'; end if;
  if v_claim.status = 'received' then raise exception 'CLAIM_ALREADY_RECEIVED'; end if;
  if v_claim.status <> 'issued' then raise exception 'CLAIM_VOIDED'; end if;
  if v_claim.amount <= 0 then raise exception 'INVALID_ALLOWANCE'; end if;
  update public.allowance_claims set status = 'received', claimed_at = now() where id = v_claim.id;
  update public.profiles set balance = balance + v_claim.amount where id = public.wallet_uid();
  insert into public.transactions(scholar_id,title,subtitle,amount,type,status,batch_id)
    values (public.wallet_uid(), v_claim.batch_title, 'Allowance receipt confirmed',
            v_claim.amount, 'credit', 'completed', v_claim.batch_id);
  update public.disbursements d set status = 'completed' where d.id = v_claim.batch_id
    and not exists (select 1 from public.allowance_claims c where c.batch_id = d.id and c.status = 'issued');
  return v_claim.amount;
end; $$;

-- 7) Legacy claim: same as before, but refuses program events ---------------------------------------
create or replace function public.claim_allowance(p_token text, p_scholar_id text)
returns numeric language plpgsql security definer set search_path = '' as $$
declare v_claim public.allowance_claims; v_profile public.profiles;
begin
  if public.wallet_uid() is null or p_scholar_id is distinct from public.wallet_uid() then
    raise exception 'CLAIM_WRONG_SCHOLAR';
  end if;
  select * into v_profile from public.profiles where id = public.wallet_uid() for update;
  if not found or v_profile.role <> 'scholar' or
      v_profile.verification_status <> 'approved' or not v_profile.is_active then
    raise exception 'SCHOLAR_NOT_VERIFIED';
  end if;
  select * into v_claim from public.allowance_claims where token = p_token for update;
  if not found then raise exception 'CLAIM_NOT_FOUND'; end if;
  if v_claim.scholar_id <> public.wallet_uid() then raise exception 'CLAIM_WRONG_SCHOLAR'; end if;
  if exists (select 1 from public.payout_event_tokens where batch_id = v_claim.batch_id) then
    raise exception 'CLAIM_USE_EVENT_QR';
  end if;
  if v_claim.status = 'received' then raise exception 'CLAIM_ALREADY_RECEIVED'; end if;
  if v_claim.status <> 'issued' then raise exception 'CLAIM_VOIDED'; end if;
  if v_claim.amount <= 0 then raise exception 'INVALID_ALLOWANCE'; end if;
  update public.allowance_claims set status = 'received', claimed_at = now() where id = v_claim.id;
  update public.profiles set balance = balance + v_claim.amount where id = public.wallet_uid();
  insert into public.transactions(scholar_id,title,subtitle,amount,type,status,batch_id)
    values(public.wallet_uid(),v_claim.batch_title,'Allowance receipt confirmed',v_claim.amount,'credit','completed',v_claim.batch_id);
  update public.disbursements d set status = 'completed' where d.id = v_claim.batch_id
    and not exists(select 1 from public.allowance_claims c where c.batch_id = d.id and c.status = 'issued');
  return v_claim.amount;
end; $$;

-- 8) Permissions ----------------------------------------------------------------------------------------
revoke all on function public.set_program_budget(text, numeric) from public;
revoke all on function public.get_program_budgets() from public;
grant execute on function public.set_program_budget(text, numeric) to anon, authenticated;
grant execute on function public.get_program_budgets() to anon, authenticated;
revoke all on function public.list_program_roster(text) from public;
revoke all on function public.list_unassigned_scholars() from public;
revoke all on function public.issue_program_payout(text, text, text[], date) from public;
revoke all on function public.get_payout_event_token(text) from public;
revoke all on function public.claim_event_allowance(text, text) from public;
grant execute on function public.list_program_roster(text) to anon, authenticated;
grant execute on function public.list_unassigned_scholars() to anon, authenticated;
grant execute on function public.issue_program_payout(text, text, text[], date) to anon, authenticated;
grant execute on function public.get_payout_event_token(text) to anon, authenticated;
grant execute on function public.claim_event_allowance(text, text) to anon, authenticated;
-- (checks are inside the functions, same model as the existing ones)

-- 9) Verification -------------------------------------------------------------------------------------------
do $$
begin
  if (select count(*) from pg_proc where pronamespace='public'::regnamespace
       and proname in ('list_program_roster','list_unassigned_scholars','issue_program_payout',
                       'get_payout_event_token','claim_event_allowance','claim_allowance',
                       'set_program_budget','get_program_budgets')) <> 8 then
    raise exception 'expected 8 functions';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema='public'
                  and table_name='disbursements' and column_name='program_name') then
    raise exception 'disbursements.program_name missing';
  end if;
  if has_table_privilege('authenticated','public.payout_event_tokens','select') then
    raise exception 'payout_event_tokens must not be readable by app roles';
  end if;
end $$;

select 'ok' as result,
       (select count(*) from information_schema.columns where table_name='scholarship_catalog' and column_name='program_budget') as budget_col_expected_1,
       (select count(*) from public.payout_event_tokens) as events_expected_0;

commit;