-- Killer Pack v22
-- MVP/highlights, achievements/badges, weekly quests, seasons/hall of fame, tournament hub
-- Cosmetic-only rewards. No automatic role escalation.

-- Profile cosmetic showcase
alter table public.profiles add column if not exists showcase_badge text;
alter table public.profiles add column if not exists showcase_title text;
alter table public.profiles add column if not exists profile_frame text;

-- Achievements / badges
create table if not exists public.clan_player_badges (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  badge_key text not null,
  title text not null,
  description text not null default '',
  icon text not null default '🏅',
  rarity text not null default 'common' check (rarity in ('common','rare','epic','legendary')),
  earned_at timestamptz not null default now(),
  meta jsonb not null default '{}'::jsonb,
  unique (clan_id, player_id, badge_key)
);
create index if not exists clan_player_badges_clan_idx on public.clan_player_badges(clan_id, earned_at desc);
create index if not exists clan_player_badges_player_idx on public.clan_player_badges(player_id, earned_at desc);
alter table public.clan_player_badges enable row level security;
drop policy if exists "clan_player_badges_read" on public.clan_player_badges;
create policy "clan_player_badges_read" on public.clan_player_badges for select to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid()) or exists (select 1 from public.clans c where c.id = clan_id and coalesce(c.is_public,true)));
drop policy if exists "clan_player_badges_insert" on public.clan_player_badges;
create policy "clan_player_badges_insert" on public.clan_player_badges for insert to authenticated
  with check (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer','member')));
drop policy if exists "clan_player_badges_update" on public.clan_player_badges;
create policy "clan_player_badges_update" on public.clan_player_badges for update to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer')))
  with check (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer')));
drop policy if exists "clan_player_badges_delete" on public.clan_player_badges;
create policy "clan_player_badges_delete" on public.clan_player_badges for delete to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer')));

-- Weekly clan quests
create table if not exists public.clan_quests (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  week_start date not null,
  quest_key text not null,
  title text not null,
  description text not null default '',
  target integer not null check (target > 0),
  progress integer not null default 0 check (progress >= 0),
  reward text not null default '',
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (clan_id, week_start, quest_key)
);
create index if not exists clan_quests_clan_week_idx on public.clan_quests(clan_id, week_start desc);
alter table public.clan_quests enable row level security;
drop policy if exists "clan_quests_read" on public.clan_quests;
create policy "clan_quests_read" on public.clan_quests for select to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid()) or exists (select 1 from public.clans c where c.id = clan_id and coalesce(c.is_public,true)));
drop policy if exists "clan_quests_write" on public.clan_quests;
create policy "clan_quests_write" on public.clan_quests for all to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer','member')))
  with check (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer','member')));

-- Seasons / Hall of Fame
create table if not exists public.clan_seasons (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  name text not null,
  starts_at date not null,
  ends_at date not null,
  status text not null default 'active' check (status in ('active','closed')),
  summary jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists clan_seasons_clan_idx on public.clan_seasons(clan_id, starts_at desc);
create table if not exists public.clan_season_results (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.clan_seasons(id) on delete cascade,
  clan_id uuid not null references public.clans(id) on delete cascade,
  player_id uuid references public.players(id) on delete set null,
  nick text not null,
  matches integer not null default 0,
  kills integer not null default 0,
  deaths integer not null default 0,
  assists integer not null default 0,
  score integer not null default 0,
  wins integer not null default 0,
  mvp_count integer not null default 0,
  rank integer,
  is_mvp boolean not null default false,
  reward text not null default '',
  created_at timestamptz not null default now(),
  unique (season_id, player_id)
);
create index if not exists clan_season_results_season_idx on public.clan_season_results(season_id, rank asc);
alter table public.clan_seasons enable row level security;
alter table public.clan_season_results enable row level security;
drop policy if exists "clan_seasons_read" on public.clan_seasons;
create policy "clan_seasons_read" on public.clan_seasons for select to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid()) or exists (select 1 from public.clans c where c.id = clan_id and coalesce(c.is_public,true)));
drop policy if exists "clan_seasons_write" on public.clan_seasons;
create policy "clan_seasons_write" on public.clan_seasons for all to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer')))
  with check (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer')));
drop policy if exists "clan_season_results_read" on public.clan_season_results;
create policy "clan_season_results_read" on public.clan_season_results for select to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid()) or exists (select 1 from public.clans c where c.id = clan_id and coalesce(c.is_public,true)));
drop policy if exists "clan_season_results_write" on public.clan_season_results;
create policy "clan_season_results_write" on public.clan_season_results for all to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer')))
  with check (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer')));

-- Tournament hub (lightweight, no fixed bracket)
create table if not exists public.clan_tournaments (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  title text not null,
  starts_at timestamptz,
  status text not null default 'planned' check (status in ('planned','live','done','cancelled')),
  format text not null default '',
  roster jsonb not null default '[]'::jsonb,
  rounds jsonb not null default '[]'::jsonb,
  placement integer,
  result text not null default '',
  mvp_player_id uuid references public.players(id) on delete set null,
  mvp_nick text,
  notes text not null default '',
  recap jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists clan_tournaments_clan_idx on public.clan_tournaments(clan_id, starts_at desc nulls last, created_at desc);
alter table public.clan_tournaments enable row level security;
drop policy if exists "clan_tournaments_read" on public.clan_tournaments;
create policy "clan_tournaments_read" on public.clan_tournaments for select to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid()) or exists (select 1 from public.clans c where c.id = clan_id and coalesce(c.is_public,true)));
drop policy if exists "clan_tournaments_write" on public.clan_tournaments;
create policy "clan_tournaments_write" on public.clan_tournaments for all to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer')))
  with check (clan_id in (select clan_id from public.clan_members where user_id = auth.uid() and role in ('owner','officer')));
