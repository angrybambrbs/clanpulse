-- Storage для ClanPulse: аватарки кланов и скриншоты верификации.
-- Применить в Supabase SQL Editor (SQL -> New query -> Run).
-- Путь файла всегда начинается с clan_id: <clan_uuid>/avatar.webp или <clan_uuid>/<ts>.jpg

-- 1) Бакеты
insert into storage.buckets (id, name, public, file_size_limit)
values ('clan-avatars', 'clan-avatars', true, 5242880)
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit;

insert into storage.buckets (id, name, public, file_size_limit)
values ('verification-proofs', 'verification-proofs', false, 10485760)
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit;

-- 2) Аватарки кланов: читают все, меняют участники клана
drop policy if exists "clan_avatars_read" on storage.objects;
create policy "clan_avatars_read" on storage.objects
  for select using (bucket_id = 'clan-avatars');

drop policy if exists "clan_avatars_write" on storage.objects;
create policy "clan_avatars_write" on storage.objects
  for all to authenticated
  using (bucket_id = 'clan-avatars' and exists (
    select 1 from public.clan_members
    where clan_id = ((storage.foldername(name))[1])::uuid and user_id = auth.uid()
  ))
  with check (bucket_id = 'clan-avatars' and exists (
    select 1 from public.clan_members
    where clan_id = ((storage.foldername(name))[1])::uuid and user_id = auth.uid()
  ));

-- 3) Доказательства верификации: приватный бакет, доступ только участникам клана
drop policy if exists "verification_proofs_read" on storage.objects;
create policy "verification_proofs_read" on storage.objects
  for select to authenticated
  using (bucket_id = 'verification-proofs' and exists (
    select 1 from public.clan_members
    where clan_id = ((storage.foldername(name))[1])::uuid and user_id = auth.uid()
  ));

drop policy if exists "verification_proofs_insert" on storage.objects;
create policy "verification_proofs_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'verification-proofs' and exists (
    select 1 from public.clan_members
    where clan_id = ((storage.foldername(name))[1])::uuid and user_id = auth.uid()
  ));

drop policy if exists "verification_proofs_delete" on storage.objects;
create policy "verification_proofs_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'verification-proofs' and exists (
    select 1 from public.clan_members
    where clan_id = ((storage.foldername(name))[1])::uuid
      and user_id = auth.uid() and role in ('owner', 'officer')
  ));
