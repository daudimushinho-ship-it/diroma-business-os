-- Milestone A database acceptance tests.
-- Runs against a real PostgreSQL 16 with the Supabase stub + migrations applied.
\set ON_ERROR_STOP 1
\set QUIET 1
\pset tuples_only on
\pset format unaligned

\ir _framework.sql

-- Fixed test identities (synthetic; not real people)
insert into auth.users (id, phone) values
  ('00000000-0000-0000-0000-0000000000a1', '+255700000001'),  -- owner
  ('00000000-0000-0000-0000-0000000000a2', '+255700000002'),  -- manager
  ('00000000-0000-0000-0000-0000000000a3', '+255700000003'),  -- sales
  ('00000000-0000-0000-0000-0000000000a4', '+255700000004'),  -- storekeeper
  ('00000000-0000-0000-0000-0000000000a9', '+255700000009');  -- outsider (no membership)

\set OWNER   '''00000000-0000-0000-0000-0000000000a1'''
\set MANAGER '''00000000-0000-0000-0000-0000000000a2'''
\set SALES   '''00000000-0000-0000-0000-0000000000a3'''
\set STORE   '''00000000-0000-0000-0000-0000000000a4'''
\set OUTSIDE '''00000000-0000-0000-0000-0000000000a9'''

-- ---------------------------------------------------------------- owner bootstrap
set role service_role;
select public.setup_create_business('DIROMA', 'Spirit of Fashion', 'SETUP-CODE-123') \gset biz_
select test.ok('setup: wrong code returns null', public.setup_check_owner_code('WRONG') is null);
select test.ok('setup: failed attempt is persisted', (select attempts from public.owner_setup_codes) = 1);
select test.throws('setup: finalize with wrong code fails',
  $$select public.setup_finalize_owner('WRONG', '00000000-0000-0000-0000-0000000000a1', '+255700000001', 'Owner Test')$$);
select public.setup_finalize_owner('SETUP-CODE-123', :OWNER, '+255700000001', 'Owner Test') is not null as x \gset
select test.ok('setup: owner membership created active',
  (select status = 'active' and role = 'owner' from public.memberships where user_id = :OWNER));
select test.throws('setup: code cannot be replayed',
  $$select public.setup_finalize_owner('SETUP-CODE-123', '00000000-0000-0000-0000-0000000000a9', '+255700000009', 'Intruder')$$);
select test.throws('setup: cannot create a second owner bootstrap',
  $$select public.setup_create_business('X', 'Y', 'ANOTHER-CODE')$$);
reset role;

-- ---------------------------------------------------------------- owner without MFA
set role authenticated;
select set_config('request.jwt.claims', test.claims(:OWNER, 'aal1'), false) \gset x_
select test.ok('owner aal1: privileged permission denied until MFA', not public.has_permission('team.manage'));
select test.throws('owner aal1: cannot invite staff',
  $$select public.team_invite('+255700000002', 'Manager Test', 'manager', '{}', null)$$);
select test.ok('owner aal1: workspace says MFA required',
  (public.my_workspace() ->> 'mfa_required')::boolean and public.my_workspace() ->> 'aal' = 'aal1');

-- ---------------------------------------------------------------- owner with MFA: locations + invites
select set_config('request.jwt.claims', test.claims(:OWNER, 'aal2'), false) \gset x_
select public.location_create('wh', 'Kariakoo Store / Stoo', 'warehouse') as loc_wh \gset
select public.location_create('shop1', 'Kariakoo Shop / Dukani', 'shop') as loc_shop \gset
select test.ok('owner aal2: locations created', (select count(*) from public.locations) = 2);

select public.team_invite('+255700000002', 'Manager Test', 'manager', array[:'loc_wh', :'loc_shop']::uuid[], 'new hire') as m_mgr \gset
select public.team_invite('+255700000003', 'Sales Test', 'sales_staff', array[:'loc_shop']::uuid[], null) as m_sales \gset
select public.team_invite('+255700000004', 'Store Test', 'storekeeper', array[:'loc_wh']::uuid[], null) as m_store \gset
select test.throws('owner: cannot invite a second owner',
  $$select public.team_invite('+255700000005', 'Second Owner', 'owner', '{}', null)$$);
select test.throws('owner: duplicate phone rejected',
  $$select public.team_invite('+255700000003', 'Dup', 'sales_staff', '{}', null)$$);
select test.throws('owner: non-E.164 phone rejected',
  $$select public.team_invite('0712345678', 'Bad', 'sales_staff', '{}', null)$$);
reset role;

