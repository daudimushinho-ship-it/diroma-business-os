-- DIROMA Business OS — Milestone A foundation
-- Identity comes from Supabase Auth (auth.users / auth.uid()).
-- Business authority comes ONLY from server-controlled rows in this schema.
-- Clients get read access through RLS; every write goes through
-- SECURITY DEFINER functions that check membership, permission and MFA level.

begin;

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------
create type public.app_role as enum ('owner', 'manager', 'sales_staff', 'storekeeper');
create type public.membership_status as enum ('invited', 'pending_activation', 'active', 'suspended', 'deactivated');
create type public.location_kind as enum ('warehouse', 'shop', 'transit', 'partner', 'inspection', 'quarantine');

-- ---------------------------------------------------------------------------
-- Core tables
-- ---------------------------------------------------------------------------
create table public.businesses (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slogan      text,
  currency    char(3) not null default 'TZS',
  timezone    text not null default 'Africa/Dar_es_Salaam',
  created_at  timestamptz not null default now()
);

create table public.locations (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  code        text not null,
  name        text not null,
  kind        public.location_kind not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (business_id, code)
);

create table public.memberships (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references public.businesses(id),
  user_id        uuid unique references auth.users(id),
  phone_e164     text not null check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  display_name   text not null check (length(btrim(display_name)) between 2 and 80),
  role           public.app_role not null,
  status         public.membership_status not null default 'invited',
  all_locations  boolean not null default false,
  created_by     uuid references public.memberships(id),
  created_at     timestamptz not null default now(),
  activated_at   timestamptz,
  updated_at     timestamptz not null default now(),
  unique (business_id, phone_e164)
);
-- Exactly one Owner per business.
create unique index memberships_one_owner on public.memberships (business_id) where role = 'owner';

create table public.membership_locations (
  membership_id uuid not null references public.memberships(id) on delete cascade,
  location_id   uuid not null references public.locations(id),
  primary key (membership_id, location_id)
);

create table public.permissions (
  code        text primary key,
  description text not null
);

create table public.role_permissions (
  role        public.app_role not null,
  permission  text not null references public.permissions(code),
  primary key (role, permission)
);

-- Append-only audit trail.
create table public.audit_log (
  id                  bigint generated always as identity primary key,
  business_id         uuid references public.businesses(id),
  actor_user_id       uuid,
  actor_membership_id uuid,
  action              text not null,
  entity              text not null,
  entity_id           text,
  before_data         jsonb,
  after_data          jsonb,
  reason              text,
  correlation_id      uuid not null default gen_random_uuid(),
  created_at          timestamptz not null default now()
);
create index audit_log_business_created on public.audit_log (business_id, created_at desc);

-- One-time Owner bootstrap codes (hash only; plaintext is shown once to the operator).
create table public.owner_setup_codes (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id),
  code_hash    text not null,
  expires_at   timestamptz not null,
  consumed_at  timestamptz,
  attempts     int not null default 0,
  created_at   timestamptz not null default now()
);

