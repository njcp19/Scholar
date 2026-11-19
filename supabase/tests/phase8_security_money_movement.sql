-- Phase 8 checks for an isolated, rollback-only run in Supabase SQL Editor.
-- Run the entire file as the database owner (normally postgres), then inspect
-- the PASS/FAIL notices. Every fixture and setting is rolled back at the end.
begin;

do $$
declare
  v_scholar text := 'phase8-scholar-' || replace(gen_random_uuid()::text, '-', '');
  v_other text := 'phase8-other-' || replace(gen_random_uuid()::text, '-', '');
  v_cashout_scholar text := 'phase8-cashout-' || replace(gen_random_uuid()::text, '-', '');
  v_admin text := 'phase8-admin-' || replace(gen_random_uuid()::text, '-', '');
  v_account_id bigint;
  v_claim_token text := replace(gen_random_uuid()::text, '-', '');
begin
  insert into public.profiles(id, full_name, email, role, balance, is_active,
                              verification_status)
  values
    (v_scholar, 'Phase 8 Scholar', v_scholar || '@test.invalid',
     'scholar', 0, false, 'pending'),
    (v_other, 'Phase 8 Other Scholar', v_other || '@test.invalid',
     'scholar', 0, false, 'pending'),
    (v_cashout_scholar, 'Phase 8 Cash Out Scholar',
     v_cashout_scholar || '@test.invalid', 'scholar', 5000, true, 'approved'),
    (v_admin, 'Phase 8 Admin', v_admin || '@test.invalid',
     'admin', 0, true, 'approved');

  insert into public.linked_accounts(
    scholar_id, provider, bank_name, account_name, account_number
  )
  values (v_cashout_scholar, 'gcash', '', 'Phase 8 Cash Out Scholar', '1234')
  returning id into v_account_id;

  insert into public.allowance_claims(
    batch_id, batch_title, scholar_id, amount, token, status
  )
  values (
    'phase8-' || replace(gen_random_uuid()::text, '-', ''),
    'Phase 8 duplicate-claim test', v_cashout_scholar, 250, v_claim_token, 'issued'
  );

  if not exists (select 1 from public.funding_account where id = 1) then
    insert into public.funding_account(id, bank_name, account_name, account_last4)
    values (1, 'Phase 8 Test Bank', 'Phase 8 Test Account', '0000');
  end if;

  perform set_config('phase8.scholar_id', v_scholar, true);
  perform set_config('phase8.other_scholar_id', v_other, true);
  perform set_config('phase8.cashout_scholar_id', v_cashout_scholar, true);
  perform set_config('phase8.admin_id', v_admin, true);
  perform set_config('phase8.account_id', v_account_id::text, true);
  perform set_config('phase8.claim_token', v_claim_token, true);
  perform set_config(
    'phase8.idempotency_key',
    'phase8-' || replace(gen_random_uuid()::text, '-', ''),
    true
  );
end
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', current_setting('phase8.scholar_id'),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    if exists (
      select 1 from public.profiles
       where id = current_setting('phase8.other_scholar_id')
    ) then
      raise exception 'Other scholar profile was visible.';
    end if;
    raise notice 'PASS: scholar cannot read another scholar profile';
  exception when others then
    raise notice 'FAIL: scholar cannot read another scholar profile - %', sqlerrm;
  end;
end
$$;

do $$
begin
  begin
    update public.profiles
       set verification_status = 'approved', is_active = true
     where id = current_setting('phase8.scholar_id');
    raise exception 'Self-approval update unexpectedly succeeded.';
  exception
    when insufficient_privilege then
      raise notice 'PASS: scholar cannot approve their own profile';
    when others then
      raise notice 'FAIL: scholar cannot approve their own profile - %', sqlerrm;
  end;
end
$$;

do $$
begin
  begin
    update public.profiles
       set balance = balance + 1
     where id = current_setting('phase8.scholar_id');
    raise exception 'Balance update unexpectedly succeeded.';
  exception
    when insufficient_privilege then
      raise notice 'PASS: scholar cannot change their balance';
    when others then
      raise notice 'FAIL: scholar cannot change their balance - %', sqlerrm;
  end;
end
$$;