-- ---------------------------------------------------------------- invited (not yet activated) staff
set role authenticated;
select set_config('request.jwt.claims', test.claims(:SALES, 'aal1'), false) \gset x_
select test.ok('invited user without auth binding: no workspace', public.my_workspace() is null);
reset role;

-- ---------------------------------------------------------------- activation (server/service_role)
set role service_role;
select public.team_attach_auth_user(:'m_mgr',   :MANAGER, 'ACT-MGR-1') \gset x_
select public.team_attach_auth_user(:'m_sales', :SALES,   'ACT-SAL-1') \gset x_
select public.team_attach_auth_user(:'m_store', :STORE,   'ACT-STO-1') \gset x_
select test.throws('attach: cannot bind membership to a different user',
  $$select public.team_attach_auth_user('$$ || :'m_sales' || $$', '00000000-0000-0000-0000-0000000000a9', 'X')$$);
reset role;

set role authenticated;
select set_config('request.jwt.claims', test.claims(:SALES, 'aal1'), false) \gset x_
select test.ok('pending activation: no workspace', public.my_workspace() is null);
select test.ok('pending activation: no business data', (select count(*) from public.businesses) = 0);
select test.ok('pending activation: no locations', (select count(*) from public.locations) = 0);
reset role;

set role service_role;
select test.ok('activation: wrong code returns null', public.activation_check('+255700000003', 'WRONG') is null);
select test.ok('activation: failed attempt persisted',
  (select attempts from public.staff_activation_codes c join public.memberships m on m.id = c.membership_id
    where m.user_id = '00000000-0000-0000-0000-0000000000a3' and c.consumed_at is null) = 1);
select public.activation_finalize('+255700000002', 'ACT-MGR-1') \gset x_
select public.activation_finalize('+255700000003', 'ACT-SAL-1') \gset x_
select public.activation_finalize('+255700000004', 'ACT-STO-1') \gset x_
select test.throws('activation: code cannot be replayed',
  $$select public.activation_finalize('+255700000003', 'ACT-SAL-1')$$);
reset role;

-- ---------------------------------------------------------------- sales staff
set role authenticated;
select set_config('request.jwt.claims', test.claims(:SALES, 'aal1'), false) \gset x_
select test.ok('sales: workspace role is sales_staff', public.my_workspace() ->> 'role' = 'sales_staff');
select test.ok('sales: can sell', public.has_permission('pos.sell'));
select test.ok('sales: cannot see costs', not public.has_permission('costs.view'));
select test.ok('sales: sees only assigned shop location',
  (select count(*) from public.locations) = 1 and (select kind from public.locations limit 1) = 'shop');
select test.ok('sales: sees only own membership row', (select count(*) from public.memberships) = 1);
select test.ok('sales: cannot read audit', (select count(*) from public.audit_log) = 0);
select test.throws('sales: cannot invite', $$select public.team_invite('+255700000007', 'X Y', 'sales_staff', '{}', null)$$);
select test.throws('sales: cannot self-promote via RPC',
  $$select public.team_set_role('$$ || :'m_sales' || $$', 'manager', 'please')$$);
select test.throws('sales: direct UPDATE of own role denied',
  $$update public.memberships set role = 'owner' where user_id = auth.uid()$$);
select test.throws('sales: direct INSERT membership denied',
  $$insert into public.memberships (business_id, phone_e164, display_name, role) select id, '+255799999999', 'Hack', 'owner' from public.businesses$$);
select test.throws('sales: direct INSERT audit denied',
  $$insert into public.audit_log (action, entity) values ('x','y')$$);
select test.throws('sales: cannot call server-only activation function',
  $$select public.activation_finalize('+255700000003', 'ACT-SAL-1')$$);
select test.throws('sales: cannot call owner setup function',
  $$select public.setup_create_business('A','B','C')$$);
reset role;

-- ---------------------------------------------------------------- storekeeper
set role authenticated;
select set_config('request.jwt.claims', test.claims(:STORE, 'aal1'), false) \gset x_
select test.ok('store: can operate store', public.has_permission('store.operate'));
select test.ok('store: cannot sell at POS', not public.has_permission('pos.sell'));
select test.ok('store: cannot see costs', not public.has_permission('costs.view'));
select test.ok('store: sees only warehouse', (select count(*) from public.locations) = 1
  and (select kind from public.locations limit 1) = 'warehouse');
reset role;

-- ---------------------------------------------------------------- manager
set role authenticated;
select set_config('request.jwt.claims', test.claims(:MANAGER, 'aal1'), false) \gset x_
select test.ok('manager aal1: team.view blocked until MFA', not public.has_permission('team.view'));
select test.ok('manager aal1: cannot list team', (select count(*) from public.memberships) = 1);
select set_config('request.jwt.claims', test.claims(:MANAGER, 'aal2'), false) \gset x_
select test.ok('manager aal2: can view team', (select count(*) from public.memberships) = 4);
select test.ok('manager: cannot manage team', not public.has_permission('team.manage'));
select test.ok('manager: no costs by default', not public.has_permission('costs.view'));
select test.throws('manager: cannot self-promote',
  $$select public.team_set_role('$$ || :'m_mgr' || $$', 'owner', 'x')$$);
