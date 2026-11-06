-- DIROMA Business OS — Milestone F: team targets, content log, tasks, inquiries (attribution), commissions, public catalogue.
--
-- Principles from the brief:
--  * Content targets default to 3 reels/day, 21/week, 3 × days-in-month per calendar month, and 100 product posts/month,
--    unless the Owner overrides them. Sales targets are NEVER invented: none exists until the Owner sets one.
--  * Content counts only with evidence (a link) and can be verified by someone other than the poster.
--  * A sale is attributed to an inquiry only when staff explicitly link them — no guessed attribution.
--  * Commissions: Owner-configured rates only; calculated → independently approved (accrued) → paid once; returns claw back.
--  * The public catalogue exposes only explicitly published fields: no costs, no wholesale prices, no exact stock.

begin;

insert into public.permissions (code, description) values
  ('team.work',            'Log content, update own tasks, record customer inquiries'),
  ('targets.manage',       'Set business, location and staff targets'),
  ('tasks.assign',         'Assign, verify and cancel team tasks'),
  ('content.verify',       'Verify content posted by others'),
  ('commissions.calculate','Calculate commission runs'),
  ('commissions.approve',  'Approve and pay commissions; configure commission plans');
insert into public.role_permissions (role, permission)
select 'owner', code from public.permissions where code in ('team.work','targets.manage','tasks.assign','content.verify','commissions.calculate','commissions.approve');
insert into public.role_permissions (role, permission) values
  ('manager','team.work'), ('manager','tasks.assign'), ('manager','content.verify'), ('manager','commissions.calculate'),
  ('sales_staff','team.work'), ('storekeeper','team.work');

insert into public.ledger_accounts values ('2200','Commissions payable','liability'), ('6500','Staff commissions','expense');

-- ---------------------------------------------------------------------------
-- Targets
-- ---------------------------------------------------------------------------
create table public.targets (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references public.businesses(id),
  metric         text not null check (metric in ('net_sales','units','collections','reels','product_posts','follow_ups','new_customers')),
  scope          text not null check (scope in ('business','location','member')),
  location_id    uuid references public.locations(id),
  membership_id  uuid references public.memberships(id),
  period_kind    text not null check (period_kind in ('day','week','month')),
  period_start   date not null,
  target_value   bigint not null check (target_value >= 0),
  note           text,
  set_by         uuid not null references public.memberships(id),
  created_at     timestamptz not null default now(),
  check ((scope = 'location') = (location_id is not null)),
  check ((scope = 'member') = (membership_id is not null))
);
create unique index targets_unique on public.targets (business_id, metric, scope, coalesce(location_id, '00000000-0000-0000-0000-000000000000'),
  coalesce(membership_id, '00000000-0000-0000-0000-000000000000'), period_kind, period_start);

create or replace function public._period_start(p_kind text, p_date date) returns date
language sql immutable set search_path = '' as $$
  select case p_kind when 'day' then p_date when 'week' then p_date - ((extract(isodow from p_date)::int) - 1)
                     else date_trunc('month', p_date)::date end
$$;
create or replace function public._period_end(p_kind text, p_start date) returns date
language sql immutable set search_path = '' as $$
  select case p_kind when 'day' then p_start when 'week' then p_start + 6 else (p_start + interval '1 month' - interval '1 day')::date end
$$;

-- Built-in content defaults (brief §13). Sales metrics have no default.
create or replace function public._default_target(p_metric text, p_kind text, p_start date) returns bigint
language sql immutable set search_path = '' as $$
  select case
    when p_metric = 'reels' and p_kind = 'day' then 3
    when p_metric = 'reels' and p_kind = 'week' then 21
    when p_metric = 'reels' and p_kind = 'month' then 3 * extract(day from (p_start + interval '1 month' - interval '1 day'))::bigint
    when p_metric = 'product_posts' and p_kind = 'month' then 100
    else null end
$$;

