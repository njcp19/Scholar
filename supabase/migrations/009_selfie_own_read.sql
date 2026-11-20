-- 009: A scholar can read ONLY their own selfie (so it can be shown as their profile picture).
-- Before: only admins could read files in the private "selfies" bucket.
-- After: admins read all (unchanged); a signed-in or anon-JWT scholar reads only files inside their own folder (<uid>/...).
-- The bucket stays private. Uploading rules from 007 are unchanged (upload once; retake only after an admin request).
-- Independent of 001-008 except it needs 007 (bucket) and wallet_uid().
-- Rollback (manual): drop policy selfies_read_own on storage.objects;
begin;

drop policy if exists selfies_read_own on storage.objects;
create policy selfies_read_own on storage.objects
  for select to anon, authenticated
  using (
    bucket_id = 'selfies'
    and public.wallet_uid() is not null
    and split_part(name, '/', 1) = public.wallet_uid()
  );

-- Verification (fails and rolls everything back if something is off)
do $$
begin
  if not exists (select 1 from storage.buckets where id = 'selfies' and public = false) then
    raise exception 'selfies bucket missing or public';
  end if;
  if (select count(*) from pg_policies
       where schemaname = 'storage' and tablename = 'objects'
         and policyname in ('selfies_insert_own', 'selfies_admin_read', 'selfies_read_own')) <> 3 then
    raise exception 'expected 3 selfie storage policies';
  end if;
end
$$;

select
  (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects'
     and policyname in ('selfies_insert_own', 'selfies_admin_read', 'selfies_read_own')) as policies_expected_3,
  (select public from storage.buckets where id = 'selfies') as bucket_public_expected_false;

commit;