select test.throws('manager: cannot suspend staff',
  $$select public.team_set_status('$$ || :'m_sales' || $$', 'suspended', 'x')$$);
reset role;

-- ---------------------------------------------------------------- owner suspends sales staff
set role authenticated;
select set_config('request.jwt.claims', test.claims(:OWNER, 'aal2'), false) \gset x_
select test.throws('owner: suspension requires a reason',
  $$select public.team_set_status('$$ || :'m_sales' || $$', 'suspended', '  ')$$);
select public.team_set_status(:'m_sales', 'suspended', 'investigation') \gset x_
select test.throws('owner: cannot change own status',
  $$select public.team_set_status(public.current_membership().id, 'suspended', 'x')$$);
select test.throws('owner: cannot grant owner role',
  $$select public.team_set_role('$$ || :'m_mgr' || $$', 'owner', 'x')$$);
select test.ok('owner: can read audit trail', (select count(*) from public.audit_log) >= 6);
select test.ok('owner: audit records suspension with reason',
  exists (select 1 from public.audit_log where action = 'team.status' and reason = 'investigation'));
reset role;

set role authenticated;
select set_config('request.jwt.claims', test.claims(:SALES, 'aal1'), false) \gset x_
select test.ok('suspended (token still valid): no workspace', public.my_workspace() is null);
select test.ok('suspended: permission revoked immediately', not public.has_permission('pos.sell'));
select test.ok('suspended: no business data', (select count(*) from public.businesses) = 0);
select test.ok('suspended: no locations', (select count(*) from public.locations) = 0);
reset role;

-- ---------------------------------------------------------------- owner-assisted recovery
set role authenticated;
select set_config('request.jwt.claims', test.claims(:STORE, 'aal1'), false) \gset x_
select test.throws('store: cannot reset another account', $$select public.team_reset_access('$$ || :'m_mgr' || $$', 'x')$$);
select set_config('request.jwt.claims', test.claims(:OWNER, 'aal2'), false) \gset x_
select test.throws('recovery: reason required', $$select public.team_reset_access('$$ || :'m_store' || $$', '')$$);
select test.throws('recovery: owner cannot reset own account here', $$select public.team_reset_access(public.current_membership().id, 'x')$$);
select public.team_reset_access(:'m_store', 'forgot password') \gset x_
select test.ok('recovery: membership back to pending_activation',
  (select status from public.memberships where id = :'m_store') = 'pending_activation');
select set_config('request.jwt.claims', test.claims(:STORE, 'aal1'), false) \gset x_
select test.ok('recovery: access cut immediately', public.my_workspace() is null and (select count(*) from public.locations) = 0);
reset role;
set role service_role;
select public.team_attach_auth_user(:'m_store', :STORE, 'ACT-STO-2') \gset x_
select test.ok('recovery: old code no longer works', public.activation_check('+255700000004', 'ACT-STO-1') is null);
select public.activation_finalize('+255700000004', 'ACT-STO-2') \gset x_
reset role;
set role authenticated;
select set_config('request.jwt.claims', test.claims(:STORE, 'aal1'), false) \gset x_
select test.ok('recovery: access restored after new activation', public.my_workspace() ->> 'role' = 'storekeeper');
reset role;

-- ---------------------------------------------------------------- outsider & anon
set role authenticated;
select set_config('request.jwt.claims', test.claims(:OUTSIDE, 'aal2'), false) \gset x_
select test.ok('outsider: no workspace', public.my_workspace() is null);
select test.ok('outsider: no business rows', (select count(*) from public.businesses) = 0);
select test.ok('outsider: no membership rows', (select count(*) from public.memberships) = 0);
reset role;

set role anon;
select set_config('request.jwt.claims', '', false) \gset x_
select test.throws('anon: cannot read memberships', $$select * from public.memberships$$);
select test.throws('anon: cannot call my_workspace', $$select public.my_workspace()$$);
reset role;

-- ---------------------------------------------------------------- audit immutability (even superuser)
select test.throws('audit: UPDATE blocked', $$update public.audit_log set reason = 'edited'$$);
select test.throws('audit: DELETE blocked', $$delete from public.audit_log$$);
select test.throws('audit: TRUNCATE blocked', $$truncate public.audit_log$$);

\ir _report.sql