create or replace function public.target_set(p_metric text, p_scope text, p_location uuid, p_member uuid, p_kind text, p_date date,
                                             p_value bigint, p_note text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_start date; v uuid; v_old bigint;
begin
  v_me := public.require_permission('targets.manage');
  if p_value is null or p_value < 0 then raise exception 'target must be zero or positive' using errcode = '22023'; end if;
  if p_scope = 'location' and not exists (select 1 from public.locations where id = p_location and business_id = v_me.business_id) then
    raise exception 'unknown location' using errcode = '22023'; end if;
  if p_scope = 'member' and not exists (select 1 from public.memberships where id = p_member and business_id = v_me.business_id) then
    raise exception 'unknown staff member' using errcode = '22023'; end if;
  v_start := public._period_start(p_kind, p_date);
  select id, target_value into v, v_old from public.targets
   where business_id = v_me.business_id and metric = p_metric and scope = p_scope and period_kind = p_kind and period_start = v_start
     and location_id is not distinct from (case when p_scope = 'location' then p_location end)
     and membership_id is not distinct from (case when p_scope = 'member' then p_member end) for update;
  if v is null then
    insert into public.targets (business_id, metric, scope, location_id, membership_id, period_kind, period_start, target_value, note, set_by)
    values (v_me.business_id, p_metric, p_scope, case when p_scope = 'location' then p_location end, case when p_scope = 'member' then p_member end,
            p_kind, v_start, p_value, nullif(btrim(p_note), ''), v_me.id) returning id into v;
  else
    update public.targets set target_value = p_value, note = nullif(btrim(p_note), ''), set_by = v_me.id where id = v;
  end if;
  perform public.write_audit(v_me.business_id, 'target.set', 'target', v::text, jsonb_build_object('value', v_old),
    jsonb_build_object('metric', p_metric, 'scope', p_scope, 'period', p_kind, 'start', v_start, 'value', p_value), p_note);
  return v;
end $$;

-- ---------------------------------------------------------------------------
-- Content log (evidence required)
-- ---------------------------------------------------------------------------
create table public.content_posts (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id),
  kind         text not null check (kind in ('reel','product_post','story')),
  platform     text not null check (platform in ('instagram','tiktok','facebook','whatsapp','youtube','other')),
  url          text not null check (url ~ '^https://\S{6,}$' and length(url) <= 500),
  design_id    uuid references public.designs(id),
  posted_on    date not null,
  posted_by    uuid not null references public.memberships(id),
  note         text,
  status       text not null default 'logged' check (status in ('logged','verified','rejected')),
  verified_by  uuid references public.memberships(id),
  verified_at  timestamptz,
  verify_note  text,
  created_at   timestamptz not null default now(),
  unique (business_id, url)
);

