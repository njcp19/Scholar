-- Phase 8 checks: security + money movement. Rollback-only run for the Supabase SQL Editor.
-- Run the WHOLE file as the database owner (postgres). Nothing is committed: every fixture,
-- setting and balance change is rolled back at the end.
-- The result table (one row per test, PASS/FAIL) is the last thing the editor shows.
-- Afterwards run the leftover check at the bottom of this file (it must return 0).
begin;
set local lock_timeout = '3s';   -- never hang on a busy production row

-- 1) Fixtures (created as owner) --------------------------------------------------
do $$
declare
  v_scholar text := 'phase8-scholar-' || replace(gen_random_uuid()::text, '-', '');
  v_other text := 'phase8-other-' || replace(gen_random_uuid()::text, '-', '');
  v_cashout_scholar text := 'phase8-cashout-' || replace(gen_random_uuid()::text, '-', '');
  v_admin text := 'phase8-admin-' || replace(gen_random_uuid()::text, '-', '');
  v_account_id bigint;
  v_claim_token text := replace(gen_random_uuid()::text, '-', '');
begin
  insert into public.profiles(id, full_name, email, role, balance, is_active, verification_status)
  values
    (v_scholar, 'Phase 8 Scholar', v_scholar || '@test.invalid', 'scholar', 0, false, 'pending'),
    (v_other, 'Phase 8 Other Scholar', v_other || '@test.invalid', 'scholar', 0, false, 'pending'),
    (v_cashout_scholar, 'Phase 8 Cash Out Scholar', v_cashout_scholar || '@test.invalid',
     'scholar', 5000, true, 'approved'),
    (v_admin, 'Phase 8 Admin', v_admin || '@test.invalid', 'admin', 0, true, 'approved');

  insert into public.linked_accounts(scholar_id, provider, bank_name, account_name, account_number)
  values (v_cashout_scholar, 'gcash', '', 'Phase 8 Cash Out Scholar', '1234')
  returning id into v_account_id;

  insert into public.allowance_claims(batch_id, batch_title, scholar_id, amount, token, status)
  values ('phase8-' || replace(gen_random_uuid()::text, '-', ''),
          'Phase 8 duplicate-claim test', v_cashout_scholar, 250, v_claim_token, 'issued');

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
  perform set_config('phase8.idempotency_key',
                     'phase8-' || replace(gen_random_uuid()::text, '-', ''), true);
  perform set_config('phase8.results', '', true);
end
$$;

-- 2) As a plain scholar ------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  jsonb_build_object('sub', current_setting('phase8.scholar_id'), 'role', 'authenticated')::text, true);

do $$
declare v_res text;
begin
  -- CONTROL: the test identity must really resolve, or the next tests prove nothing.
  begin
    if public.wallet_uid() is distinct from current_setting('phase8.scholar_id') then
      raise exception 'wallet_uid() = %, expected the test scholar', coalesce(public.wallet_uid(), 'NULL');
    end if;
    if (select count(*) from public.profiles
         where id = current_setting('phase8.scholar_id')) <> 1 then
      raise exception 'scholar cannot read their OWN profile';
    end if;
    v_res := 'PASS: control - test scholar identity resolves and own profile is readable';
  exception when others then
    v_res := 'FAIL: control - test scholar identity - ' || sqlerrm;
  end;
  perform set_config('phase8.results', current_setting('phase8.results') || v_res || E'\n', true);
end
$$;

do $$
declare v_res text;
begin
  begin
    if exists (select 1 from public.profiles
                where id = current_setting('phase8.other_scholar_id')) then
      raise exception 'Other scholar profile was visible.';
    end if;
    v_res := 'PASS: scholar cannot read another scholar profile';
  exception when others then
    v_res := 'FAIL: scholar cannot read another scholar profile - ' || sqlerrm;
  end;
  perform set_config('phase8.results', current_setting('phase8.results') || v_res || E'\n', true);
end
$$;

do $$
declare v_res text;
begin
  begin
    update public.profiles set verification_status = 'approved', is_active = true
     where id = current_setting('phase8.scholar_id');
    raise exception 'Self-approval update unexpectedly succeeded.';
  exception
    when insufficient_privilege then
      v_res := 'PASS: scholar cannot approve their own profile';
    when others then
      v_res := 'FAIL: scholar cannot approve their own profile - ' || sqlerrm;
  end;
  perform set_config('phase8.results', current_setting('phase8.results') || v_res || E'\n', true);
