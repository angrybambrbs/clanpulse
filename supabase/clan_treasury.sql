-- Казна клана: доходы, расходы и штрафы.
create table if not exists public.clan_treasury (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references public.clans(id) on delete cascade,
  player_id uuid references public.players(id) on delete set null,
  kind text not null check (kind in ('income','expense','fine')),
  amount integer not null check (amount > 0),
  reason text not null default '',
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists clan_treasury_clan_idx on public.clan_treasury(clan_id, created_at desc);
alter table public.clan_treasury enable row level security;
drop policy if exists "treasury_read" on public.clan_treasury;
create policy "treasury_read" on public.clan_treasury for select to authenticated
  using (clan_id in (select clan_id from public.clan_members where user_id = auth.uid()));
drop policy if exists "treasury_write" on public.clan_treasury;
create policy "treasury_write" on public.clan_treasury for insert to authenticated
  with check (public.can_edit_tactics(clan_id));
drop policy if exists "treasury_del" on public.clan_treasury;
create policy "treasury_del" on public.clan_treasury for delete to authenticated
  using (public.can_edit_tactics(clan_id));