create or replace function public.content_log(p_kind text, p_platform text, p_url text, p_design uuid, p_posted_on date, p_note text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v uuid; v_today date;
begin
  v_me := public.require_permission('team.work');
  v_today := public._business_date(v_me.business_id, now());
  if p_posted_on is null or p_posted_on > v_today or p_posted_on < v_today - 31 then
    raise exception 'posting date must be within the last 31 days' using errcode = '22023';
  end if;
  if exists (select 1 from public.content_posts where business_id = v_me.business_id and url = btrim(p_url)) then
    raise exception 'this link was already logged' using errcode = '22023';
  end if;
  insert into public.content_posts (business_id, kind, platform, url, design_id, posted_on, posted_by, note)
  values (v_me.business_id, p_kind, p_platform, btrim(p_url), p_design, p_posted_on, v_me.id, nullif(btrim(p_note), '')) returning id into v;
  return v;
end $$;

create or replace function public.content_verify(p_post uuid, p_approve boolean, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; c public.content_posts;
begin
  v_me := public.require_permission('content.verify');
  select * into c from public.content_posts where id = p_post and business_id = v_me.business_id for update;
  if c.id is null or c.status <> 'logged' then raise exception 'post is not awaiting verification' using errcode = '22023'; end if;
  if c.posted_by = v_me.id then raise exception 'cannot verify your own post' using errcode = '42501'; end if;
  if not p_approve and coalesce(btrim(p_note), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  update public.content_posts set status = case when p_approve then 'verified' else 'rejected' end, verified_by = v_me.id, verified_at = now(),
         verify_note = nullif(btrim(p_note), '') where id = c.id;
end $$;

-- ---------------------------------------------------------------------------
-- Tasks
-- ---------------------------------------------------------------------------
create table public.team_tasks (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references public.businesses(id),
  title         text not null check (length(btrim(title)) between 3 and 140),
  details       text,
  assignee      uuid not null references public.memberships(id),
  location_id   uuid references public.locations(id),
  due_at        timestamptz not null,
  priority      text not null default 'normal' check (priority in ('low','normal','high')),
  status        text not null default 'open' check (status in ('open','done','verified','cancelled')),
  evidence      text,
  created_by    uuid not null references public.memberships(id),
  created_at    timestamptz not null default now(),
  completed_at  timestamptz,
  verified_by   uuid references public.memberships(id),
  verified_at   timestamptz,
  review_note   text
);
create index team_tasks_assignee on public.team_tasks (assignee, status);

create or replace function public.task_create(p_title text, p_details text, p_assignee uuid, p_location uuid, p_due_at timestamptz, p_priority text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v uuid;
begin
  v_me := public.require_permission('tasks.assign');
  if not exists (select 1 from public.memberships where id = p_assignee and business_id = v_me.business_id and status = 'active') then
    raise exception 'assignee must be an active staff member' using errcode = '22023';
  end if;
  if p_due_at is null then raise exception 'due time required' using errcode = '22023'; end if;
  insert into public.team_tasks (business_id, title, details, assignee, location_id, due_at, priority, created_by)
  values (v_me.business_id, btrim(p_title), nullif(btrim(p_details), ''), p_assignee, p_location, p_due_at, coalesce(p_priority, 'normal'), v_me.id)
  returning id into v;
  perform public.write_audit(v_me.business_id, 'task.create', 'team_task', v::text, null, jsonb_build_object('title', p_title, 'assignee', p_assignee), null);
  return v;
end $$;

create or replace function public.task_complete(p_task uuid, p_evidence text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; t public.team_tasks;
begin
  v_me := public.require_permission('team.work');
  select * into t from public.team_tasks where id = p_task and business_id = v_me.business_id for update;
  if t.id is null or t.status <> 'open' then raise exception 'task is not open' using errcode = '22023'; end if;
  if t.assignee <> v_me.id then raise exception 'only the assignee can complete this task' using errcode = '42501'; end if;
  if coalesce(btrim(p_evidence), '') = '' then raise exception 'evidence required (what was done, link or photo reference)' using errcode = '22023'; end if;
  update public.team_tasks set status = 'done', evidence = btrim(p_evidence), completed_at = now() where id = t.id;
end $$;

create or replace function public.task_review(p_task uuid, p_decision text, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; t public.team_tasks;
begin
  v_me := public.require_permission('tasks.assign');
  select * into t from public.team_tasks where id = p_task and business_id = v_me.business_id for update;
  if t.id is null then raise exception 'not found' using errcode = '22023'; end if;
  if p_decision = 'cancel' then
    if t.status in ('verified','cancelled') or coalesce(btrim(p_note), '') = '' then raise exception 'cannot cancel (reason required)' using errcode = '22023'; end if;
    update public.team_tasks set status = 'cancelled', review_note = p_note, verified_by = v_me.id, verified_at = now() where id = t.id;
  elsif p_decision in ('verify','reopen') then
    if t.status <> 'done' then raise exception 'task is not awaiting review' using errcode = '22023'; end if;
    if t.assignee = v_me.id then raise exception 'cannot review your own task' using errcode = '42501'; end if;
    if p_decision = 'reopen' and coalesce(btrim(p_note), '') = '' then raise exception 'say what is missing' using errcode = '22023'; end if;
    update public.team_tasks set status = case when p_decision = 'verify' then 'verified' else 'open' end,
           verified_by = v_me.id, verified_at = now(), review_note = nullif(btrim(p_note), '') where id = t.id;
  else
    raise exception 'decision must be verify, reopen or cancel' using errcode = '22023';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Inquiries → follow-ups → visit → (explicitly) linked sale
-- ---------------------------------------------------------------------------
create table public.inquiries (
  id                uuid primary key default gen_random_uuid(),
  business_id       uuid not null references public.businesses(id),
  ref_no            text not null,
  name              text not null check (length(btrim(name)) between 2 and 120),
  phone_e164        text check (phone_e164 is null or phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  customer_id       uuid references public.customers(id),
  channel           text not null check (channel in ('instagram','whatsapp','tiktok','facebook','walk_in','phone','referral','other')),
  interest          text,
  design_id         uuid references public.designs(id),
  status            text not null default 'new' check (status in ('new','followed_up','visited','won','lost')),
  assigned_to       uuid references public.memberships(id),
  next_follow_up_on date,
  linked_sale_id    uuid unique references public.sales(id),
  lost_reason       text,
  created_by        uuid not null references public.memberships(id),
  created_at        timestamptz not null default now(),
  unique (business_id, ref_no)
);
create table public.inquiry_events (
  id          bigint generated always as identity primary key,
  inquiry_id  uuid not null references public.inquiries(id),
  kind        text not null check (kind in ('created','follow_up','visit','note','won','lost')),
  note        text,
  created_by  uuid not null references public.memberships(id),
  created_at  timestamptz not null default now()
);

create or replace function public.inquiry_create(p_name text, p_phone text, p_customer uuid, p_channel text, p_interest text, p_design uuid,
                                                 p_assigned_to uuid, p_next_follow_up date)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v uuid;
begin
  v_me := public.require_permission('team.work');
  if p_customer is not null and not exists (select 1 from public.customers where id = p_customer and business_id = v_me.business_id) then
    raise exception 'unknown customer' using errcode = '22023'; end if;
  if p_assigned_to is not null and not exists (select 1 from public.memberships where id = p_assigned_to and business_id = v_me.business_id and status = 'active') then
    raise exception 'unknown staff member' using errcode = '22023'; end if;
  insert into public.inquiries (business_id, ref_no, name, phone_e164, customer_id, channel, interest, design_id, assigned_to, next_follow_up_on, created_by)
  values (v_me.business_id, public._next_ref(v_me.business_id, 'INQ'), btrim(p_name), p_phone, p_customer, p_channel, nullif(btrim(p_interest), ''),
          p_design, coalesce(p_assigned_to, v_me.id), p_next_follow_up, v_me.id) returning id into v;
  insert into public.inquiry_events (inquiry_id, kind, created_by) values (v, 'created', v_me.id);
  return v;
end $$;

create or replace function public.inquiry_event(p_inquiry uuid, p_kind text, p_note text, p_next_follow_up date)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; q public.inquiries;
begin
  v_me := public.require_permission('team.work');
  select * into q from public.inquiries where id = p_inquiry and business_id = v_me.business_id for update;
  if q.id is null then raise exception 'not found' using errcode = '22023'; end if;
  if q.status in ('won','lost') then raise exception 'inquiry is closed' using errcode = '22023'; end if;
  if p_kind not in ('follow_up','visit','note','lost') then raise exception 'invalid event' using errcode = '22023'; end if;
  if p_kind = 'lost' and coalesce(btrim(p_note), '') = '' then raise exception 'say why it was lost' using errcode = '22023'; end if;
  insert into public.inquiry_events (inquiry_id, kind, note, created_by) values (q.id, p_kind, nullif(btrim(p_note), ''), v_me.id);
  update public.inquiries set
    status = case p_kind when 'follow_up' then case when q.status = 'new' then 'followed_up' else q.status end
                         when 'visit' then 'visited' when 'lost' then 'lost' else q.status end,
    lost_reason = case when p_kind = 'lost' then p_note else lost_reason end,
    next_follow_up_on = case when p_kind = 'lost' then null else coalesce(p_next_follow_up, next_follow_up_on) end
  where id = q.id;
end $$;

-- Attribution only by an explicit, audited link. If the inquiry has a customer, the sale must be that customer's.
create or replace function public.inquiry_link_sale(p_inquiry uuid, p_sale uuid, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; q public.inquiries; s public.sales;
begin
  v_me := public.require_permission('team.work');
  select * into q from public.inquiries where id = p_inquiry and business_id = v_me.business_id for update;
  if q.id is null or q.status in ('won','lost') then raise exception 'inquiry is not open' using errcode = '22023'; end if;
  select * into s from public.sales where id = p_sale and business_id = v_me.business_id;
  if s.id is null then raise exception 'unknown sale' using errcode = '22023'; end if;
  if exists (select 1 from public.inquiries where linked_sale_id = s.id) then raise exception 'this sale is already linked to another inquiry' using errcode = '22023'; end if;
  if s.sold_at < q.created_at - interval '1 day' then raise exception 'sale happened before the inquiry' using errcode = '22023'; end if;
  if q.customer_id is not null and s.customer_id is distinct from q.customer_id then
    raise exception 'sale belongs to a different customer' using errcode = '22023';
  end if;
  if q.customer_id is null and coalesce(btrim(p_note), '') = '' then
    raise exception 'explain how you know this sale came from this inquiry' using errcode = '22023';
  end if;
  update public.inquiries set status = 'won', linked_sale_id = s.id, next_follow_up_on = null where id = q.id;
  insert into public.inquiry_events (inquiry_id, kind, note, created_by) values (q.id, 'won', coalesce(nullif(btrim(p_note), ''), s.ref_no), v_me.id);
  perform public.write_audit(v_me.business_id, 'inquiry.link_sale', 'inquiry', q.id::text, null, jsonb_build_object('sale', s.ref_no), p_note);
end $$;

-- ---------------------------------------------------------------------------
-- Commissions
-- ---------------------------------------------------------------------------
create table public.commission_plans (
  id                  uuid primary key default gen_random_uuid(),
  business_id         uuid not null references public.businesses(id),
  name                text not null,
  applies_role        public.app_role,
  membership_id       uuid references public.memberships(id),
  basis               text not null check (basis in ('net_sales','collections')),
  rate_pct            numeric(5,2) not null check (rate_pct > 0 and rate_pct <= 50),
  min_basis           bigint not null default 0 check (min_basis >= 0),
  require_tasks_done  boolean not null default false,
  is_active           boolean not null default true,
  created_by          uuid not null references public.memberships(id),
  created_at          timestamptz not null default now(),
  check ((applies_role is null) <> (membership_id is null))
);

create type public.commission_status as enum ('calculated', 'approved', 'paid', 'cancelled');

create table public.commission_runs (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references public.businesses(id),
  ref_no         text not null,
  period_from    date not null,
  period_to      date not null,
  status         public.commission_status not null default 'calculated',
  total          bigint not null default 0,
  calculated_by  uuid not null references public.memberships(id),
  calculated_at  timestamptz not null default now(),
  approved_by    uuid references public.memberships(id),
  approved_at    timestamptz,
  approval_note  text,
  paid_by        uuid references public.memberships(id),
  paid_at        timestamptz,
  money_account_id uuid references public.money_accounts(id),
  cancel_reason  text,
  check (period_to >= period_from),
  unique (business_id, ref_no)
);
create table public.commission_lines (
  id               uuid primary key default gen_random_uuid(),
  run_id           uuid not null references public.commission_runs(id),
  membership_id    uuid not null references public.memberships(id),
  plan_id          uuid not null references public.commission_plans(id),
  basis            text not null,
  basis_amount     bigint not null,
  returns_deducted bigint not null default 0,
  net_basis        bigint not null,
  rate_pct         numeric(5,2) not null,
  open_tasks       int not null default 0,
  eligible         boolean not null,
  amount           bigint not null check (amount >= 0),
  note             text
);

create or replace function public.commission_plan_save(p_id uuid, p_name text, p_role public.app_role, p_member uuid, p_basis text,
                                                       p_rate numeric, p_min bigint, p_require_tasks boolean, p_active boolean)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v uuid;
begin
  v_me := public.require_permission('commissions.approve');
  if p_id is null then
    insert into public.commission_plans (business_id, name, applies_role, membership_id, basis, rate_pct, min_basis, require_tasks_done, is_active, created_by)
    values (v_me.business_id, btrim(p_name), p_role, p_member, p_basis, p_rate, coalesce(p_min, 0), coalesce(p_require_tasks, false), coalesce(p_active, true), v_me.id)
    returning id into v;
  else
    update public.commission_plans set name = btrim(p_name), basis = p_basis, rate_pct = p_rate, min_basis = coalesce(p_min, 0),
           require_tasks_done = coalesce(p_require_tasks, false), is_active = coalesce(p_active, true)
     where id = p_id and business_id = v_me.business_id returning id into v;
    if v is null then raise exception 'not found' using errcode = '22023'; end if;
  end if;
  perform public.write_audit(v_me.business_id, 'commission.plan', 'commission_plan', v::text, null,
    jsonb_build_object('basis', p_basis, 'rate', p_rate, 'role', p_role, 'member', p_member, 'active', p_active), null);
  return v;
end $$;

create or replace function public.commission_calculate(p_from date, p_to date)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_run uuid; m record; pl public.commission_plans; v_basis bigint; v_ret bigint; v_net bigint;
        v_open int; v_ok boolean; v_amt bigint; v_total bigint := 0;
begin
  v_me := public.require_permission('commissions.calculate');
  if p_from is null or p_to is null or p_to < p_from then raise exception 'invalid period' using errcode = '22023'; end if;
  if p_to > public._business_date(v_me.business_id, now()) then raise exception 'period must have ended' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_me.business_id::text || 'commission', 0));
  if exists (select 1 from public.commission_runs where business_id = v_me.business_id and status <> 'cancelled'
             and daterange(period_from, period_to, '[]') && daterange(p_from, p_to, '[]')) then
    raise exception 'an active commission run already covers part of this period' using errcode = '22023';
  end if;
  insert into public.commission_runs (business_id, ref_no, period_from, period_to, calculated_by)
  values (v_me.business_id, public._next_ref(v_me.business_id, 'COM'), p_from, p_to, v_me.id) returning id into v_run;

  for m in select * from public.memberships where business_id = v_me.business_id and status in ('active','suspended') loop
    select * into pl from public.commission_plans where business_id = v_me.business_id and is_active and membership_id = m.id order by created_at desc limit 1;
    if pl.id is null then
      select * into pl from public.commission_plans where business_id = v_me.business_id and is_active and applies_role = m.role order by created_at desc limit 1;
    end if;
    continue when pl.id is null;
    if pl.basis = 'net_sales' then
      select coalesce(sum(s.total - s.delivery_fee), 0) into v_basis from public.sales s
       where s.sold_by = m.id and public._business_date(s.business_id, s.sold_at) between p_from and p_to;
      select coalesce(sum(r.amount), 0) into v_ret from public.sale_returns r join public.sales s on s.id = r.sale_id
       where s.sold_by = m.id and r.status = 'approved' and public._business_date(r.business_id, r.decided_at) between p_from and p_to;
    else
      select coalesce(sum(p.amount), 0) into v_basis from public.payments p
       where p.received_by = m.id and public._business_date(p.business_id, p.received_at) between p_from and p_to;
      v_ret := 0;
    end if;
    v_net := greatest(v_basis - v_ret, 0);
    select count(*) into v_open from public.team_tasks t
     where t.assignee = m.id and t.status in ('open','done') and public._business_date(t.business_id, t.due_at) <= p_to;
    v_ok := v_net >= pl.min_basis and (not pl.require_tasks_done or v_open = 0);
    v_amt := case when v_ok then round(v_net * pl.rate_pct / 100)::bigint else 0 end;
    insert into public.commission_lines (run_id, membership_id, plan_id, basis, basis_amount, returns_deducted, net_basis, rate_pct, open_tasks, eligible, amount, note)
    values (v_run, m.id, pl.id, pl.basis, v_basis, v_ret, v_net, pl.rate_pct, v_open, v_ok, v_amt,
            case when not v_ok and v_net < pl.min_basis then 'below minimum' when not v_ok then 'tasks not completed/verified' end);
    v_total := v_total + v_amt;
    pl := null;
  end loop;
  update public.commission_runs set total = v_total where id = v_run;
  perform public.write_audit(v_me.business_id, 'commission.calculate', 'commission_run', v_run::text, null,
    jsonb_build_object('from', p_from, 'to', p_to, 'total', v_total), null);
  return v_run;
end $$;

-- Approval accrues the expense (Dr 6500 / Cr 2200). Approver must differ from the calculator unless the Owner overrides with a reason.
create or replace function public.commission_approve(p_run uuid, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; r public.commission_runs;
begin
  v_me := public.require_permission('commissions.approve');
  select * into r from public.commission_runs where id = p_run and business_id = v_me.business_id for update;
  if r.id is null or r.status <> 'calculated' then raise exception 'run is not awaiting approval' using errcode = '22023'; end if;
  if r.calculated_by = v_me.id and coalesce(btrim(p_note), '') = '' then
    raise exception 'you calculated this run: give a reason to approve it yourself' using errcode = '42501';
  end if;
  perform public._post_journal(v_me.business_id, r.period_to, 'commission_accrual', r.id, r.ref_no, v_me.id,
    jsonb_build_array(public._jl('6500', r.total, 0), public._jl('2200', 0, r.total)));
  update public.commission_runs set status = 'approved', approved_by = v_me.id, approved_at = now(), approval_note = nullif(btrim(p_note), '') where id = r.id;
  perform public.write_audit(v_me.business_id, 'commission.approve', 'commission_run', r.id::text, null,
    jsonb_build_object('total', r.total, 'self_approved', r.calculated_by = v_me.id), p_note);
end $$;

create or replace function public.commission_pay(p_run uuid, p_account uuid, p_reference text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; r public.commission_runs; a public.money_accounts;
begin
  v_me := public.require_permission('commissions.approve');
  select * into r from public.commission_runs where id = p_run and business_id = v_me.business_id for update;
  if r.id is null or r.status <> 'approved' then raise exception 'run is not approved (or already paid)' using errcode = '22023'; end if;
  select * into a from public.money_accounts where id = p_account and business_id = v_me.business_id and is_active and kind <> 'cash';
  if a.id is null then raise exception 'pay commissions from a bank or mobile account' using errcode = '22023'; end if;
  perform public._post_journal(v_me.business_id, public._business_date(v_me.business_id, now()), 'commission_payment', r.id, r.ref_no, v_me.id,
    jsonb_build_array(public._jl('2200', r.total, 0), public._jl('1000', 0, r.total, a.id)));
  update public.commission_runs set status = 'paid', paid_by = v_me.id, paid_at = now(), money_account_id = a.id where id = r.id;
  perform public.write_audit(v_me.business_id, 'commission.pay', 'commission_run', r.id::text, null,
    jsonb_build_object('total', r.total, 'account', a.code), p_reference);
end $$;

create or replace function public.commission_cancel(p_run uuid, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; r public.commission_runs;
begin
  v_me := public.require_permission('commissions.approve');
  if coalesce(btrim(p_reason), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  select * into r from public.commission_runs where id = p_run and business_id = v_me.business_id for update;
  if r.id is null or r.status not in ('calculated','approved') then raise exception 'only unpaid runs can be cancelled' using errcode = '22023'; end if;
  if r.status = 'approved' then
    perform public._post_journal(v_me.business_id, public._business_date(v_me.business_id, now()), 'commission_reversal', r.id, r.ref_no, v_me.id,
      jsonb_build_array(public._jl('2200', r.total, 0), public._jl('6500', 0, r.total)));
  end if;
  update public.commission_runs set status = 'cancelled', cancel_reason = p_reason where id = r.id;
  perform public.write_audit(v_me.business_id, 'commission.cancel', 'commission_run', r.id::text, null, null, p_reason);
end $$;

-- ---------------------------------------------------------------------------
-- Progress (targets vs actuals)
-- ---------------------------------------------------------------------------
create or replace function public._metric_actual(b uuid, p_metric text, p_from date, p_to date, p_loc uuid, p_member uuid) returns bigint
language plpgsql stable security definer set search_path = '' as $$
declare v bigint;
begin
  case p_metric
    when 'net_sales' then
      select coalesce(sum(s.total - s.delivery_fee), 0) into v from public.sales s
       where s.business_id = b and public._business_date(b, s.sold_at) between p_from and p_to
         and (p_loc is null or s.location_id = p_loc) and (p_member is null or s.sold_by = p_member);
      v := v - (select coalesce(sum(r.amount), 0) from public.sale_returns r join public.sales s on s.id = r.sale_id
                where r.business_id = b and r.status = 'approved' and public._business_date(b, r.decided_at) between p_from and p_to
                  and (p_loc is null or s.location_id = p_loc) and (p_member is null or s.sold_by = p_member));
    when 'units' then
      select coalesce(sum(sl.qty), 0) into v from public.sale_lines sl join public.sales s on s.id = sl.sale_id
       where s.business_id = b and public._business_date(b, s.sold_at) between p_from and p_to
         and (p_loc is null or s.location_id = p_loc) and (p_member is null or s.sold_by = p_member);
    when 'collections' then
      select coalesce(sum(p.amount), 0) into v from public.payments p
       where p.business_id = b and public._business_date(b, p.received_at) between p_from and p_to
         and (p_loc is null or p.location_id = p_loc) and (p_member is null or p.received_by = p_member);
    when 'reels', 'product_posts' then
      select count(*) into v from public.content_posts c
       where c.business_id = b and c.kind = case p_metric when 'reels' then 'reel' else 'product_post' end
         and c.status <> 'rejected' and c.posted_on between p_from and p_to and (p_member is null or c.posted_by = p_member);
    when 'follow_ups' then
      select count(*) into v from public.inquiry_events e join public.inquiries q on q.id = e.inquiry_id
       where q.business_id = b and e.kind in ('follow_up','visit') and public._business_date(b, e.created_at) between p_from and p_to
         and (p_member is null or e.created_by = p_member);
    when 'new_customers' then
      select count(*) into v from public.customers c
       where c.business_id = b and public._business_date(b, c.created_at) between p_from and p_to and (p_member is null or c.created_by = p_member);
    else v := null;
  end case;
  return v;
end $$;

create or replace function public.target_progress(p_metric text, p_kind text, p_date date, p_scope text, p_location uuid, p_member uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_me public.memberships; v_start date; v_end date; t public.targets; v_target bigint; v_source text; v_actual bigint; v_verified bigint;
begin
  v_me := public.current_membership();
  if v_me.id is null then raise exception 'not authorized' using errcode = '42501'; end if;
  if not (public.has_permission('targets.manage') or public.has_permission('reports.view')) then
    -- staff may see their own targets and the business content targets only
    if not ((p_scope = 'member' and p_member = v_me.id) or (p_scope = 'business' and p_metric in ('reels','product_posts'))) then
      raise exception 'not authorized' using errcode = '42501';
    end if;
  end if;
  v_start := public._period_start(p_kind, p_date); v_end := public._period_end(p_kind, v_start);
  select * into t from public.targets where business_id = v_me.business_id and metric = p_metric and scope = p_scope and period_kind = p_kind
     and period_start = v_start and location_id is not distinct from (case when p_scope = 'location' then p_location end)
     and membership_id is not distinct from (case when p_scope = 'member' then p_member end);
  if t.id is not null then v_target := t.target_value; v_source := 'owner';
  elsif p_scope = 'business' then v_target := public._default_target(p_metric, p_kind, v_start); v_source := case when v_target is null then 'none' else 'default' end;
  else v_source := 'none'; end if;
  v_actual := public._metric_actual(v_me.business_id, p_metric, v_start, v_end,
                case when p_scope = 'location' then p_location end, case when p_scope = 'member' then p_member end);
  if p_metric in ('reels','product_posts') then
    select count(*) into v_verified from public.content_posts c where c.business_id = v_me.business_id
       and c.kind = case p_metric when 'reels' then 'reel' else 'product_post' end and c.status = 'verified'
       and c.posted_on between v_start and v_end and (p_scope <> 'member' or c.posted_by = p_member);
  end if;
  return jsonb_build_object('metric', p_metric, 'period', jsonb_build_object('kind', p_kind, 'from', v_start, 'to', v_end),
    'target', v_target, 'source', v_source, 'actual', v_actual, 'verified', v_verified,
    'pct', case when v_target > 0 then round(v_actual::numeric * 100 / v_target, 1) end);
end $$;

create or replace function public.inquiry_funnel(p_from date, p_to date)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare b uuid;
begin
  if not (public.has_permission('reports.view') or public.has_permission('targets.manage')) then raise exception 'not authorized' using errcode = '42501'; end if;
  b := (public.current_membership()).business_id;
  return (select coalesce(jsonb_agg(jsonb_build_object('channel', channel, 'inquiries', n, 'followed_up', f, 'visited', vis, 'won_linked', w, 'lost', l,
                   'linked_sales_value', val) order by n desc), '[]')
    from (select q.channel, count(*) n,
            count(*) filter (where q.status in ('followed_up','visited','won')) f, count(*) filter (where q.status in ('visited','won')) vis,
            count(*) filter (where q.status = 'won' and q.linked_sale_id is not null) w, count(*) filter (where q.status = 'lost') l,
            coalesce(sum(s.total) filter (where q.linked_sale_id is not null), 0) val
          from public.inquiries q left join public.sales s on s.id = q.linked_sale_id
          where q.business_id = b and public._business_date(b, q.created_at) between p_from and p_to group by q.channel) t);
end $$;

-- ---------------------------------------------------------------------------
-- Public catalogue (explicitly published fields only)
-- ---------------------------------------------------------------------------
alter table public.businesses
  add column catalogue_enabled boolean not null default false,
  add column catalogue_slug text unique check (catalogue_slug is null or catalogue_slug ~ '^[a-z0-9-]{3,40}$'),
  add column catalogue_whatsapp text check (catalogue_whatsapp is null or catalogue_whatsapp ~ '^\+[1-9][0-9]{7,14}$');
alter table public.designs
  add column published boolean not null default false,
  add column public_description text,
  add column show_price boolean not null default true;

create or replace function public.catalogue_configure(p_enabled boolean, p_slug text, p_whatsapp text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships;
begin
  v_me := public.require_permission('settings.manage');
  update public.businesses set catalogue_enabled = coalesce(p_enabled, false), catalogue_slug = nullif(lower(btrim(p_slug)), ''),
         catalogue_whatsapp = nullif(btrim(p_whatsapp), '') where id = v_me.business_id;
  perform public.write_audit(v_me.business_id, 'catalogue.configure', 'business', v_me.business_id::text, null,
    jsonb_build_object('enabled', p_enabled, 'slug', p_slug), null);
end $$;

create or replace function public.design_publish(p_design uuid, p_published boolean, p_show_price boolean, p_description text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships;
begin
  v_me := public.require_permission('products.manage');
  update public.designs set published = coalesce(p_published, false), show_price = coalesce(p_show_price, true),
         public_description = nullif(btrim(p_description), '') where id = p_design and business_id = v_me.business_id;
  if not found then raise exception 'not found' using errcode = '22023'; end if;
  perform public.write_audit(v_me.business_id, 'design.publish', 'design', p_design::text, null,
    jsonb_build_object('published', p_published, 'show_price', p_show_price), null);
end $$;

-- Callable without login. Returns only published designs, retail "from" price (if allowed), and per-size availability as yes/no.
create or replace function public.public_catalogue(p_slug text)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when b.id is null then null else jsonb_build_object(
    'business', b.name, 'slogan', b.slogan, 'whatsapp', b.catalogue_whatsapp,
    'designs', coalesce((select jsonb_agg(jsonb_build_object(
        'code', d.code, 'name', d.name, 'category', d.category, 'description', d.public_description,
        'from_price', case when d.show_price then (select min(v.retail_price) from public.variants v where v.design_id = d.id and v.is_active) end,
        'colors', (select coalesce(jsonb_agg(distinct v.color), '[]') from public.variants v where v.design_id = d.id and v.is_active),
        'sizes', (select coalesce(jsonb_agg(jsonb_build_object('color', x.color, 'size', x.size, 'available', x.avail) order by x.color, x.size), '[]')
                  from (select v.color, v.size, coalesce(sum(sb.on_hand - sb.reserved) filter (where l.kind in ('warehouse','shop')), 0) > 0 avail
                        from public.variants v left join public.stock_balances sb on sb.variant_id = v.id left join public.locations l on l.id = sb.location_id
                        where v.design_id = d.id and v.is_active group by v.color, v.size) x)
      ) order by d.code) from public.designs d where d.business_id = b.id and d.published and d.is_active), '[]')) end
  from (select * from public.businesses where catalogue_enabled and catalogue_slug = lower(p_slug) limit 1) b
  right join (select 1) one on true
$$;

-- ---------------------------------------------------------------------------
-- RLS & grants
-- ---------------------------------------------------------------------------
alter table public.targets enable row level security;
alter table public.content_posts enable row level security;
alter table public.team_tasks enable row level security;
alter table public.inquiries enable row level security;
alter table public.inquiry_events enable row level security;
alter table public.commission_plans enable row level security;
alter table public.commission_runs enable row level security;
alter table public.commission_lines enable row level security;

create policy targets_read on public.targets for select to authenticated
  using (public.is_business_member(business_id) and (public.has_permission('targets.manage') or public.has_permission('reports.view')
         or membership_id = (public.current_membership()).id or scope = 'business'));
create policy content_read on public.content_posts for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('team.work'));
create policy tasks_read on public.team_tasks for select to authenticated
  using (public.is_business_member(business_id) and (assignee = (public.current_membership()).id or created_by = (public.current_membership()).id
         or public.has_permission('tasks.assign')));
create policy inquiries_read on public.inquiries for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('team.work')
         and (public.has_permission('tasks.assign') or assigned_to = (public.current_membership()).id or created_by = (public.current_membership()).id));
create policy inquiry_events_read on public.inquiry_events for select to authenticated
  using (exists (select 1 from public.inquiries q where q.id = inquiry_id and public.is_business_member(q.business_id) and public.has_permission('team.work')
         and (public.has_permission('tasks.assign') or q.assigned_to = (public.current_membership()).id or q.created_by = (public.current_membership()).id)));
create policy commission_plans_read on public.commission_plans for select to authenticated
  using (public.is_business_member(business_id) and (public.has_permission('commissions.calculate') or public.has_permission('commissions.approve')));
-- SECURITY DEFINER helper avoids a policy cycle between commission_runs and commission_lines.
create or replace function public._has_commission_line(p_run uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.commission_lines l where l.run_id = p_run and l.membership_id = (public.current_membership()).id)
$$;
grant execute on function public._has_commission_line(uuid) to authenticated;

create policy commission_runs_read on public.commission_runs for select to authenticated
  using (public.is_business_member(business_id) and (public.has_permission('commissions.calculate') or public.has_permission('commissions.approve')
         or (status in ('approved','paid') and public._has_commission_line(id))));
create policy commission_lines_read on public.commission_lines for select to authenticated
  using (exists (select 1 from public.commission_runs r where r.id = run_id and public.is_business_member(r.business_id)
         and (public.has_permission('commissions.calculate') or public.has_permission('commissions.approve')
              or (membership_id = (public.current_membership()).id and r.status in ('approved','paid')))));

revoke all on public.targets, public.content_posts, public.team_tasks, public.inquiries, public.inquiry_events,
  public.commission_plans, public.commission_runs, public.commission_lines from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
grant select on public.targets, public.content_posts, public.team_tasks, public.inquiries, public.inquiry_events,
  public.commission_plans, public.commission_runs, public.commission_lines to authenticated;

grant execute on function
  public.target_set(text, text, uuid, uuid, text, date, bigint, text), public.target_progress(text, text, date, text, uuid, uuid),
  public.content_log(text, text, text, uuid, date, text), public.content_verify(uuid, boolean, text),
  public.task_create(text, text, uuid, uuid, timestamptz, text), public.task_complete(uuid, text), public.task_review(uuid, text, text),
  public.inquiry_create(text, text, uuid, text, text, uuid, uuid, date), public.inquiry_event(uuid, text, text, date),
  public.inquiry_link_sale(uuid, uuid, text), public.inquiry_funnel(date, date),
  public.commission_plan_save(uuid, text, public.app_role, uuid, text, numeric, bigint, boolean, boolean),
  public.commission_calculate(date, date), public.commission_approve(uuid, text), public.commission_pay(uuid, uuid, text),
  public.commission_cancel(uuid, text), public.catalogue_configure(boolean, text, text), public.design_publish(uuid, boolean, boolean, text)
to authenticated;
grant execute on function public.public_catalogue(text) to anon, authenticated;

commit;