do $$
begin
  begin
    perform public.set_verified_scholar_active(
      current_setting('phase8.scholar_id'), true
    );
    raise exception 'Admin RPC unexpectedly succeeded for a scholar.';
  exception
    when insufficient_privilege then
      raise notice 'PASS: scholar cannot successfully call an admin RPC';
    when others then
      if sqlerrm = 'ADMIN_REQUIRED' then
        raise notice 'PASS: scholar cannot successfully call an admin RPC';
      else
        raise notice 'FAIL: scholar cannot successfully call an admin RPC - %',
          sqlerrm;
      end if;
  end;
end
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', current_setting('phase8.cashout_scholar_id'),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare
  v_amount numeric;
begin
  begin
    v_amount := public.claim_allowance(
      current_setting('phase8.claim_token'),
      current_setting('phase8.cashout_scholar_id')
    );
    if v_amount <> 250 then
      raise exception 'First claim returned an unexpected amount.';
    end if;

    begin
      perform public.claim_allowance(
        current_setting('phase8.claim_token'),
        current_setting('phase8.cashout_scholar_id')
      );
      raise exception 'Duplicate claim unexpectedly succeeded.';
    exception when others then
      if sqlerrm = 'CLAIM_ALREADY_RECEIVED' then
        raise notice 'PASS: duplicate claim is rejected';
      else
        raise exception 'Duplicate-claim check failed: %', sqlerrm;
      end if;
    end;
  exception when others then
    raise notice 'FAIL: duplicate claim is rejected - %', sqlerrm;
  end;
end
$$;

do $$
declare
  v_balance_before numeric;
  v_balance_after numeric;
  v_withdrawals_before bigint;
  v_withdrawals_after bigint;
  v_debits_before bigint;
  v_debits_after bigint;
  v_first_id bigint;
  v_retry_id bigint;
  v_account_id bigint := current_setting('phase8.account_id')::bigint;
  v_amount numeric := 100;
  v_key text := current_setting('phase8.idempotency_key');
begin
  begin
    select balance into v_balance_before
      from public.profiles
     where id = current_setting('phase8.cashout_scholar_id');
    select count(*) into v_withdrawals_before
      from public.withdrawals
     where scholar_id = current_setting('phase8.cashout_scholar_id')
       and idempotency_key = v_key;
    select count(*) into v_debits_before
      from public.transactions
     where scholar_id = current_setting('phase8.cashout_scholar_id')
       and type = 'debit' and title = 'Cash-out to GCash';

    v_first_id := public.request_withdrawal(v_account_id, v_amount, v_key);
    v_retry_id := public.request_withdrawal(v_account_id, v_amount, v_key);

    select balance into v_balance_after
      from public.profiles
     where id = current_setting('phase8.cashout_scholar_id');
    select count(*) into v_withdrawals_after
      from public.withdrawals
     where scholar_id = current_setting('phase8.cashout_scholar_id')
       and idempotency_key = v_key;
    select count(*) into v_debits_after
      from public.transactions
     where scholar_id = current_setting('phase8.cashout_scholar_id')
       and type = 'debit' and title = 'Cash-out to GCash';

    if v_first_id <> v_retry_id
       or v_balance_before - v_balance_after <> v_amount
       or v_withdrawals_after - v_withdrawals_before <> 1
       or v_debits_after - v_debits_before <> 1 then
      raise exception 'Retry did not return one request and one debit.';
    end if;
    raise notice 'PASS: Cash Out retry with the same key debits only once';
  exception when others then
    raise notice 'FAIL: Cash Out retry with the same key debits only once - %',
      sqlerrm;
  end;
end
$$;

reset role;

update public.allowance_settings
   set allowance_amount = 1e100
 where id = 1;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', current_setting('phase8.admin_id'),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.issue_verified_payout(
      'Phase 8 insufficient-funds test',
      array[current_setting('phase8.cashout_scholar_id')],
      current_date
    );
    raise exception 'Payout unexpectedly succeeded with an unaffordable amount.';
  exception when others then
    if sqlerrm = 'INSUFFICIENT_FUNDS' then
      raise notice 'PASS: payout is rejected when funds are insufficient';
    else
      raise notice 'FAIL: payout is rejected when funds are insufficient - %',
        sqlerrm;
    end if;
  end;
end
$$;

reset role;
rollback;