end
$$;

do $$
declare v_res text;
begin
  begin
    update public.profiles set balance = balance + 1
     where id = current_setting('phase8.scholar_id');
    raise exception 'Balance update unexpectedly succeeded.';
  exception
    when insufficient_privilege then
      v_res := 'PASS: scholar cannot change their balance';
    when others then
      v_res := 'FAIL: scholar cannot change their balance - ' || sqlerrm;
  end;
  perform set_config('phase8.results', current_setting('phase8.results') || v_res || E'\n', true);
end
$$;

do $$
declare v_res text;
begin
  begin
    perform public.set_verified_scholar_active(current_setting('phase8.scholar_id'), true);
    raise exception 'Admin RPC unexpectedly succeeded for a scholar.';
  exception when others then
    if sqlerrm = 'ADMIN_REQUIRED' or sqlstate = '42501' then
      v_res := 'PASS: scholar cannot successfully call an admin RPC';
    else
      v_res := 'FAIL: scholar cannot successfully call an admin RPC - ' || sqlerrm;
    end if;
  end;
  perform set_config('phase8.results', current_setting('phase8.results') || v_res || E'\n', true);
end
$$;

-- 3) As the Cash Out scholar: duplicate claim, then Cash Out retry -------------------
select set_config('request.jwt.claims',
  jsonb_build_object('sub', current_setting('phase8.cashout_scholar_id'), 'role', 'authenticated')::text, true);

do $$
declare v_res text; v_amount numeric; v_balance_before numeric; v_balance_after numeric;
begin
  begin
    select balance into v_balance_before from public.profiles
     where id = current_setting('phase8.cashout_scholar_id');
    v_amount := public.claim_allowance(current_setting('phase8.claim_token'),
                                       current_setting('phase8.cashout_scholar_id'));
    if v_amount <> 250 then raise exception 'First claim returned an unexpected amount.'; end if;
    begin
      perform public.claim_allowance(current_setting('phase8.claim_token'),
                                     current_setting('phase8.cashout_scholar_id'));
      raise exception 'Duplicate claim unexpectedly succeeded.';
    exception when others then
      if sqlerrm <> 'CLAIM_ALREADY_RECEIVED' then
        raise exception 'Duplicate-claim check failed: %', sqlerrm;
      end if;
    end;
    select balance into v_balance_after from public.profiles
     where id = current_setting('phase8.cashout_scholar_id');
    if v_balance_after - v_balance_before <> 250 then
      raise exception 'Balance changed by % instead of 250 once.', v_balance_after - v_balance_before;
    end if;
    v_res := 'PASS: duplicate claim is rejected and the balance is credited only once';
  exception when others then
    v_res := 'FAIL: duplicate claim is rejected - ' || sqlerrm;
  end;
  perform set_config('phase8.results', current_setting('phase8.results') || v_res || E'\n', true);
end
$$;

do $$
declare
  v_res text; v_balance_before numeric; v_balance_after numeric;
  v_withdrawals_before bigint; v_withdrawals_after bigint;
  v_debits_before bigint; v_debits_after bigint;
  v_first_id bigint; v_retry_id bigint;
  v_account_id bigint := current_setting('phase8.account_id')::bigint;
  v_amount numeric := 100;
  v_key text := current_setting('phase8.idempotency_key');
