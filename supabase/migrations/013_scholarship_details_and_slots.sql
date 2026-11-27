-- 013 (revised): Scholarship details for each program in the catalog.
--
-- What it adds (all optional, nothing is pre-filled; the admin fills the real values in the app):
--   scholarship_catalog.description         text, up to 600 characters
--   scholarship_catalog.allowance_amount    number, 0 or more: the allowance of THIS scholarship
--   scholarship_catalog.payout_frequency    'monthly' or 'semester'
--   scholarship_catalog.support_from_year   1 to 10: first year level that is supported (for example 1 = 1st year)
--   scholarship_catalog.support_to_year     1 to 10: last year level that is supported (for example 4 = 4th year)
--   scholarship_catalog.slots               whole number, 0 or more (null = no limit set)
--
-- Functions:
--   list_scholarship_catalog(include_inactive)  now also returns the six fields above and slots_taken.
--       slots_taken = approved scholars whose scholarship_name equals the program name (a count only, no personal data).
--       Same permissions as before: anyone can read ACTIVE programs, so the Sign up screen can show the details page.
--       The old app still works: it ignores the extra fields.
--   set_scholarship_program_details(...)        admin only, saves the six fields with checks.
--
-- It does NOT touch balances, payouts, claims, profiles or any money function.
-- The duration is information only. It does not stop a payout.
-- Run in a NEW blank SQL editor tab with nothing highlighted. One transaction: if anything fails, nothing changes.
-- If you already ran the first version of 013 (with duration_months), tell me before running this one.
-- Rollback (manual): drop function set_scholarship_program_details; recreate list_scholarship_catalog from 008;
--   alter table public.scholarship_catalog drop the six columns.

begin;

alter table public.scholarship_catalog
  add column if not exists description text not null default '',
  add column if not exists allowance_amount numeric,
  add column if not exists payout_frequency text,
  add column if not exists support_from_year integer,
  add column if not exists support_to_year integer,
  add column if not exists slots integer;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'scholarship_catalog_description_len') then
    alter table public.scholarship_catalog
      add constraint scholarship_catalog_description_len check (length(description) <= 600);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'scholarship_catalog_amount_nonneg') then
    alter table public.scholarship_catalog
      add constraint scholarship_catalog_amount_nonneg check (allowance_amount is null or allowance_amount >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'scholarship_catalog_frequency_valid') then
    alter table public.scholarship_catalog
      add constraint scholarship_catalog_frequency_valid check (payout_frequency is null or payout_frequency in ('monthly', 'semester'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'scholarship_catalog_years_valid') then
    alter table public.scholarship_catalog
      add constraint scholarship_catalog_years_valid check (
        (support_from_year is null or support_from_year between 1 and 10)
        and (support_to_year is null or support_to_year between 1 and 10)
        and (support_from_year is null or support_to_year is null or support_to_year >= support_from_year));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'scholarship_catalog_slots_nonneg') then
    alter table public.scholarship_catalog
      add constraint scholarship_catalog_slots_nonneg check (slots is null or slots >= 0);
  end if;
end
$$;

-- Clean up the first version of 013 (safe to run when it was never run) -----------------
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'scholarship_catalog'
                and column_name = 'duration_months') then
    if exists (select 1 from public.scholarship_catalog where duration_months is not null) then
      raise exception 'duration_months already has values; tell Claude before running this';
    end if;
    alter table public.scholarship_catalog drop column duration_months;
  end if;
end
$$;
drop function if exists public.set_scholarship_program_details(bigint, text, numeric, text, integer, integer);

-- Read (return type changes, so the old function is dropped first) -------------------
drop function if exists public.list_scholarship_catalog(boolean);