-- Staff activation codes (hash only; single use, short lived, attempt-limited).
create table public.staff_activation_codes (
  id             uuid primary key default gen_random_uuid(),
  membership_id  uuid not null references public.memberships(id) on delete cascade,
  code_hash      text not null,
  expires_at     timestamptz not null,
  consumed_at    timestamptz,
  attempts       int not null default 0,
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Seed: permission catalogue and default role matrix
-- ---------------------------------------------------------------------------
insert into public.permissions (code, description) values
  ('overview.business',   'Owner business overview incl. profit'),
  ('overview.operations', 'Manager operations overview'),
  ('pos.sell',            'Use POS and record sales'),
  ('sales.view',          'View sales register'),
  ('store.operate',       'Receive, dispatch, count stock in Store/Stoo'),
  ('shop_stock.view',     'View shop stock and confirm incoming receipts'),
  ('products.view',       'View catalogue (selling prices only)'),
  ('products.manage',     'Create/edit catalogue'),
  ('costs.view',          'See buying costs, valuation and profit'),
  ('customers.view',      'View customers'),
  ('wholesale.manage',    'Operate wholesale and consignment partners'),
  ('money.view',          'View money accounts and closings'),
  ('reports.view',        'View reports'),
  ('team.view',           'View staff list'),
  ('team.manage',         'Invite, suspend, change roles and locations'),
  ('audit.view',          'View audit log / control center'),
  ('settings.manage',     'Manage company settings and locations');

insert into public.role_permissions (role, permission)
select 'owner'::public.app_role, code from public.permissions;

insert into public.role_permissions (role, permission) values
  ('manager','overview.operations'), ('manager','pos.sell'), ('manager','sales.view'),
  ('manager','store.operate'), ('manager','shop_stock.view'), ('manager','products.view'),
  ('manager','customers.view'), ('manager','wholesale.manage'), ('manager','reports.view'),
  ('manager','team.view'),
  ('sales_staff','pos.sell'), ('sales_staff','sales.view'), ('sales_staff','shop_stock.view'),
  ('sales_staff','products.view'), ('sales_staff','customers.view'),
  ('storekeeper','store.operate'), ('storekeeper','shop_stock.view'), ('storekeeper','products.view');

-- ---------------------------------------------------------------------------
-- Integrity triggers
-- ---------------------------------------------------------------------------
create or replace function public.tg_audit_immutable() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'audit_log is append-only' using errcode = '42501';
end $$;

create trigger audit_log_no_update before update or delete on public.audit_log
for each row execute function public.tg_audit_immutable();
create trigger audit_log_no_truncate before truncate on public.audit_log
for each statement execute function public.tg_audit_immutable();

create or replace function public.tg_touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;

create trigger memberships_touch before update on public.memberships
for each row execute function public.tg_touch_updated_at();

-- ---------------------------------------------------------------------------
-- Identity helpers (all SECURITY DEFINER with empty search_path)
-- ---------------------------------------------------------------------------
-- Current active membership. Re-evaluated on every call, so suspending a user
-- cuts access immediately even while their JWT is still valid.
create or replace function public.current_membership() returns public.memberships
language sql stable security definer set search_path = '' as $$
  select m.* from public.memberships m
  where m.user_id = auth.uid() and m.status = 'active'
  limit 1
$$;

create or replace function public.current_aal() returns text
language sql stable set search_path = '' as $$
  select coalesce(auth.jwt() ->> 'aal', 'aal1')
$$;

create or replace function public.has_permission(p_permission text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.memberships m
    join public.role_permissions rp on rp.role = m.role
    where m.user_id = auth.uid()
      and m.status = 'active'
      and rp.permission = p_permission
      -- privileged roles must have completed MFA in this session
      and (m.role not in ('owner','manager') or public.current_aal() = 'aal2')
  )
$$;

create or replace function public.is_business_member(p_business uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.memberships m
                 where m.user_id = auth.uid() and m.status = 'active' and m.business_id = p_business)
$$;

create or replace function public.can_access_location(p_location uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m
    join public.locations l on l.business_id = m.business_id and l.id = p_location
    where m.user_id = auth.uid() and m.status = 'active'
      and (m.all_locations or exists (select 1 from public.membership_locations ml
                                      where ml.membership_id = m.id and ml.location_id = p_location))
  )
$$;

create or replace function public.write_audit(
  p_business uuid, p_action text, p_entity text, p_entity_id text,
  p_before jsonb, p_after jsonb, p_reason text
) returns void
language plpgsql security definer set search_path = '' as $$
declare v_m public.memberships;
begin
  select * into v_m from public.memberships where user_id = auth.uid() limit 1;
  insert into public.audit_log (business_id, actor_user_id, actor_membership_id, action, entity, entity_id,
                                before_data, after_data, reason)
  values (p_business, auth.uid(), v_m.id, p_action, p_entity, p_entity_id, p_before, p_after, p_reason);
end $$;

-- ---------------------------------------------------------------------------
-- Workspace for routing (what the app shell uses)
-- ---------------------------------------------------------------------------
create or replace function public.my_workspace() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_m public.memberships; v_b public.businesses;
begin
  v_m := public.current_membership();
  if v_m.id is null then return null; end if;
  select * into v_b from public.businesses where id = v_m.business_id;
  return jsonb_build_object(
    'membership_id', v_m.id,
    'business', jsonb_build_object('id', v_b.id, 'name', v_b.name, 'slogan', v_b.slogan,
                                   'currency', v_b.currency, 'timezone', v_b.timezone),
    'display_name', v_m.display_name,
    'role', v_m.role,
    'aal', public.current_aal(),
    'mfa_required', v_m.role in ('owner','manager'),
    'permissions', coalesce((select jsonb_agg(rp.permission order by rp.permission)
                             from public.role_permissions rp where rp.role = v_m.role), '[]'::jsonb),
    'locations', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'code', l.code, 'name', l.name, 'kind', l.kind)
                                            order by l.name)
                           from public.locations l
                           where l.business_id = v_m.business_id and l.is_active
                             and (v_m.all_locations or exists (select 1 from public.membership_locations ml
                                    where ml.membership_id = v_m.id and ml.location_id = l.id))), '[]'::jsonb)
  );
