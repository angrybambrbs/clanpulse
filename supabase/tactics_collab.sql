-- Тактика: общий план клана, совместная работа и галерея тактик.
-- Применить в Supabase SQL Editor (SQL -> New query -> Run).
-- После применения включи Realtime для новых таблиц (см. конец файла).

-- Проверка членства в клане на уровне базы (клиенту нельзя подделать).
-- Функция уже может существовать в проекте — тогда не трогаем её.
do $do$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'is_clan_member' and p.pronargs = 1
  ) then
    create function public.is_clan_member(cid uuid)
    returns boolean language sql stable security definer set search_path = public
    as $func$
      select exists (
        select 1 from public.clan_members
        where clan_id = cid and user_id = auth.uid()
      );
    $func$;
  end if;
end $do$;

-- 1) Общий план клана: по одной строке на карту.
create table if not exists public.tactics_plans (
  clan_id   uuid not null references public.clans(id) on delete cascade,
  map_key   text not null,
  marks     jsonb not null default '[]'::jsonb,
  version   integer not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (clan_id, map_key)
);

alter table public.tactics_plans enable row level security;
drop policy if exists "tactics_plans_read" on public.tactics_plans;
drop policy if exists "tactics_plans_write" on public.tactics_plans;
create policy "tactics_plans_read" on public.tactics_plans
  for select using (public.is_clan_member(clan_id));
create policy "tactics_plans_write" on public.tactics_plans
  for all using (public.is_clan_member(clan_id))
  with check (public.is_clan_member(clan_id));

-- 2) Галерея опубликованных тактик клана.
create table if not exists public.tactics_gallery (
  id         uuid primary key default gen_random_uuid(),
  clan_id    uuid not null references public.clans(id) on delete cascade,
  map_key    text not null,
  title      text not null check (char_length(title) between 1 and 80),
  notes      text not null default '' check (char_length(notes) <= 2000),
  marks      jsonb not null default '[]'::jsonb,
  author_id  uuid not null references auth.users(id) on delete cascade,
  author_nick text not null default '',
  created_at timestamptz not null default now()
);

alter table public.tactics_gallery enable row level security;
drop policy if exists "tactics_gallery_read" on public.tactics_gallery;
drop policy if exists "tactics_gallery_insert" on public.tactics_gallery;
drop policy if exists "tactics_gallery_delete" on public.tactics_gallery;
create policy "tactics_gallery_read" on public.tactics_gallery
  for select using (public.is_clan_member(clan_id));
create policy "tactics_gallery_insert" on public.tactics_gallery
  for insert with check (public.is_clan_member(clan_id) and author_id = auth.uid());
create policy "tactics_gallery_delete" on public.tactics_gallery
  for delete using (
    author_id = auth.uid() or exists (
      select 1 from public.clan_members m
      where m.clan_id = tactics_gallery.clan_id
        and m.user_id = auth.uid()
        and m.role in ('owner', 'officer')
    )
  );

create index if not exists tactics_gallery_clan_idx
  on public.tactics_gallery (clan_id, created_at desc);

-- Серверная saves-функция: версия растёт на сервере, поэтому два участника
-- не перетирают правки друг друга.
create or replace function public.save_tactics_plan(p_clan uuid, p_map text, p_marks jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare v integer;
begin
  if not public.is_clan_member(p_clan) then
    raise exception 'not allowed';
  end if;
  insert into public.tactics_plans (clan_id, map_key, marks, updated_by)
  values (p_clan, p_map, coalesce(p_marks, '[]'::jsonb), auth.uid())
  on conflict (clan_id, map_key) do update
    set marks = excluded.marks,
        updated_by = auth.uid(),
        updated_at = now(),
        version = public.tactics_plans.version + 1
  returning version into v;
  return v;
end $$;

-- 3) Realtime: чтобы изменения приходили другим участникам без перезагрузки.
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = 'tactics_plans') then
    alter publication supabase_realtime add table public.tactics_plans;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = 'tactics_gallery') then
    alter publication supabase_realtime add table public.tactics_gallery;
  end if;
end $$;
