-- v22.1 hotfix: database grants required by the app
-- Applied to project jzfaggufycangmgwuuks.

-- Public landing shows live counters via anon key.
grant execute on function public.site_stats() to anon;

-- Audit log writes from clan members (RLS policy audit_insert already exists).
grant insert on public.clan_audit_log to authenticated;
