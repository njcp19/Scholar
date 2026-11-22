-- 003: Let a scholar update the registration fields an admin asked about.
-- Extends resubmit_registration with student_number, university, program, year_level.
-- NULL for a new parameter means "keep the current value", so older calls still work.
-- Independent of 001 and 002. One transaction: if anything fails, nothing changes.
-- Rollback (manual): drop the 7-argument function and recreate the 3-argument version
--   from supabase_setup.sql (resubmit_registration), then grant execute to anon, authenticated.
begin;

drop function if exists public.resubmit_registration(boolean, text, text);

create or replace function public.resubmit_registration(
  p_declared_scholar boolean,
  p_scholarship_name text,
  p_scholarship_reference text,
  p_student_number text default null,
  p_university text default null,
  p_program text default null,
  p_year_level text default null
) returns void language plpgsql security definer set search_path = '' as $$
declare
  v public.profiles;
  v_sn text := nullif(trim(p_student_number), '');
  v_uni text := nullif(trim(p_university), '');
  v_prog text := nullif(trim(p_program), '');
  v_year text := nullif(trim(p_year_level), '');
begin
  if public.wallet_uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v from public.profiles
   where id = public.wallet_uid() and role = 'scholar' for update;
  if not found or v.verification_status <> 'needs_info' then
    raise exception 'INFORMATION_NOT_REQUESTED';
  end if;
  if p_declared_scholar is null then raise exception 'DECLARATION_REQUIRED'; end if;
  if p_declared_scholar and length(trim(coalesce(p_scholarship_name, ''))) = 0 then
    raise exception 'SCHOLARSHIP_NAME_REQUIRED';
  end if;
  -- A value that was sent but is blank, or too long, is rejected (NULL = keep current).
  if (p_student_number is not null and v_sn is null)
     or (p_university is not null and v_uni is null)
     or (p_program is not null and v_prog is null)
     or (p_year_level is not null and v_year is null)
     or length(coalesce(v_sn, '')) > 60
     or length(coalesce(v_uni, '')) > 150
     or length(coalesce(v_prog, '')) > 150
     or length(coalesce(v_year, '')) > 40 then
    raise exception 'INVALID_FIELD';
  end if;

  update public.profiles set
    declared_scholar = p_declared_scholar,
    scholarship_name = case when p_declared_scholar then trim(p_scholarship_name) else '' end,
    scholarship_reference = case when p_declared_scholar
                                 then trim(coalesce(p_scholarship_reference, '')) else '' end,
    student_number = coalesce(v_sn, student_number),
    university = coalesce(v_uni, university),
    program = coalesce(v_prog, program),
    year_level = coalesce(v_year, year_level),
    verification_status = 'pending',
    is_active = false
  where id = v.id;

  insert into public.registration_reviews(scholar_id, from_status, decision, notes)
  values (v.id, 'needs_info', 'pending', 'Student updated requested verification details.');
end;
$$;

revoke all on function public.resubmit_registration(boolean, text, text, text, text, text, text) from public;
grant execute on function public.resubmit_registration(boolean, text, text, text, text, text, text)
  to anon, authenticated;

-- Verification (fails and rolls everything back if something is off)
do $$
begin
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
        and proname = 'resubmit_registration') <> 1 then
    raise exception 'resubmit_registration must have exactly one definition';
  end if;
  if not (select prosecdef from pg_proc where pronamespace = 'public'::regnamespace
            and proname = 'resubmit_registration') then
    raise exception 'resubmit_registration must be security definer';
  end if;
end
$$;

select pg_get_function_identity_arguments(oid) as resubmit_registration_args
  from pg_proc
 where pronamespace = 'public'::regnamespace and proname = 'resubmit_registration';

commit;