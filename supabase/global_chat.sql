-- Глобальный чат между всеми пользователями сайта.
-- Применить в Supabase SQL Editor.

create table if not exists public.global_messages (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  nick       text not null default '',
  avatar_url text,
  body       text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

alter table public.global_messages enable row level security;
drop policy if exists "global_messages_read" on public.global_messages;
drop policy if exists "global_messages_insert" on public.global_messages;
drop policy if exists "global_messages_delete" on public.global_messages;
create policy "global_messages_read" on public.global_messages
  for select to authenticated using (true);
create policy "global_messages_insert" on public.global_messages
  for insert to authenticated with check (auth.uid() = user_id);
create policy "global_messages_delete" on public.global_messages
  for delete to authenticated using (auth.uid() = user_id);

create index if not exists global_messages_created_idx
  on public.global_messages (created_at desc);

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = 'global_messages') then
    alter publication supabase_realtime add table public.global_messages;
  end if;
end $$;