begin
  begin
    select balance into v_balance_before from public.profiles
     where id = current_setting('phase8.cashout_scholar_id');
    select count(*) into v_withdrawals_before from public.withdrawals
     where scholar_id = current_setting('phase8.cashout_scholar_id') and idempotency_key = v_key;
    select count(*) into v_debits_before from public.transactions
     where scholar_id = current_setting('phase8.cashout_scholar_id')
       and type = 'debit' and title = 'Cash-out to GCash';

    v_first_id := public.request_withdrawal(v_account_id, v_amount, v_key);
    v_retry_id := public.request_withdrawal(v_account_id, v_amount, v_key);

    select balance into v_balance_after from public.profiles
     where id = current_setting('phase8.cashout_scholar_id');
    select count(*) into v_withdrawals_after from public.withdrawals
     where scholar_id = current_setting('phase8.cashout_scholar_id') and idempotency_key = v_key;
    select count(*) into v_debits_after from public.transactions
     where scholar_id = current_setting('phase8.cashout_scholar_id')
       and type = 'debit' and title = 'Cash-out to GCash';

    if v_first_id <> v_retry_id
       or v_balance_before - v_balance_after <> v_amount
       or v_withdrawals_after - v_withdrawals_before <> 1
       or v_debits_after - v_debits_before <> 1 then
      raise exception 'Retry did not return one request and one debit.';
    end if;
    v_res := 'PASS: Cash Out retry with the same key debits only once';
  exception when others then
    v_res := 'FAIL: Cash Out retry with the same key debits only once - ' || sqlerrm;
  end;
  perform set_config('phase8.results', current_setting('phase8.results') || v_res || E'\n', true);
end
$$;

do $$
declare v_res text; v_before numeric; v_after numeric; v_count_before bigint; v_count_after bigint;
begin
  -- Same key with a DIFFERENT amount must be refused and must not debit.
  begin
    select balance into v_before from public.profiles
     where id = current_setting('phase8.cashout_scholar_id');
    select count(*) into v_count_before from public.withdrawals
     where scholar_id = current_setting('phase8.cashout_scholar_id');
    begin
      perform public.request_withdrawal(current_setting('phase8.account_id')::bigint, 150,
                                        current_setting('phase8.idempotency_key'));
      raise exception 'Reused key with another amount unexpectedly succeeded.';
    exception when others then
      if sqlerrm <> 'KEY_REUSED_WITH_DIFFERENT_REQUEST' then
        raise exception 'Unexpected error: %', sqlerrm;
      end if;
    end;
    select balance into v_after from public.profiles
     where id = current_setting('phase8.cashout_scholar_id');
    select count(*) into v_count_after from public.withdrawals
     where scholar_id = current_setting('phase8.cashout_scholar_id');
    if v_before <> v_after or v_count_before <> v_count_after then
      raise exception 'Balance or withdrawal count changed.';
    end if;
    v_res := 'PASS: reused key with a different amount is refused, no debit';
  exception when others then
    v_res := 'FAIL: reused key with a different amount - ' || sqlerrm;
  end;
  perform set_config('phase8.results', current_setting('phase8.results') || v_res || E'\n', true);
end
$$;

-- 4) As the admin: payout with insufficient funds ----------------------------------------
reset role;
update public.allowance_settings set allowance_amount = 1e100 where id = 1;  -- rolled back below
set local role authenticated;
select set_config('request.jwt.claims',
  jsonb_build_object('sub', current_setting('phase8.admin_id'), 'role', 'authenticated')::text, true);

do $$
declare v_res text;
begin
  begin
    if not public.wallet_is_admin() then
      raise exception 'control failed: wallet_is_admin() is false for the admin fixture';
    end if;
    perform public.issue_verified_payout('Phase 8 insufficient-funds test',
      array[current_setting('phase8.cashout_scholar_id')], current_date);
    raise exception 'Payout unexpectedly succeeded with an unaffordable amount.';
  exception when others then
    if sqlerrm = 'INSUFFICIENT_FUNDS' then
      v_res := 'PASS: payout is rejected when funds are insufficient';
    else
      v_res := 'FAIL: payout is rejected when funds are insufficient - ' || sqlerrm;
    end if;
  end;
  perform set_config('phase8.results', current_setting('phase8.results') || v_res || E'\n', true);
end
$$;

-- 5) Show the results, then roll everything back -----------------------------------------
reset role;
select t.n as test_no, t.line as result
  from regexp_split_to_table(current_setting('phase8.results'), E'\n')
       with ordinality as t(line, n)
 where t.line <> ''
 order by t.n;

rollback;

-- 6) AFTER the run, in a NEW tab: this must return 0 and the allowance must be your normal value.
-- select (select count(*) from public.profiles where id like 'phase8-%') as leftover_profiles,
--        (select allowance_amount from public.allowance_settings where id = 1) as allowance_amount;