create function public.list_scholarship_catalog(p_include_inactive boolean default false)
returns table (
  id bigint,
  name text,
  is_active boolean,
  description text,
  allowance_amount numeric,
  payout_frequency text,
  support_from_year integer,
  support_to_year integer,
  slots integer,
  slots_taken integer
)
language plpgsql stable security definer set search_path = '' as $$
begin
  return query
  select c.id, c.name, c.is_active, c.description, c.allowance_amount,
         c.payout_frequency, c.support_from_year, c.support_to_year, c.slots,
         (select count(*)::integer
            from public.profiles p
           where p.role = 'scholar'
             and p.verification_status = 'approved'
             and lower(btrim(p.scholarship_name)) = lower(btrim(c.name)))
    from public.scholarship_catalog c
   where c.is_active
      or (coalesce(p_include_inactive, false) and public.wallet_is_admin())
   order by lower(c.name);
end; $$;

-- Admin write ---------------------------------------------------------------------------
create or replace function public.set_scholarship_program_details(
  p_id bigint,
  p_description text,
  p_allowance_amount numeric,
  p_payout_frequency text,
  p_support_from_year integer,
  p_support_to_year integer,
  p_slots integer
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_desc text := btrim(coalesce(p_description, ''));
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_ONLY'; end if;
  if length(v_desc) > 600 then raise exception 'INVALID_DESCRIPTION'; end if;
  if p_allowance_amount is not null and p_allowance_amount < 0 then raise exception 'INVALID_AMOUNT'; end if;
  if p_payout_frequency is not null and p_payout_frequency not in ('monthly', 'semester') then
    raise exception 'INVALID_FREQUENCY';
  end if;
  if (p_support_from_year is not null and (p_support_from_year < 1 or p_support_from_year > 10))
     or (p_support_to_year is not null and (p_support_to_year < 1 or p_support_to_year > 10))
     or (p_support_from_year is not null and p_support_to_year is not null
         and p_support_to_year < p_support_from_year) then
    raise exception 'INVALID_YEARS';
  end if;
  if p_slots is not null and p_slots < 0 then raise exception 'INVALID_SLOTS'; end if;

  update public.scholarship_catalog
     set description = v_desc,
         allowance_amount = p_allowance_amount,
         payout_frequency = p_payout_frequency,
         support_from_year = p_support_from_year,
         support_to_year = p_support_to_year,
         slots = p_slots,
         updated_at = now()
   where id = p_id;
  if not found then raise exception 'NOT_FOUND'; end if;
end; $$;

-- Permissions (same model as 008: the checks are inside the functions) -----------------
revoke all on function public.list_scholarship_catalog(boolean) from public;
revoke all on function public.set_scholarship_program_details(bigint, text, numeric, text, integer, integer, integer) from public;
grant execute on function public.list_scholarship_catalog(boolean) to anon, authenticated;
grant execute on function public.set_scholarship_program_details(bigint, text, numeric, text, integer, integer, integer) to anon, authenticated;

-- Verification (fails and rolls everything back if something is off) --------------------
do $$
begin
  if (select count(*) from information_schema.columns
       where table_schema = 'public' and table_name = 'scholarship_catalog'
         and column_name in ('description', 'allowance_amount', 'payout_frequency',
                             'support_from_year', 'support_to_year', 'slots')) <> 6 then
    raise exception 'catalog columns missing';
  end if;
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
       and proname in ('list_scholarship_catalog', 'set_scholarship_program_details')) <> 2 then
    raise exception 'catalog functions missing';
  end if;
  if has_table_privilege('anon', 'public.scholarship_catalog', 'select')
     or has_table_privilege('authenticated', 'public.scholarship_catalog', 'select') then
    raise exception 'scholarship_catalog must not be readable directly';
  end if;
end
$$;

select
  (select count(*) from information_schema.columns
     where table_schema = 'public' and table_name = 'scholarship_catalog'
       and column_name in ('description', 'allowance_amount', 'payout_frequency',
                           'support_from_year', 'support_to_year', 'slots')) as columns_expected_6,
  (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
     and proname in ('list_scholarship_catalog', 'set_scholarship_program_details')) as functions_expected_2,
  (select count(*) from public.scholarship_catalog) as programs_unchanged;

commit;