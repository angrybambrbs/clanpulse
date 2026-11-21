-- Точки захвата: храним состояние (нейтральная/своя/вражеская, удалена) отдельно от разметки.
alter table public.tactics_plans add column if not exists caps jsonb not null default '[]'::jsonb;

create or replace function public.save_tactics_plan(p_clan uuid, p_map text, p_marks jsonb, p_caps jsonb default '[]'::jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare v integer;
begin
  if not public.can_edit_tactics(p_clan) then
    raise exception 'not allowed';
  end if;
  insert into public.tactics_plans (clan_id, map_key, marks, caps, updated_by)
  values (p_clan, p_map, coalesce(p_marks, '[]'::jsonb), coalesce(p_caps, '[]'::jsonb), auth.uid())
  on conflict (clan_id, map_key) do update
    set marks = excluded.marks,
        caps = excluded.caps,
        updated_by = auth.uid(),
        updated_at = now(),
        version = public.tactics_plans.version + 1
  returning version into v;
  return v;
end $$;
