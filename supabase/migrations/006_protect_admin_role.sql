-- 006: A role stays what it was registered as. Protect roles and audit every change.
-- 1) Table profile_role_audit: every role change on public.profiles is recorded
--    (who, from where, when). No direct access; read it as the database owner.
-- 2) The role can no longer be changed (scholar <-> admin) and an admin can no longer be deleted
--    by accident. A deliberate change must first run, in the same transaction:
--        set local app.allow_role_change = 'on';
--    Sign up always creates a scholar; an admin is made only on purpose, with that line.
-- Independent of 001-005. One transaction: if anything fails, nothing changes.
-- Rollback (manual): drop trigger trg_profile_role_guard and trg_profile_admin_delete_guard on public.profiles;
--   drop functions public.profile_role_guard() and public.profile_admin_delete_guard(); drop table public.profile_role_audit.
begin;

create table if not exists public.profile_role_audit (
  id bigserial primary key,
  profile_id text not null,
  email text,
  old_role text,
  new_role text,
  changed_by text,          -- Firebase UID when the change came through the API (NULL for SQL editor)
  db_user text not null default current_user,
  app_name text,            -- e.g. the SQL editor, PostgREST, a client tool
  changed_at timestamptz not null default now()
);
alter table public.profile_role_audit enable row level security;
revoke all on table public.profile_role_audit from public, anon, authenticated;
revoke all on sequence public.profile_role_audit_id_seq from public, anon, authenticated;

create or replace function public.profile_role_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.role is distinct from old.role then
    if coalesce(current_setting('app.allow_role_change', true), '') <> 'on' then
      raise exception 'ROLE_CHANGE_BLOCKED: run "set local app.allow_role_change = ''on''" first if this is intentional';
    end if;
    insert into public.profile_role_audit(profile_id, email, old_role, new_role, changed_by, app_name)
    values (old.id, old.email, old.role, new.role, public.wallet_uid(),
            current_setting('application_name', true));
  end if;
  return new;
end; $$;

drop trigger if exists trg_profile_role_guard on public.profiles;
create trigger trg_profile_role_guard
  before update of role on public.profiles
  for each row execute function public.profile_role_guard();

create or replace function public.profile_admin_delete_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.role = 'admin'
     and coalesce(current_setting('app.allow_role_change', true), '') <> 'on' then
    raise exception 'ADMIN_DELETE_BLOCKED: run "set local app.allow_role_change = ''on''" first if this is intentional';
  end if;
  return old;
end; $$;

drop trigger if exists trg_profile_admin_delete_guard on public.profiles;
create trigger trg_profile_admin_delete_guard
  before delete on public.profiles
  for each row execute function public.profile_admin_delete_guard();

revoke all on function public.profile_role_guard() from public, anon, authenticated;
revoke all on function public.profile_admin_delete_guard() from public, anon, authenticated;

-- Verification (fails and rolls everything back if something is off)
do $$
begin
  if to_regclass('public.profile_role_audit') is null then
    raise exception 'profile_role_audit missing';
  end if;
  if (select count(*) from pg_trigger
       where tgrelid = 'public.profiles'::regclass
         and tgname in ('trg_profile_role_guard', 'trg_profile_admin_delete_guard')) <> 2 then
    raise exception 'admin guard triggers missing';
  end if;
  if has_table_privilege('anon', 'public.profile_role_audit', 'select')
     or has_table_privilege('authenticated', 'public.profile_role_audit', 'select') then
    raise exception 'profile_role_audit must not be readable by anon/authenticated';
  end if;
end
$$;

select
  (select count(*) from pg_trigger
    where tgrelid = 'public.profiles'::regclass
      and tgname in ('trg_profile_role_guard', 'trg_profile_admin_delete_guard')) as guard_triggers_expected_2,
  to_regclass('public.profile_role_audit') as audit_table;

commit; 