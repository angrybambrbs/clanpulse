-- Журнал клана: запись действий и правка званий/фракции участников.
drop policy if exists "audit_insert" on public.clan_audit_log;
create policy "audit_insert" on public.clan_audit_log
  for insert to authenticated with check (clan_id in (select clan_id from public.clan_members where user_id = auth.uid()));

create or replace function public.set_member_faction(p_user uuid, p_faction text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.clan_members
                 where clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer'))
                   and user_id = p_user) then
    return false;
  end if;
  if p_faction <> '' and p_faction not in ('svoboda','dolg','naemniki','zavet') then
    return false;
  end if;
  update public.profiles set faction = nullif(p_faction, '') where user_id = p_user;
  return true;
end $$;
