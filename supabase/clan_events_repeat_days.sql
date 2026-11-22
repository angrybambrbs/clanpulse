-- Дни недели для повторяющихся событий.
alter table public.clan_events add column if not exists repeat_days text[] not null default '{}';
