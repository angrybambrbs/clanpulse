-- Механики Зоны в календаре клана: локация события.
alter table public.clan_events add column if not exists location text;
