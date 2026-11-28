-- Chat: show who wrote each message (Discord bridge + site) and keep replies visible.
-- Applied to project jzfaggufycangmgwuuks.

-- Author info for Discord-bridged messages (no site account needed).
alter table public.clan_messages add column if not exists author_name text;
alter table public.clan_messages add column if not exists author_avatar text;

-- Needed to resolve Discord reply_to and to de-duplicate the bridge.
create index if not exists clan_messages_discord_msg_id_idx on public.clan_messages(discord_msg_id);

-- One-time cleanup: the bridge polled without de-duplication, so each Discord
-- message could be inserted dozens of times. Keep the oldest copy.
with d as (
  select id, row_number() over (partition by discord_msg_id order by created_at asc) rn
  from public.clan_messages where discord_msg_id is not null
)
delete from public.clan_messages using d
where public.clan_messages.id = d.id and d.rn > 1;
