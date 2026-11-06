-- Shared assertion helpers for DB tests.
create schema if not exists test;
create table test.results (n serial, name text, ok boolean, detail text);
grant usage on schema test to anon, authenticated, service_role;
grant insert, select on test.results to anon, authenticated, service_role;
grant usage on sequence test.results_n_seq to anon, authenticated, service_role;

create function test.ok(p_name text, p_cond boolean, p_detail text default null) returns void
language sql as $$ insert into test.results (name, ok, detail) values (p_name, coalesce(p_cond,false), p_detail) $$;

-- Expect a statement to fail (any error). Records pass/fail.
create function test.throws(p_name text, p_sql text) returns void language plpgsql as $$
begin
  begin
    execute p_sql;
    perform test.ok(p_name, false, 'no error raised');
  exception when others then
    perform test.ok(p_name, true, sqlerrm);
  end;
end $$;
grant execute on all functions in schema test to anon, authenticated, service_role;

-- Act as a user: role + JWT claims (mirrors what PostgREST does per request).
create function test.claims(p_uid uuid, p_aal text) returns text language sql as $$
  select json_build_object('sub', p_uid, 'role', 'authenticated', 'aal', p_aal)::text
$$;
grant execute on function test.claims(uuid, text) to anon, authenticated, service_role;

