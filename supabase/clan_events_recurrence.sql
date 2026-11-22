-- Повторяющиеся события: серия occurrences с общим series_id.
alter table public.clan_events add column if not exists repeat_rule text not null default 'once';
alter table public.clan_events add column if not exists series_id uuid;
