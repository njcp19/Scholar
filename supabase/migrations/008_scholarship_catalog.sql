-- 008: Scholarship catalog (the pre-listed scholarships a student can pick from).
-- 1) Table scholarship_catalog (no direct access; everything goes through the functions below).
-- 2) list_scholarship_catalog(): anyone (even before login, so Sign up can show the list) sees ACTIVE names only.
--    An admin can also see inactive ones (p_include_inactive = true).
-- 3) Admin only: add_scholarship_program(name), rename_scholarship_program(id, name),
--    set_scholarship_program_active(id, active). Nothing is ever deleted, so old registrations keep their text.
-- No names are pre-filled: the admin adds the real scholarships. The legacy scholarship_programs table is NOT touched.
-- Independent of 001-007. One transaction: if anything fails, nothing changes.
-- Rollback (manual): drop the 4 functions; drop table public.scholarship_catalog.
begin;

create table if not exists public.scholarship_catalog (
  id bigserial primary key,
  name text not null check (length(btrim(name)) between 2 and 80),
  is_active boolean not null default true,
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists scholarship_catalog_name_unique
  on public.scholarship_catalog (lower(btrim(name)));

alter table public.scholarship_catalog enable row level security;
revoke all on table public.scholarship_catalog from public, anon, authenticated;
revoke all on sequence public.scholarship_catalog_id_seq from public, anon, authenticated;

-- Read -----------------------------------------------------------------------
create or replace function public.list_scholarship_catalog(p_include_inactive boolean default false)
returns table (id bigint, name text, is_active boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  return query
  select c.id, c.name, c.is_active
    from public.scholarship_catalog c
   where c.is_active
      or (coalesce(p_include_inactive, false) and public.wallet_is_admin())
   order by lower(c.name);
end; $$;

-- Admin writes -------------------------------------------------------------------
create or replace function public.add_scholarship_program(p_name text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_id bigint;
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_ONLY'; end if;
  if length(v_name) < 2 or length(v_name) > 80 then raise exception 'INVALID_NAME'; end if;
  insert into public.scholarship_catalog(name, created_by)
  values (v_name, public.wallet_uid())
  returning id into v_id;
  return v_id;
exception when unique_violation then
  raise exception 'NAME_ALREADY_EXISTS';
end; $$;

create or replace function public.rename_scholarship_program(p_id bigint, p_name text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_ONLY'; end if;
  if length(v_name) < 2 or length(v_name) > 80 then raise exception 'INVALID_NAME'; end if;
  update public.scholarship_catalog set name = v_name, updated_at = now() where id = p_id;
  if not found then raise exception 'NOT_FOUND'; end if;
exception when unique_violation then
  raise exception 'NAME_ALREADY_EXISTS';
end; $$;

create or replace function public.set_scholarship_program_active(p_id bigint, p_active boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.wallet_is_admin() then raise exception 'ADMIN_ONLY'; end if;
  if p_active is null then raise exception 'INVALID_NAME'; end if;
  update public.scholarship_catalog set is_active = p_active, updated_at = now() where id = p_id;
  if not found then raise exception 'NOT_FOUND'; end if;
end; $$;

-- Permissions (same model as the other RPCs: checks are inside) ------------------
revoke all on function public.list_scholarship_catalog(boolean) from public;
revoke all on function public.add_scholarship_program(text) from public;
revoke all on function public.rename_scholarship_program(bigint, text) from public;
revoke all on function public.set_scholarship_program_active(bigint, boolean) from public;
grant execute on function public.list_scholarship_catalog(boolean) to anon, authenticated;
grant execute on function public.add_scholarship_program(text) to anon, authenticated;
grant execute on function public.rename_scholarship_program(bigint, text) to anon, authenticated;
grant execute on function public.set_scholarship_program_active(bigint, boolean) to anon, authenticated;

-- Verification (fails and rolls everything back if something is off) -------------
do $$
begin
  if to_regclass('public.scholarship_catalog') is null then
    raise exception 'scholarship_catalog missing';
  end if;
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
       and proname in ('list_scholarship_catalog', 'add_scholarship_program',
                       'rename_scholarship_program', 'set_scholarship_program_active')) <> 4 then
    raise exception 'catalog functions missing';
  end if;
  if has_table_privilege('anon', 'public.scholarship_catalog', 'select')
     or has_table_privilege('authenticated', 'public.scholarship_catalog', 'select') then
    raise exception 'scholarship_catalog must not be readable directly';
  end if;
end
$$;

select
  (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
     and proname in ('list_scholarship_catalog', 'add_scholarship_program',
                     'rename_scholarship_program', 'set_scholarship_program_active')) as functions_expected_4,
  (select count(*) from public.scholarship_catalog) as rows_expected_0;

commit;