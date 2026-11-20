-- Разрешить приложению создавать уведомления от имени текущего пользователя.
-- Используется для лайков и закрепления тактик.
drop policy if exists "notifications_insert" on public.notifications;
create policy "notifications_insert" on public.notifications
  for insert to authenticated with check (actor_id = auth.uid());
