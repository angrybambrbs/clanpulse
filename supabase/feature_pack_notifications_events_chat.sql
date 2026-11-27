-- ClanPulse feature pack: notifications, events, chat/social
alter table public.profiles add column if not exists notif_prefs jsonb not null default
  '{"application":true,"dm":true,"rsvp":true,"verification":true,"digest":true,"like":true,"pin":true,"mention":true,"event_reminder":true}'::jsonb;

alter table public.clan_messages add column if not exists reply_to uuid references public.clan_messages(id) on delete set null;
alter table public.clan_messages add column if not exists pinned_at timestamptz;
alter table public.clan_messages add column if not exists pinned_by uuid;
alter table public.global_messages add column if not exists reply_to uuid references public.global_messages(id) on delete set null;
alter table public.global_messages add column if not exists pinned_at timestamptz;
alter table public.global_messages add column if not exists pinned_by uuid;
alter table public.direct_messages add column if not exists reply_to uuid references public.direct_messages(id) on delete set null;

create table if not exists public.message_reactions (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('clan','global','dm')),
  message_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  unique(kind, message_id, user_id, emoji)
);
create index if not exists message_reactions_msg_idx on public.message_reactions(kind, message_id);
alter table public.message_reactions enable row level security;

alter table public.event_rsvps add column if not exists reminded_24h_at timestamptz;
alter table public.event_rsvps add column if not exists reminded_1h_at timestamptz;

do  begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='message_reactions' and policyname='mr_select') then
    create policy mr_select on public.message_reactions for select using (
      (kind='global' and exists(select 1 from public.global_messages gm where gm.id=message_id))
      or (kind='clan' and exists(select 1 from public.clan_messages cm where cm.id=message_id and is_clan_member(cm.clan_id)))
      or (kind='dm' and exists(select 1 from public.direct_messages dm where dm.id=message_id and (dm.sender_id=auth.uid() or dm.recipient_id=auth.uid())))
    );
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='message_reactions' and policyname='mr_insert') then
    create policy mr_insert on public.message_reactions for insert with check (
      user_id = auth.uid() and (
        (kind='global' and exists(select 1 from public.global_messages gm where gm.id=message_id))
        or (kind='clan' and exists(select 1 from public.clan_messages cm where cm.id=message_id and is_clan_member(cm.clan_id)))
        or (kind='dm' and exists(select 1 from public.direct_messages dm where dm.id=message_id and (dm.sender_id=auth.uid() or dm.recipient_id=auth.uid())))
      )
    );
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='message_reactions' and policyname='mr_delete') then
    create policy mr_delete on public.message_reactions for delete using (user_id = auth.uid());
  end if;
end ;

do  begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='clan_messages' and policyname='cm_update_pin') then
    create policy cm_update_pin on public.clan_messages for update using (can_edit_clan(clan_id)) with check (can_edit_clan(clan_id));
  end if;
end ;