end $$;

-- ---------------------------------------------------------------------------
-- Owner bootstrap (service_role only — called by the server after validating input)
-- ---------------------------------------------------------------------------
-- Operator creates a business + one-time setup code with scripts/setup-owner.mjs.
create or replace function public.setup_create_business(p_name text, p_slogan text, p_code text, p_ttl_minutes int default 1440)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_b uuid;
begin
  if exists (select 1 from public.memberships where role = 'owner') then
    raise exception 'owner already established' using errcode = '42501';
  end if;
  select id into v_b from public.businesses order by created_at limit 1;
  if v_b is null then
    insert into public.businesses (name, slogan) values (p_name, p_slogan) returning id into v_b;
  end if;
  -- invalidate previous unused codes
  update public.owner_setup_codes set expires_at = least(expires_at, now()) where business_id = v_b and consumed_at is null;
  insert into public.owner_setup_codes (business_id, code_hash, expires_at)
  values (v_b, extensions.crypt(p_code, extensions.gen_salt('bf')), now() + make_interval(mins => p_ttl_minutes));
  return v_b;
end $$;

-- Validates the setup code (counts attempts). Returns business id, or NULL for a wrong code.
create or replace function public.setup_check_owner_code(p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare r public.owner_setup_codes;
begin
  if exists (select 1 from public.memberships where role = 'owner') then
    raise exception 'owner already established' using errcode = '42501';
  end if;
  select * into r from public.owner_setup_codes
   where consumed_at is null and expires_at > now() order by created_at desc limit 1 for update;
  if r.id is null then raise exception 'invalid or expired setup code' using errcode = '28000'; end if;
  if r.attempts >= 5 then raise exception 'too many attempts' using errcode = '28000'; end if;
  update public.owner_setup_codes set attempts = attempts + 1 where id = r.id;
  -- Return NULL (not raise) on a wrong code so the attempt counter is persisted.
  if r.code_hash <> extensions.crypt(p_code, r.code_hash) then
    return null;
  end if;
  return r.business_id;
end $$;

-- Consumes the code and creates the active Owner membership for an existing auth user.
create or replace function public.setup_finalize_owner(p_code text, p_user uuid, p_phone text, p_name text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_b uuid; v_m uuid;
begin
  v_b := public.setup_check_owner_code(p_code);
  if v_b is null then raise exception 'invalid or expired setup code' using errcode = '28000'; end if;
  update public.owner_setup_codes set consumed_at = now()
   where business_id = v_b and consumed_at is null;
  insert into public.memberships (business_id, user_id, phone_e164, display_name, role, status, all_locations, activated_at)
  values (v_b, p_user, p_phone, p_name, 'owner', 'active', true, now())
  returning id into v_m;
  insert into public.audit_log (business_id, actor_user_id, actor_membership_id, action, entity, entity_id, after_data, reason)
  values (v_b, p_user, v_m, 'owner.bootstrap', 'membership', v_m::text,
          jsonb_build_object('phone', p_phone, 'name', p_name), 'one-time owner setup code');
  return v_m;
end $$;

-- ---------------------------------------------------------------------------
-- Team administration (Owner, MFA required)
-- ---------------------------------------------------------------------------
create or replace function public.require_permission(p_permission text) returns public.memberships
language plpgsql stable security definer set search_path = '' as $$
declare v_m public.memberships;
begin
  if not public.has_permission(p_permission) then
    raise exception 'not authorized: %', p_permission using errcode = '42501';
  end if;
  v_m := public.current_membership();
  return v_m;
end $$;

-- Step 1 (as Owner): reserve an invitation. No auth user exists yet → no access possible.
create or replace function public.team_invite(p_phone text, p_name text, p_role public.app_role,
                                              p_location_ids uuid[], p_reason text default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_new uuid;
begin
  v_me := public.require_permission('team.manage');
  if p_role = 'owner' then raise exception 'cannot invite another owner' using errcode = '42501'; end if;
  if p_phone !~ '^\+[1-9][0-9]{7,14}$' then raise exception 'phone must be E.164' using errcode = '22023'; end if;
  if exists (select 1 from unnest(coalesce(p_location_ids, '{}')) x
             where not exists (select 1 from public.locations l where l.id = x and l.business_id = v_me.business_id)) then
    raise exception 'unknown location' using errcode = '22023';
  end if;
  insert into public.memberships (business_id, phone_e164, display_name, role, status, created_by)
  values (v_me.business_id, p_phone, btrim(p_name), p_role, 'invited', v_me.id)
  returning id into v_new;
  insert into public.membership_locations (membership_id, location_id)
  select v_new, x from unnest(coalesce(p_location_ids, '{}')) x;
  perform public.write_audit(v_me.business_id, 'team.invite', 'membership', v_new::text, null,
    jsonb_build_object('phone', p_phone, 'name', p_name, 'role', p_role, 'locations', p_location_ids), p_reason);
  return v_new;
end $$;

-- Step 2 (service_role, after auth.admin.createUser succeeded): attach auth user + activation code.
-- If auth-user creation failed, the invitation simply stays 'invited' with no user → safe retry.
create or replace function public.team_attach_auth_user(p_membership uuid, p_user uuid, p_code text, p_ttl_minutes int default 1440)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_m public.memberships;
begin
  select * into v_m from public.memberships where id = p_membership for update;
  if v_m.id is null or v_m.status not in ('invited','pending_activation') then
    raise exception 'membership not awaiting activation' using errcode = '22023';
  end if;
  if v_m.user_id is not null and v_m.user_id <> p_user then
    raise exception 'membership already bound to another user' using errcode = '22023';
  end if;
  update public.memberships set user_id = p_user, status = 'pending_activation' where id = p_membership;
  update public.staff_activation_codes set expires_at = least(expires_at, now())
   where membership_id = p_membership and consumed_at is null;
  insert into public.staff_activation_codes (membership_id, code_hash, expires_at)
  values (p_membership, extensions.crypt(p_code, extensions.gen_salt('bf')), now() + make_interval(mins => p_ttl_minutes));
  insert into public.audit_log (business_id, action, entity, entity_id, after_data, reason)
  values (v_m.business_id, 'team.activation_code_issued', 'membership', p_membership::text,
          jsonb_build_object('expires_minutes', p_ttl_minutes), 'issued by owner via server');
end $$;

-- Activation step A (service_role): verify phone + code. Returns user id, or NULL for a wrong code.
create or replace function public.activation_check(p_phone text, p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_m public.memberships; r public.staff_activation_codes;
begin
  select * into v_m from public.memberships where phone_e164 = p_phone and status = 'pending_activation' limit 1;
  if v_m.id is null then raise exception 'invalid activation' using errcode = '28000'; end if;
  select * into r from public.staff_activation_codes
   where membership_id = v_m.id and consumed_at is null and expires_at > now()
   order by created_at desc limit 1 for update;
  if r.id is null or r.attempts >= 5 then raise exception 'invalid activation' using errcode = '28000'; end if;
  update public.staff_activation_codes set attempts = attempts + 1 where id = r.id;
  -- Return NULL (not raise) on a wrong code so the attempt counter is persisted.
  if r.code_hash <> extensions.crypt(p_code, r.code_hash) then
    return null;
  end if;
  return v_m.user_id;
end $$;

-- Activation step B (service_role, after the staff member's own password was set): consume + activate.
create or replace function public.activation_finalize(p_phone text, p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_user uuid; v_m public.memberships;
begin
  v_user := public.activation_check(p_phone, p_code);
  if v_user is null then raise exception 'invalid activation' using errcode = '28000'; end if;
  select * into v_m from public.memberships where user_id = v_user;
  update public.staff_activation_codes set consumed_at = now() where membership_id = v_m.id and consumed_at is null;
  update public.memberships set status = 'active', activated_at = now() where id = v_m.id;
  insert into public.audit_log (business_id, actor_user_id, actor_membership_id, action, entity, entity_id, reason)
  values (v_m.business_id, v_user, v_m.id, 'team.activated', 'membership', v_m.id::text, 'staff set own password');
  return v_m.id;
end $$;

create or replace function public.team_set_status(p_membership uuid, p_status public.membership_status, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_t public.memberships;
begin
  v_me := public.require_permission('team.manage');
  if coalesce(btrim(p_reason), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  select * into v_t from public.memberships where id = p_membership and business_id = v_me.business_id for update;
  if v_t.id is null then raise exception 'not found' using errcode = '22023'; end if;
  if v_t.id = v_me.id or v_t.role = 'owner' then raise exception 'cannot change owner status here' using errcode = '42501'; end if;
  if p_status not in ('active','suspended','deactivated') then raise exception 'invalid status' using errcode = '22023'; end if;
  if p_status = 'active' and v_t.activated_at is null then
    raise exception 'staff must complete activation first' using errcode = '22023';
  end if;
  update public.memberships set status = p_status where id = v_t.id;
  perform public.write_audit(v_me.business_id, 'team.status', 'membership', v_t.id::text,
    jsonb_build_object('status', v_t.status), jsonb_build_object('status', p_status), p_reason);
end $$;

create or replace function public.team_set_role(p_membership uuid, p_role public.app_role, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_t public.memberships;
begin
  v_me := public.require_permission('team.manage');
  if coalesce(btrim(p_reason), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  if p_role = 'owner' then raise exception 'cannot grant owner role' using errcode = '42501'; end if;
  select * into v_t from public.memberships where id = p_membership and business_id = v_me.business_id for update;
  if v_t.id is null then raise exception 'not found' using errcode = '22023'; end if;
  if v_t.id = v_me.id or v_t.role = 'owner' then raise exception 'cannot change owner role' using errcode = '42501'; end if;
  update public.memberships set role = p_role where id = v_t.id;
  perform public.write_audit(v_me.business_id, 'team.role', 'membership', v_t.id::text,
    jsonb_build_object('role', v_t.role), jsonb_build_object('role', p_role), p_reason);
end $$;

create or replace function public.team_set_locations(p_membership uuid, p_all boolean, p_location_ids uuid[], p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_t public.memberships; v_before jsonb;
begin
  v_me := public.require_permission('team.manage');
  select * into v_t from public.memberships where id = p_membership and business_id = v_me.business_id for update;
  if v_t.id is null or v_t.role = 'owner' then raise exception 'not allowed' using errcode = '42501'; end if;
  if exists (select 1 from unnest(coalesce(p_location_ids, '{}')) x
             where not exists (select 1 from public.locations l where l.id = x and l.business_id = v_me.business_id)) then
    raise exception 'unknown location' using errcode = '22023';
  end if;
  select coalesce(jsonb_agg(location_id), '[]') into v_before from public.membership_locations where membership_id = v_t.id;
  delete from public.membership_locations where membership_id = v_t.id;
  insert into public.membership_locations (membership_id, location_id)
  select v_t.id, x from unnest(coalesce(p_location_ids, '{}')) x;
  update public.memberships set all_locations = coalesce(p_all, false) where id = v_t.id;
  perform public.write_audit(v_me.business_id, 'team.locations', 'membership', v_t.id::text,
    jsonb_build_object('all', v_t.all_locations, 'locations', v_before),
    jsonb_build_object('all', p_all, 'locations', p_location_ids), p_reason);
end $$;

create or replace function public.location_create(p_code text, p_name text, p_kind public.location_kind)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_id uuid;
begin
  v_me := public.require_permission('settings.manage');
  insert into public.locations (business_id, code, name, kind)
  values (v_me.business_id, upper(btrim(p_code)), btrim(p_name), p_kind) returning id into v_id;
  perform public.write_audit(v_me.business_id, 'location.create', 'location', v_id::text, null,
    jsonb_build_object('code', p_code, 'name', p_name, 'kind', p_kind), null);
  return v_id;
end $$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.businesses             enable row level security;
alter table public.locations              enable row level security;
alter table public.memberships            enable row level security;
alter table public.membership_locations   enable row level security;
alter table public.permissions            enable row level security;
alter table public.role_permissions       enable row level security;
alter table public.audit_log              enable row level security;
alter table public.owner_setup_codes      enable row level security;
alter table public.staff_activation_codes enable row level security;

create policy businesses_read on public.businesses for select to authenticated
  using (public.is_business_member(id));

create policy locations_read on public.locations for select to authenticated
  using (public.can_access_location(id) or (public.is_business_member(business_id) and public.has_permission('settings.manage')));

create policy memberships_read_self on public.memberships for select to authenticated
  using (user_id = auth.uid());
create policy memberships_read_team on public.memberships for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('team.view'));

create policy membership_locations_read on public.membership_locations for select to authenticated
  using (exists (select 1 from public.memberships m where m.id = membership_id
                 and (m.user_id = auth.uid() or (public.is_business_member(m.business_id) and public.has_permission('team.view')))));

create policy permissions_read on public.permissions for select to authenticated using (true);
create policy role_permissions_read on public.role_permissions for select to authenticated using (true);

create policy audit_read on public.audit_log for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('audit.view'));
-- owner_setup_codes / staff_activation_codes: no policies → no client access at all.

-- ---------------------------------------------------------------------------
-- Grants: clients read through RLS, never write tables directly.
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

grant select on public.businesses, public.locations, public.memberships, public.membership_locations,
                public.permissions, public.role_permissions, public.audit_log to authenticated;

grant execute on function
  public.current_membership(), public.current_aal(), public.has_permission(text),
  public.is_business_member(uuid), public.can_access_location(uuid), public.my_workspace(),
  public.team_invite(text, text, public.app_role, uuid[], text),
  public.team_set_status(uuid, public.membership_status, text),
  public.team_set_role(uuid, public.app_role, text),
  public.team_set_locations(uuid, boolean, uuid[], text),
  public.location_create(text, text, public.location_kind)
to authenticated;

-- Server-only functions (called with the service_role key from server code).
grant execute on function
  public.setup_create_business(text, text, text, int), public.setup_check_owner_code(text),
  public.setup_finalize_owner(text, uuid, text, text),
  public.team_attach_auth_user(uuid, uuid, text, int),
  public.activation_check(text, text), public.activation_finalize(text, text)
to service_role;

-- Default privileges so future objects are not accidentally exposed.
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

commit;
