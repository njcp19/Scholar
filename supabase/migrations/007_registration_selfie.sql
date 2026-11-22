-- 007: One-time registration selfie.
-- 1) profiles: selfie_path, selfie_submitted_at, selfie_retake_allowed (only the RPCs below can change them).
-- 2) Private Storage bucket "selfies" (2 MB, jpeg/png). A scholar can upload only into their own folder,
--    only while not approved and only if they have no selfie yet (or an admin allowed a retake).
--    Only admins can read the files. Scholars cannot read, update or delete.
-- 3) submit_selfie(p_path): records the uploaded file once. A retake works only after request_selfie_retake().
-- 4) request_selfie_retake(p_scholar_id): admin only.
-- 5) A scholar cannot become 'approved' without a selfie (trigger; existing approved scholars are not touched).
-- Independent of 001-006. One transaction: if anything fails, nothing changes.
-- Note: a failed upload that never reaches submit_selfie can leave an orphan file in the scholar's own folder.
--   It is private, size-limited, and can be cleaned up by the owner in the dashboard.
-- Rollback (manual): drop trigger trg_selfie_required_for_approval and trg_selfie_columns_guard on public.profiles;
--   drop functions selfie_required_for_approval, selfie_columns_guard, selfie_upload_allowed, submit_selfie,
--   request_selfie_retake; drop the 3 storage policies "selfies_*"; drop the 3 columns; delete the bucket
--   (empty it first in the dashboard).
begin;

-- 1) Columns -----------------------------------------------------------------
alter table public.profiles add column if not exists selfie_path text;
alter table public.profiles add column if not exists selfie_submitted_at timestamptz;
alter table public.profiles add column if not exists selfie_retake_allowed boolean not null default false;

create or replace function public.selfie_columns_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (new.selfie_path is distinct from old.selfie_path
      or new.selfie_submitted_at is distinct from old.selfie_submitted_at
      or new.selfie_retake_allowed is distinct from old.selfie_retake_allowed)
     and coalesce(current_setting('app.selfie_rpc', true), '') <> 'on' then
    raise exception 'SELFIE_COLUMNS_PROTECTED';
  end if;
  return new;
end; $$;

drop trigger if exists trg_selfie_columns_guard on public.profiles;
create trigger trg_selfie_columns_guard
  before update on public.profiles
  for each row execute function public.selfie_columns_guard();

-- 5) Approval needs a selfie ---------------------------------------------------
create or replace function public.selfie_required_for_approval() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.role = 'scholar'
     and new.verification_status = 'approved'
     and old.verification_status is distinct from 'approved'
     and new.selfie_path is null then
    raise exception 'SELFIE_REQUIRED';
  end if;
  return new;
end; $$;

drop trigger if exists trg_selfie_required_for_approval on public.profiles;
create trigger trg_selfie_required_for_approval
  before update of verification_status on public.profiles
  for each row execute function public.selfie_required_for_approval();

-- 2) Bucket + storage policies ---------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('selfies', 'selfies', false, 2097152, array['image/jpeg', 'image/png'])
on conflict (id) do update
  set public = false, file_size_limit = 2097152,
      allowed_mime_types = array['image/jpeg', 'image/png'];

create or replace function public.selfie_upload_allowed(p_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.wallet_uid() is not null
     and split_part(p_name, '/', 1) = public.wallet_uid()
     and exists (
       select 1 from public.profiles p
        where p.id = public.wallet_uid()
          and p.role = 'scholar'
          and p.verification_status <> 'approved'
          and (p.selfie_path is null or p.selfie_retake_allowed)
     );
$$;

drop policy if exists selfies_insert_own on storage.objects;
create policy selfies_insert_own on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'selfies' and public.selfie_upload_allowed(name));

drop policy if exists selfies_admin_read on storage.objects;
create policy selfies_admin_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'selfies' and public.wallet_is_admin());

-- 3) Scholar records the uploaded file --------------------------------------------
create or replace function public.submit_selfie(p_path text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_profile public.profiles;
begin
  select * into v_profile from public.profiles where id = public.wallet_uid() for update;
  if not found or v_profile.role <> 'scholar' or v_profile.verification_status = 'approved' then
    raise exception 'SCHOLAR_NOT_ELIGIBLE';
  end if;
  if p_path is null or split_part(p_path, '/', 1) <> public.wallet_uid()
     or length(p_path) > 200 or p_path !~ '^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$' then
    raise exception 'BAD_PATH';
  end if;
  if v_profile.selfie_path is not null and not v_profile.selfie_retake_allowed then
    raise exception 'SELFIE_ALREADY_SUBMITTED';
  end if;
  if not exists (select 1 from storage.objects where bucket_id = 'selfies' and name = p_path) then
    raise exception 'FILE_MISSING';
  end if;

  perform set_config('app.selfie_rpc', 'on', true);
  update public.profiles
     set selfie_path = p_path,
         selfie_submitted_at = now(),
         selfie_retake_allowed = false
   where id = public.wallet_uid();
end; $$;

-- 4) Admin allows one retake ------------------------------------------------------
create or replace function public.request_selfie_retake(p_scholar_id text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_target public.profiles;
begin
  if not public.wallet_is_admin() then
    raise exception 'ADMIN_ONLY';
  end if;
  select * into v_target from public.profiles where id = p_scholar_id for update;
  if not found or v_target.role <> 'scholar' or v_target.verification_status = 'approved' then
    raise exception 'SCHOLAR_NOT_ELIGIBLE';
  end if;
  if v_target.selfie_path is null then
    raise exception 'NO_SELFIE_YET';
  end if;
  perform set_config('app.selfie_rpc', 'on', true);
  update public.profiles set selfie_retake_allowed = true where id = p_scholar_id;
end; $$;

-- Permissions (same model as the other RPCs: checks are inside) -------------------
revoke all on function public.submit_selfie(text) from public;
revoke all on function public.request_selfie_retake(text) from public;
revoke all on function public.selfie_upload_allowed(text) from public;
revoke all on function public.selfie_columns_guard() from public, anon, authenticated;
revoke all on function public.selfie_required_for_approval() from public, anon, authenticated;
grant execute on function public.submit_selfie(text) to anon, authenticated;
grant execute on function public.request_selfie_retake(text) to anon, authenticated;
grant execute on function public.selfie_upload_allowed(text) to anon, authenticated;

-- Verification (fails and rolls everything back if something is off) -----------------
do $$
begin
  if (select count(*) from information_schema.columns
       where table_schema = 'public' and table_name = 'profiles'
         and column_name in ('selfie_path', 'selfie_submitted_at', 'selfie_retake_allowed')) <> 3 then
    raise exception 'selfie columns missing';
  end if;
  if not exists (select 1 from storage.buckets where id = 'selfies' and public = false) then
    raise exception 'selfies bucket missing or public';
  end if;
  if (select count(*) from pg_policies
       where schemaname = 'storage' and tablename = 'objects'
         and policyname in ('selfies_insert_own', 'selfies_admin_read')) <> 2 then
    raise exception 'storage policies missing';
  end if;
  if (select count(*) from pg_trigger
       where tgrelid = 'public.profiles'::regclass
         and tgname in ('trg_selfie_columns_guard', 'trg_selfie_required_for_approval')) <> 2 then
    raise exception 'selfie triggers missing';
  end if;
end
$$;

select
  (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
     and proname in ('submit_selfie', 'request_selfie_retake', 'selfie_upload_allowed')) as functions_expected_3,
  (select public from storage.buckets where id = 'selfies') as bucket_public_expected_false;

commit;