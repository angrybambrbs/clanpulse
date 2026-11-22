-- Проверка привязки игрового ника к аккаунту Discord.
-- Автоодобрение, если ник совпадает с Discord-именем; иначе заявка на подтверждение офицером.
create table if not exists public.nick_claims (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  decided_by uuid references auth.users(id),
  decided_at timestamptz
);
create index if not exists nick_claims_clan_idx on public.nick_claims(clan_id, status, created_at desc);
alter table public.nick_claims enable row level security;
drop policy if exists "nick_claims_read" on public.nick_claims;
create policy "nick_claims_read" on public.nick_claims for select to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid()));

create or replace function public.request_nick_claim(p_player uuid, p_discord_name text default '')
returns text language plpgsql security definer set search_path = public as $$
declare v uuid; vnick text; vdisc text; vstatus text;
begin
  select clan_id, nick into v, vnick from public.players where id = p_player;
  if v is null or not exists (select 1 from public.clan_members where clan_id = v and user_id = auth.uid()) then return 'denied'; end if;
  if exists (select 1 from public.players where id = p_player and user_id is not null and user_id <> auth.uid()) then return 'taken'; end if;
  if exists (select 1 from public.nick_claims where player_id = p_player and status = 'pending') then return 'pending'; end if;
  vdisc := lower(regexp_replace(regexp_replace(coalesce(p_discord_name,''), '[^a-zа-яё0-9]', '', 'g'), '#.*$', ''));
  vnick := lower(regexp_replace(regexp_replace(coalesce(vnick,''), '[^a-zа-яё0-9]', '', 'g'), '#.*$', ''));
  if length(vdisc) >= 4 and length(vnick) >= 4 and (position(vdisc in vnick) > 0 or position(vnick in vdisc) > 0) then
    vstatus := 'approved';
    update public.players set user_id = auth.uid() where id = p_player and (user_id is null or user_id = auth.uid());
  else
    vstatus := 'pending';
  end if;
  insert into public.nick_claims (clan_id, player_id, user_id, status, decided_by, decided_at)
  values (v, p_player, auth.uid(), vstatus, case when vstatus = 'approved' then auth.uid() end, case when vstatus = 'approved' then now() end);
  return vstatus;
end $$;

create or replace function public.decide_nick_claim(p_claim uuid, p_approve boolean)
returns boolean language plpgsql security definer set search_path = public as $$
declare v uuid; vpl uuid; vu uuid;
begin
  select clan_id, player_id, user_id into v, vpl, vu from public.nick_claims where id = p_claim and status = 'pending';
  if v is null or not public.can_edit_tactics(v) then return false; end if;
  if p_approve then
    update public.players set user_id = vu where id = vpl and (user_id is null or user_id = vu);
  end if;
  update public.nick_claims set status = case when p_approve then 'approved' else 'rejected' end, decided_by = auth.uid(), decided_at = now() where id = p_claim;
  return true;
end $$;
grant execute on function public.request_nick_claim(uuid, text) to authenticated;
grant execute on function public.decide_nick_claim(uuid, boolean) to authenticated;
