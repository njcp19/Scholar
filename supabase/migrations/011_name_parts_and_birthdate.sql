-- 011: Split name (last / first / middle) and add birthdate on profiles.
-- 1) New NULLABLE columns on public.profiles: last_name, first_name, middle_name, birthdate.
--    full_name is NOT changed or removed: the app still shows full_name everywhere
--    (the new app will store it as "First Middle Last"). Old accounts keep full_name and have NULL here.
--    No names are guessed or back-filled from full_name.
-- 2) Basic validation (trigger): birthdate cannot be in the future or before 1900-01-01;
--    name parts are trimmed-length checked (1..60) when present.
-- 3) Identity protection (trigger): once a scholar is 'approved', a signed-in NON-admin user cannot change
--    these four columns (an admin can; the SQL editor / owner is not affected). Before approval the scholar
--    can still edit their own row exactly as today.
-- Visibility is unchanged: the same profiles RLS policies apply (the owner and admins can read the row;
--    other scholars cannot). Birthdate is not added to any RPC result, receipt, QR or report by this migration.
-- Old app builds keep working after this migration (columns are optional). The NEW app needs this migration first.
-- Independent of 001-010. One transaction: if anything fails, nothing changes.
-- Rollback (manual): drop trigger trg_profile_identity_validate and trg_profile_identity_guard on public.profiles;
--   drop functions profile_identity_validate, profile_identity_guard;
--   alter table public.profiles drop column last_name, drop column first_name,
--     drop column middle_name, drop column birthdate;
begin;

-- 1) Columns -------------------------------------------------------------------
alter table public.profiles add column if not exists last_name text;
alter table public.profiles add column if not exists first_name text;
alter table public.profiles add column if not exists middle_name text;
alter table public.profiles add column if not exists birthdate date;

-- 2) Validation ----------------------------------------------------------------
create or replace function public.profile_identity_validate() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.birthdate is not null
     and (new.birthdate > current_date or new.birthdate < date '1900-01-01') then
    raise exception 'INVALID_BIRTHDATE';
  end if;
  if new.last_name is not null and length(btrim(new.last_name)) not between 1 and 60 then
    raise exception 'INVALID_NAME_PART';
  end if;
  if new.first_name is not null and length(btrim(new.first_name)) not between 1 and 60 then
    raise exception 'INVALID_NAME_PART';
  end if;
  if new.middle_name is not null and length(btrim(new.middle_name)) not between 1 and 60 then
    raise exception 'INVALID_NAME_PART';
  end if;
  return new;
end; $$;

drop trigger if exists trg_profile_identity_validate on public.profiles;
create trigger trg_profile_identity_validate
  before insert or update of last_name, first_name, middle_name, birthdate on public.profiles
  for each row execute function public.profile_identity_validate();

-- 3) Identity protection after approval -----------------------------------------
create or replace function public.profile_identity_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (new.last_name is distinct from old.last_name
      or new.first_name is distinct from old.first_name
      or new.middle_name is distinct from old.middle_name
      or new.birthdate is distinct from old.birthdate)
     and old.verification_status = 'approved'
     and public.wallet_uid() is not null
     and not public.wallet_is_admin() then
    raise exception 'IDENTITY_FIELDS_PROTECTED';
  end if;
  return new;
end; $$;

drop trigger if exists trg_profile_identity_guard on public.profiles;
create trigger trg_profile_identity_guard
  before update of last_name, first_name, middle_name, birthdate on public.profiles
  for each row execute function public.profile_identity_guard();

revoke all on function public.profile_identity_validate() from public, anon, authenticated;
revoke all on function public.profile_identity_guard() from public, anon, authenticated;

-- Verification (fails and rolls everything back if something is off) --------------
do $$
begin
  if (select count(*) from information_schema.columns
       where table_schema = 'public' and table_name = 'profiles'
         and column_name in ('last_name', 'first_name', 'middle_name', 'birthdate')) <> 4 then
    raise exception 'identity columns missing';
  end if;
  if (select count(*) from pg_trigger
       where tgrelid = 'public.profiles'::regclass
         and tgname in ('trg_profile_identity_validate', 'trg_profile_identity_guard')) <> 2 then
    raise exception 'identity triggers missing';
  end if;
  if (select data_type from information_schema.columns
       where table_schema = 'public' and table_name = 'profiles' and column_name = 'birthdate') <> 'date' then
    raise exception 'birthdate must be date';
  end if;
end
$$;

select
  (select count(*) from information_schema.columns
     where table_schema = 'public' and table_name = 'profiles'
       and column_name in ('last_name', 'first_name', 'middle_name', 'birthdate')) as columns_expected_4,
  (select count(*) from pg_trigger
     where tgrelid = 'public.profiles'::regclass
       and tgname in ('trg_profile_identity_validate', 'trg_profile_identity_guard')) as triggers_expected_2,
  (select count(*) from public.profiles where birthdate is not null) as existing_birthdates_expected_0;

commit;