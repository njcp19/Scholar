-- Store only the last four digits in linked-account and Cash Out history rows.
-- Rollback: restore the prior function definitions and uniqueness constraint;
-- discarded account-number digits cannot be recovered.
begin;

do $$
begin
  if exists (
    select 1
    from public.linked_accounts
    group by scholar_id, provider,
      case
        when length(account_number) > 4 then right(account_number, 4)
        else account_number
      end
    having count(*) > 1
  ) then
    raise exception
      'Cannot migrate linked accounts: multiple rows for one scholar/provider would share the same last four digits.';
  end if;
end
$$;

do $$
declare
  v_constraint text;
begin
  select c.conname
    into v_constraint
    from pg_constraint c
   where c.conrelid = 'public.linked_accounts'::regclass
     and c.contype = 'u'
     and c.conkey = array[
       (select a.attnum from pg_attribute a
         where a.attrelid = 'public.linked_accounts'::regclass
           and a.attname = 'scholar_id' and not a.attisdropped),
       (select a.attnum from pg_attribute a
         where a.attrelid = 'public.linked_accounts'::regclass
           and a.attname = 'provider' and not a.attisdropped),
       (select a.attnum from pg_attribute a
         where a.attrelid = 'public.linked_accounts'::regclass
           and a.attname = 'account_number' and not a.attisdropped)
     ]::smallint[];

  if v_constraint is not null then
    execute format(
      'alter table public.linked_accounts drop constraint %I',
      v_constraint
    );
  end if;
end
$$;

update public.linked_accounts
   set account_number = right(account_number, 4)
 where length(account_number) > 4;

update public.withdrawals
   set account_number = right(account_number, 4)
 where length(account_number) > 4;

-- This schema names the user-ownership column scholar_id.
alter table public.linked_accounts
  add constraint linked_accounts_scholar_provider_account_number_last4_key
  unique (scholar_id, provider, account_number);

comment on column public.linked_accounts.account_number is
  'Stores only the final four digits (last4); the full account number is not retained.';
comment on column public.withdrawals.account_number is
  'Stores only the final four digits (last4); the full account number is not retained.';

create or replace function public.link_account(
  p_provider text, p_bank_name text, p_account_name text, p_account_number text
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_num text := regexp_replace(coalesce(p_account_number, ''), '[^0-9]', '', 'g');
  v_id bigint;
begin
  if public.wallet_uid() is null or not public.wallet_is_verified() then
    raise exception 'SCHOLAR_NOT_VERIFIED';
  end if;
  if p_provider not in ('gcash', 'maya', 'bank') then
    raise exception 'BAD_PROVIDER';
  end if;
  if length(trim(coalesce(p_account_name, ''))) < 2 then
    raise exception 'BAD_ACCOUNT_NAME';
  end if;
  if p_provider in ('gcash', 'maya') and v_num !~ '^09[0-9]{9}$' then
    raise exception 'BAD_MOBILE_NUMBER';
  end if;
  if p_provider = 'bank' then
    if length(trim(coalesce(p_bank_name, ''))) < 2 then
      raise exception 'BAD_BANK_NAME';
    end if;
    if length(v_num) < 8 or length(v_num) > 20 then
      raise exception 'BAD_ACCOUNT_NUMBER';
    end if;
  end if;

  insert into public.linked_accounts(
    scholar_id, provider, bank_name, account_name, account_number
  )
  values (
    public.wallet_uid(), p_provider,
    case when p_provider = 'bank' then trim(p_bank_name) else '' end,
    trim(p_account_name), right(v_num, 4)
  )
  returning id into v_id;

  return v_id;
exception
  when unique_violation then
    raise exception 'ACCOUNT_ALREADY_LINKED';
end;
$$;

create or replace function public.request_withdrawal(
  p_account_id bigint, p_amount numeric
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles;
  v_acc public.linked_accounts;
  v_id bigint;
  v_label text;
begin
  select * into v_profile
    from public.profiles
   where id = public.wallet_uid()
   for update;
  if not found or v_profile.role <> 'scholar'
     or v_profile.verification_status <> 'approved'
     or not v_profile.is_active then
    raise exception 'SCHOLAR_NOT_VERIFIED';
  end if;

  select * into v_acc
    from public.linked_accounts
   where id = p_account_id
     and scholar_id = public.wallet_uid();
  if not found then
    raise exception 'ACCOUNT_NOT_FOUND';
  end if;
  if p_amount is null or p_amount < 100 then
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
    status, reference, processed_at
  )
  values (
    public.wallet_uid(), p_amount, v_acc.provider, v_acc.bank_name,
    v_acc.account_name, right(v_acc.account_number, 4), 'completed',
    'SIM-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)),
    now()
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

-- Reassert the explicit RPC allowlist: no function execution via PUBLIC.
do $$
declare
  f record;
begin
  for f in
    select p.oid::regprocedure as signature
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in (
         'wallet_uid', 'wallet_is_admin', 'wallet_is_verified',
         'review_registration', 'resubmit_registration',
         'set_verified_scholar_active', 'issue_verified_payout',
         'claim_allowance', 'link_account', 'unlink_account',
         'request_withdrawal', 'admin_delete_scholar',
         'admin_delete_inactive_scholars'
       )
  loop
    execute format(
      'revoke all on function %s from public, anon, authenticated',
      f.signature
    );
    execute format(
      'grant execute on function %s to anon, authenticated',
      f.signature
    );
  end loop;
end
$$;

do $$
begin
  if exists (
    select 1 from public.linked_accounts where length(account_number) > 4
  ) or exists (
    select 1 from public.withdrawals where length(account_number) > 4
  ) then
    raise exception 'Account-number masking verification failed.';
  end if;
end
$$;

select
  (select count(*) from public.linked_accounts
    where length(account_number) > 4) as linked_accounts_over_4,
  (select count(*) from public.withdrawals
    where length(account_number) > 4) as withdrawals_over_4;

commit;
