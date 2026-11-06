-- Privilege regression guard: runs on a fresh database with ALL migrations applied.
-- Fails if any function or table is reachable by a role that should not reach it.
\set ON_ERROR_STOP 1
\set QUIET 1
\pset tuples_only on
\pset format unaligned

\ir _framework.sql

select test.ok('anon can execute only public_catalogue',
  not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.prokind = 'f' and p.proname <> 'public_catalogue'
                and has_function_privilege('anon', p.oid, 'EXECUTE')),
  (select string_agg(p.proname, ', ') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prokind = 'f' and p.proname <> 'public_catalogue' and has_function_privilege('anon', p.oid, 'EXECUTE')));

select test.ok('internal _helpers are not executable by signed-in users (except the RLS helper)',
  not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.prokind = 'f' and left(p.proname, 1) = '_' and p.proname <> '_has_commission_line'
                and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  (select string_agg(p.proname, ', ') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prokind = 'f' and left(p.proname, 1) = '_' and p.proname <> '_has_commission_line'
     and has_function_privilege('authenticated', p.oid, 'EXECUTE')));

select test.ok('service-only functions are not executable by signed-in users',
  not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname in ('setup_create_business','setup_check_owner_code','setup_finalize_owner',
                'team_attach_auth_user','activation_check','activation_finalize','job_begin','job_finish','daily_snapshot','recovery_manifest')
                and has_function_privilege('authenticated', p.oid, 'EXECUTE')));

select test.ok('trigger functions are not directly executable by clients',
  not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.prorettype = 'trigger'::regtype
                and (has_function_privilege('authenticated', p.oid, 'EXECUTE') or has_function_privilege('anon', p.oid, 'EXECUTE'))));

create function public.test_probe() returns int language sql as $$ select 1 $$;
select test.ok('new function after migrations is not executable by anon/authenticated by default',
  not has_function_privilege('anon', 'public.test_probe()'::regprocedure, 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.test_probe()'::regprocedure, 'EXECUTE'));
drop function public.test_probe();

select test.ok('anon has no table privileges in public',
  not exists (select 1 from information_schema.role_table_grants where grantee = 'anon' and table_schema = 'public'),
  (select string_agg(table_name || ':' || privilege_type, ', ') from information_schema.role_table_grants where grantee = 'anon' and table_schema = 'public'));

select test.ok('signed-in users have no INSERT/UPDATE/DELETE on any public table',
  not exists (select 1 from information_schema.role_table_grants where grantee = 'authenticated' and table_schema = 'public'
              and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')),
  (select string_agg(table_name || ':' || privilege_type, ', ') from information_schema.role_table_grants where grantee = 'authenticated'
     and table_schema = 'public' and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')));

select test.ok('every public table has row level security enabled',
  not exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
              where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  (select string_agg(c.relname, ', ') from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity));

select test.ok('signed-in users can still call client RPCs (sample)',
  has_function_privilege('authenticated', 'public.sale_post(uuid,uuid,uuid,uuid,text,jsonb,bigint,text,jsonb,timestamptz,text,text,uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.report(text,date,date,uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.has_permission(text)', 'EXECUTE'));

\ir _report.sql
