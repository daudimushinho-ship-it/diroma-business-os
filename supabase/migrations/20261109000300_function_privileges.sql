-- SECURITY FIX: function execute privileges.
-- PostgreSQL grants EXECUTE on every new function to PUBLIC by default, and Supabase additionally grants it to
-- anon/authenticated through default privileges. Milestone A revoked that only for the functions existing at the time,
-- so functions added in Milestones C–F (including internal SECURITY DEFINER helpers such as _post_journal and _move)
-- were callable by any role. This migration:
--   1. revokes EXECUTE on every function in schema public from PUBLIC, anon and authenticated;
--   2. re-grants client RPCs to authenticated by explicit rule (no leading underscore, not service-only, not trigger);
--   3. grants service-only functions to service_role and the public catalogue to anon;
--   4. removes the global PUBLIC default so future functions start locked (each migration grants explicitly).
-- tests/db/60_privileges_test.sql fails if any function is ever exposed again.
begin;

revoke all on all functions in schema public from public, anon, authenticated;
alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

do $$
declare f record;
  service_only text[] := array['setup_create_business','setup_check_owner_code','setup_finalize_owner','team_attach_auth_user',
    'activation_check','activation_finalize','job_begin','job_finish','daily_snapshot','recovery_manifest'];
  rls_helpers text[] := array['_has_commission_line'];
begin
  for f in
    select p.oid::regprocedure as sig, p.proname, p.prorettype = 'trigger'::regtype as is_trigger
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
  loop
    if f.is_trigger then continue; end if;
    if f.proname = any (service_only) then
      execute format('grant execute on function %s to service_role', f.sig);
    elsif f.proname = 'public_catalogue' then
      execute format('grant execute on function %s to anon, authenticated', f.sig);
    elsif left(f.proname, 1) <> '_' or f.proname = any (rls_helpers) then
      execute format('grant execute on function %s to authenticated', f.sig);
    end if;
  end loop;
end $$;

commit;
