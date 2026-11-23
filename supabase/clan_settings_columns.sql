-- Недостающие поля настроек клана (ClanPulse → «Клан в поиске»).
-- Применить в Supabase SQL Editor (SQL -> New query -> Run).
-- Безопасна для повторного применения: существующие колонки не трогает.

alter table public.clans
  add column if not exists faction text,
  add column if not exists tier text,
  add column if not exists min_gear_level text,
  add column if not exists min_kd numeric,
  add column if not exists min_ehp numeric,
  add column if not exists min_speed numeric,
  add column if not exists chat_mode text not null default 'open',
  add column if not exists links jsonb not null default '[]'::jsonb,
  add column if not exists tournaments_per_week integer not null default 0,
  add column if not exists brawls_per_week integer not null default 0,
  add column if not exists open_slots integer not null default 0,
  add column if not exists contact text,
  add column if not exists needs_mic boolean not null default false,
  add column if not exists about text not null default '',
  add column if not exists goals jsonb not null default '[]'::jsonb;
