-- Разрешить приложению создавать уведомления от имени текущего пользователя.
-- Используется для лайков и закрепления тактик.
drop policy if exists "notifications_insert" on public.notifications;
create policy "notifications_insert" on public.notifications
  for insert to authenticated with check (actor_id = auth.uid());

-- Поиск пользователя по нику для @упоминаний (возвращает только user_id).
create or replace function public.find_user_by_nick(p_nick text)
returns uuid language sql stable security definer set search_path = public as $$
  select user_id from public.profiles
  where lower(nickname) = lower(btrim(p_nick))
  limit 1;
$$;
