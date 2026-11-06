-- TEST-ONLY: minimal emulation of the Supabase platform objects the migrations rely on.
-- Mirrors Supabase semantics: auth.uid()/auth.jwt() read the request JWT claims GUC,
-- roles anon/authenticated/service_role exist, pgcrypto lives in schema "extensions".
-- Never apply this file to a real Supabase project.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

create schema auth;
create schema extensions;
create extension pgcrypto with schema extensions;

create table auth.users (
  id    uuid primary key default gen_random_uuid(),
  phone text unique
);

create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(auth.jwt() ->> 'sub', '')::uuid
$$;

grant usage on schema auth, extensions to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;
grant execute on all functions in schema auth to anon, authenticated, service_role;
grant select on all tables in schema public to service_role;

-- Supabase grants broad default privileges to the API roles on objects created in "public".
-- Emulating them here means the tests prove that the migration's REVOKEs actually lock things down.
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
