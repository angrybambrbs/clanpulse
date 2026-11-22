-- Привязка игрового ника в составе к аккаунту сайта (Discord).
create or replace function public.claim_player_nick(p_player uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  select clan_id into v from public.players where id = p_player;
  if v is null or not exists (select 1 from public.clan_members where clan_id = v and user_id = auth.uid()) then return false; end if;
  update public.players set user_id = auth.uid() where id = p_player and (user_id is null or user_id = auth.uid());
  return true;
end $$;
create or replace function public.unclaim_player_nick(p_player uuid)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  update public.players set user_id = null where id = p_player and user_id = auth.uid();
  return true;
end $$;
grant execute on function public.claim_player_nick(uuid) to authenticated;
grant execute on function public.unclaim_player_nick(uuid) to authenticated;
