-- DIROMA Business OS — Milestone C: POS, payments, money accounts, shifts, expenses, returns, approvals.
--
-- Accounting model (double entry, TZS integers):
--   1000 Money accounts (cash drawers, M-Pesa/mobile, bank)   — sub-ledger by money_account_id
--   1050 Funds in transit (deposits sent, not yet confirmed)
--   1100 Accounts receivable                                   — by customer_id
--   1150 Staff/runner advances                                 — by advance
--   1200 Inventory
--   2000 Customer credits & refunds owed                      — by customer_id (or return)
--   2100 Supplier payables
--   3000 Opening balance equity
--   4000 Sales revenue (net of discounts)   4100 Delivery income   4900 Sales returns (contra revenue)
--   5000 Cost of goods sold
--   6000 Operating expenses (by category)   6100 Courier / delivery expense   6200 Stock losses
--   6300 Cash over / short                  6400 Bank & mobile money fees
-- Journal entries are append-only and must balance (checked on insert and again at commit).
-- Revenue is recognised at sale; collections only clear receivables, so old-debt collection is never revenue.

-- New stock document types (outside the transaction: enum values must be committed before use).
alter type public.stock_doc_type add value if not exists 'sale';
alter type public.stock_doc_type add value if not exists 'return_receipt';
alter type public.stock_doc_type add value if not exists 'inspection_release';

begin;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
insert into public.permissions (code, description) values
  ('approvals.decide',  'Approve or reject requests from other staff (within own limits)'),
  ('customers.manage',  'Create and edit customers'),
  ('credit.manage',     'Set customer credit limits and terms'),
  ('payments.collect',  'Collect customer payments'),
  ('returns.request',   'Request a return for a sale'),
  ('returns.approve',   'Approve returns (independent of requester)'),
  ('refunds.pay',       'Pay out an approved refund'),
  ('inspection.release','Release or quarantine returned goods after inspection'),
  ('expenses.request',  'Request an expense'),
  ('expenses.approve',  'Approve expenses (independent of requester)'),
  ('expenses.pay',      'Pay an approved expense'),
  ('money.transfer',    'Send and confirm deposits/transfers between money accounts'),
  ('money.manage',      'Create money accounts and opening balances'),
  ('deliveries.manage', 'Runner advances and delivery settlement'),
  ('shift.review',      'Review closed shifts and cash variances'),
  ('journal.view',      'View the accounting journal');

insert into public.role_permissions (role, permission)
select 'owner', code from public.permissions where code in
  ('approvals.decide','customers.manage','credit.manage','payments.collect','returns.request','returns.approve','refunds.pay',
   'inspection.release','expenses.request','expenses.approve','expenses.pay','money.transfer','money.manage',
   'deliveries.manage','shift.review','journal.view');
insert into public.role_permissions (role, permission) values
  ('manager','approvals.decide'), ('manager','customers.manage'), ('manager','credit.manage'), ('manager','payments.collect'),
  ('manager','returns.request'), ('manager','returns.approve'), ('manager','refunds.pay'), ('manager','inspection.release'),
  ('manager','expenses.request'), ('manager','expenses.approve'), ('manager','expenses.pay'), ('manager','money.transfer'),
  ('manager','deliveries.manage'), ('manager','shift.review'),
  ('sales_staff','customers.manage'), ('sales_staff','payments.collect'), ('sales_staff','returns.request'),
  ('sales_staff','refunds.pay'), ('sales_staff','expenses.request'), ('sales_staff','expenses.pay'), ('sales_staff','deliveries.manage'),
  ('storekeeper','inspection.release'), ('storekeeper','expenses.request');

-- Discount a role may give without approval, and the most it may approve for others.
create table public.discount_limits (
  role     public.app_role primary key,
  max_pct  numeric(5,2) not null check (max_pct between 0 and 100)
);
insert into public.discount_limits values ('owner', 100), ('manager', 15), ('sales_staff', 5), ('storekeeper', 0);

-- ---------------------------------------------------------------------------
-- Chart of accounts & journal
-- ---------------------------------------------------------------------------
create table public.ledger_accounts (
  code  text primary key,
  name  text not null,
  type  text not null check (type in ('asset','liability','equity','revenue','expense'))
);
insert into public.ledger_accounts values
  ('1000','Money accounts (cash, mobile, bank)','asset'), ('1050','Funds in transit','asset'),
  ('1100','Accounts receivable','asset'), ('1150','Staff / runner advances','asset'), ('1200','Inventory','asset'),
  ('2000','Customer credits & refunds owed','liability'), ('2100','Supplier payables','liability'),
  ('3000','Opening balance equity','equity'),
  ('4000','Sales revenue','revenue'), ('4100','Delivery income','revenue'), ('4900','Sales returns','revenue'),
  ('5000','Cost of goods sold','expense'), ('6000','Operating expenses','expense'), ('6100','Courier / delivery expense','expense'),
  ('6200','Stock losses','expense'), ('6300','Cash over / short','expense'), ('6400','Bank & mobile money fees','expense');

create type public.money_kind as enum ('cash', 'mobile', 'bank');

create table public.money_accounts (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id),
  code         text not null,
  name         text not null,
  kind         public.money_kind not null,
  location_id  uuid references public.locations(id),
  is_active    boolean not null default true,
  opening_posted boolean not null default false,
  created_at   timestamptz not null default now(),
  unique (business_id, code),
  check (kind <> 'cash' or location_id is not null)
);

create table public.journal_entries (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id),
  ref_no       text not null,
  entry_date   date not null,
  source_type  text not null,
  source_id    uuid,
  memo         text,
  posted_by    uuid references public.memberships(id),
  created_at   timestamptz not null default now(),
  unique (business_id, ref_no)
);
create index journal_entries_source on public.journal_entries (source_type, source_id);
create index journal_entries_date on public.journal_entries (business_id, entry_date);

create table public.journal_lines (
  id               bigint generated always as identity primary key,
  entry_id         uuid not null references public.journal_entries(id),
  account_code     text not null references public.ledger_accounts(code),
  debit            bigint not null default 0 check (debit >= 0),
  credit           bigint not null default 0 check (credit >= 0),
  money_account_id uuid references public.money_accounts(id),
  customer_id      uuid,
  shift_id         uuid,
  category         text,
  check ((debit = 0) <> (credit = 0)),
  check (account_code <> '1000' or money_account_id is not null)
);
create index journal_lines_entry on public.journal_lines (entry_id);
create index journal_lines_money on public.journal_lines (money_account_id) where money_account_id is not null;
create index journal_lines_customer on public.journal_lines (account_code, customer_id) where customer_id is not null;
create index journal_lines_shift on public.journal_lines (shift_id) where shift_id is not null;

create or replace function public.tg_journal_immutable() returns trigger
language plpgsql set search_path = '' as $$
begin raise exception 'journal is append-only; post a reversing entry instead' using errcode = '42501'; end $$;
create trigger journal_entries_immutable before update or delete on public.journal_entries
  for each row execute function public.tg_journal_immutable();
create trigger journal_lines_immutable before update or delete on public.journal_lines
  for each row execute function public.tg_journal_immutable();
create trigger journal_entries_no_truncate before truncate on public.journal_entries
  for each statement execute function public.tg_journal_immutable();
create trigger journal_lines_no_truncate before truncate on public.journal_lines
  for each statement execute function public.tg_journal_immutable();

-- Belt and braces: at commit every touched entry must balance and have at least two lines.
-- SECURITY DEFINER: must see all lines regardless of the posting user's RLS visibility.
create or replace function public.tg_journal_balanced() returns trigger
language plpgsql security definer set search_path = '' as $$
declare d bigint; c bigint; n int;
begin
  select coalesce(sum(debit),0), coalesce(sum(credit),0), count(*) into d, c, n from public.journal_lines where entry_id = new.entry_id;
  if d <> c or n < 2 then raise exception 'unbalanced journal entry % (debit %, credit %)', new.entry_id, d, c using errcode = '23514'; end if;
  return null;
end $$;
create constraint trigger journal_lines_balanced after insert on public.journal_lines
  deferrable initially deferred for each row execute function public.tg_journal_balanced();

create or replace function public._business_date(p_business uuid, p_at timestamptz) returns date
language sql stable security definer set search_path = '' as $$
  select (p_at at time zone (select timezone from public.businesses where id = p_business))::date
$$;

-- Post a balanced entry. Lines: [{account, debit, credit, money_account_id, customer_id, shift_id, category}]; zero lines skipped.
create or replace function public._post_journal(p_business uuid, p_date date, p_source text, p_source_id uuid, p_memo text,
                                                p_actor uuid, p_lines jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_entry uuid; d bigint; c bigint;
begin
  select coalesce(sum(coalesce((x->>'debit')::bigint,0)),0), coalesce(sum(coalesce((x->>'credit')::bigint,0)),0) into d, c
  from jsonb_array_elements(p_lines) x;
  if d <> c then raise exception 'unbalanced entry for % (debit %, credit %)', p_source, d, c using errcode = '23514'; end if;
  if d = 0 then return null; end if;
  insert into public.journal_entries (business_id, ref_no, entry_date, source_type, source_id, memo, posted_by)
  values (p_business, public._next_ref(p_business, 'JE'), p_date, p_source, p_source_id, p_memo, p_actor) returning id into v_entry;
  insert into public.journal_lines (entry_id, account_code, debit, credit, money_account_id, customer_id, shift_id, category)
  select v_entry, x.account, coalesce(x.debit,0), coalesce(x.credit,0), x.money_account_id, x.customer_id, x.shift_id, x.category
  from jsonb_to_recordset(p_lines) as x(account text, debit bigint, credit bigint, money_account_id uuid, customer_id uuid, shift_id uuid, category text)
  where coalesce(x.debit,0) <> 0 or coalesce(x.credit,0) <> 0;
  return v_entry;
end $$;

create or replace function public._jl(p_account text, p_debit bigint, p_credit bigint, p_money uuid default null,
                                      p_customer uuid default null, p_shift uuid default null, p_category text default null) returns jsonb
language sql immutable set search_path = '' as $$
  select jsonb_build_object('account', p_account, 'debit', greatest(coalesce(p_debit,0),0), 'credit', greatest(coalesce(p_credit,0),0),
                            'money_account_id', p_money, 'customer_id', p_customer, 'shift_id', p_shift, 'category', p_category)
$$;

-- ---------------------------------------------------------------------------
-- Customers
-- ---------------------------------------------------------------------------
create type public.customer_kind as enum ('retail', 'wholesale');

create table public.customers (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references public.businesses(id),
  name          text not null check (length(btrim(name)) between 2 and 120),
  phone_e164    text check (phone_e164 is null or phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  kind          public.customer_kind not null default 'retail',
  credit_limit  bigint not null default 0 check (credit_limit >= 0),
  terms_days    int not null default 0 check (terms_days between 0 and 365),
  region        text,
  notes         text,
  source        text,   -- walk-in / Instagram / WhatsApp / referral …
  created_by    uuid references public.memberships(id),
  created_at    timestamptz not null default now(),
  unique (business_id, phone_e164)
);

create or replace function public._customer_receivable(p_customer uuid) returns bigint
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(debit - credit), 0)::bigint from public.journal_lines where account_code = '1100' and customer_id = p_customer
$$;
create or replace function public._customer_credit(p_customer uuid) returns bigint
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(credit - debit), 0)::bigint from public.journal_lines where account_code = '2000' and customer_id = p_customer
$$;

create or replace function public.customer_save(p_id uuid, p_name text, p_phone text, p_kind public.customer_kind,
                                                p_credit_limit bigint, p_terms_days int, p_region text, p_notes text, p_source text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; c public.customers; v uuid;
begin
  v_me := public.require_permission('customers.manage');
  if p_phone is not null and p_phone !~ '^\+[1-9][0-9]{7,14}$' then raise exception 'phone must be E.164' using errcode = '22023'; end if;
  if p_id is null then
    if coalesce(p_credit_limit,0) > 0 or coalesce(p_terms_days,0) > 0 then perform public.require_permission('credit.manage'); end if;
    insert into public.customers (business_id, name, phone_e164, kind, credit_limit, terms_days, region, notes, source, created_by)
    values (v_me.business_id, btrim(p_name), p_phone, coalesce(p_kind,'retail'), coalesce(p_credit_limit,0), coalesce(p_terms_days,0),
            nullif(btrim(p_region),''), nullif(btrim(p_notes),''), nullif(btrim(p_source),''), v_me.id)
    returning id into v;
    perform public.write_audit(v_me.business_id, 'customer.create', 'customer', v::text, null,
      jsonb_build_object('name', p_name, 'kind', p_kind, 'credit_limit', p_credit_limit), null);
  else
    select * into c from public.customers where id = p_id and business_id = v_me.business_id for update;
    if c.id is null then raise exception 'not found' using errcode = '22023'; end if;
    if coalesce(p_credit_limit, c.credit_limit) <> c.credit_limit or coalesce(p_terms_days, c.terms_days) <> c.terms_days
       or coalesce(p_kind, c.kind) <> c.kind then
      perform public.require_permission('credit.manage');
    end if;
    update public.customers set name = btrim(p_name), phone_e164 = p_phone, kind = coalesce(p_kind, c.kind),
           credit_limit = coalesce(p_credit_limit, c.credit_limit), terms_days = coalesce(p_terms_days, c.terms_days),
           region = nullif(btrim(p_region),''), notes = nullif(btrim(p_notes),''), source = nullif(btrim(p_source),'')
     where id = c.id returning id into v;
    perform public.write_audit(v_me.business_id, 'customer.update', 'customer', v::text,
      jsonb_build_object('kind', c.kind, 'credit_limit', c.credit_limit, 'terms_days', c.terms_days),
      jsonb_build_object('kind', p_kind, 'credit_limit', p_credit_limit, 'terms_days', p_terms_days), null);
  end if;
  return v;
end $$;

-- ---------------------------------------------------------------------------
-- Money accounts
-- ---------------------------------------------------------------------------
create or replace function public.money_account_create(p_code text, p_name text, p_kind public.money_kind, p_location uuid)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v uuid;
begin
  v_me := public.require_permission('money.manage');
  if p_location is not null and not exists (select 1 from public.locations where id = p_location and business_id = v_me.business_id) then
    raise exception 'unknown location' using errcode = '22023';
  end if;
  insert into public.money_accounts (business_id, code, name, kind, location_id)
  values (v_me.business_id, upper(btrim(p_code)), btrim(p_name), p_kind, p_location) returning id into v;
  perform public.write_audit(v_me.business_id, 'money_account.create', 'money_account', v::text, null,
    jsonb_build_object('code', p_code, 'kind', p_kind), null);
  return v;
end $$;

create or replace function public.money_account_opening(p_account uuid, p_amount bigint, p_as_of date, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; a public.money_accounts;
begin
  v_me := public.require_permission('money.manage');
  if coalesce(btrim(p_reason),'') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  if p_amount is null or p_amount < 0 then raise exception 'amount must be zero or positive' using errcode = '22023'; end if;
  select * into a from public.money_accounts where id = p_account and business_id = v_me.business_id for update;
  if a.id is null then raise exception 'not found' using errcode = '22023'; end if;
  if a.opening_posted then raise exception 'opening balance already posted (use an adjustment)' using errcode = '22023'; end if;
  perform public._post_journal(v_me.business_id, p_as_of, 'opening_balance', a.id, p_reason, v_me.id,
    jsonb_build_array(public._jl('1000', p_amount, 0, a.id), public._jl('3000', 0, p_amount)));
  update public.money_accounts set opening_posted = true where id = a.id;
  perform public.write_audit(v_me.business_id, 'money_account.opening', 'money_account', a.id::text, null,
    jsonb_build_object('amount', p_amount, 'as_of', p_as_of), p_reason);
end $$;

-- ---------------------------------------------------------------------------
-- Shifts
-- ---------------------------------------------------------------------------
create type public.shift_status as enum ('open', 'pending_review', 'closed');

create table public.shifts (
  id               uuid primary key default gen_random_uuid(),
  business_id      uuid not null references public.businesses(id),
  ref_no           text not null,
  location_id      uuid not null references public.locations(id),
  cash_account_id  uuid not null references public.money_accounts(id),
  opened_by        uuid not null references public.memberships(id),
  opened_at        timestamptz not null default now(),
  opening_float    bigint not null check (opening_float >= 0),
  status           public.shift_status not null default 'open',
  closed_at        timestamptz,
  expected_cash    bigint,
  counted_cash     bigint check (counted_cash is null or counted_cash >= 0),
  variance         bigint,
  variance_reason  text,
  reviewed_by      uuid references public.memberships(id),
  reviewed_at      timestamptz,
  review_note      text,
  unique (business_id, ref_no)
);
create unique index shifts_one_open_per_person on public.shifts (opened_by) where status = 'open';

create or replace function public._shift_cash_movement(p_shift uuid) returns bigint
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(jl.debit - jl.credit), 0)::bigint
  from public.journal_lines jl join public.shifts s on s.id = p_shift
  where jl.shift_id = p_shift and jl.account_code = '1000' and jl.money_account_id = s.cash_account_id
$$;

create or replace function public.shift_open(p_location uuid, p_cash_account uuid, p_opening_float bigint)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; a public.money_accounts; v uuid;
begin
  v_me := public.require_permission('pos.sell');
  perform public._require_location(p_location, array['shop']::public.location_kind[]);
  select * into a from public.money_accounts where id = p_cash_account and business_id = v_me.business_id and is_active;
  if a.id is null or a.kind <> 'cash' or a.location_id <> p_location then
    raise exception 'choose the cash drawer of this shop' using errcode = '22023';
  end if;
  if exists (select 1 from public.shifts where opened_by = v_me.id and status = 'open') then
    raise exception 'you already have an open shift' using errcode = '22023';
  end if;
  insert into public.shifts (business_id, ref_no, location_id, cash_account_id, opened_by, opening_float)
  values (v_me.business_id, public._next_ref(v_me.business_id, 'SHF'), p_location, a.id, v_me.id, coalesce(p_opening_float, 0))
  returning id into v;
  perform public.write_audit(v_me.business_id, 'shift.open', 'shift', v::text, null, jsonb_build_object('float', p_opening_float), null);
  return v;
end $$;

-- Locks the caller's open shift (FOR SHARE) so a concurrent close waits for this posting to finish.
create or replace function public._lock_my_shift(p_shift uuid, p_me uuid) returns public.shifts
language plpgsql security definer set search_path = '' as $$
declare s public.shifts;
begin
  select * into s from public.shifts where id = p_shift for share;
  if s.id is null or s.opened_by <> p_me or s.status <> 'open' then
    raise exception 'open your shift first (or it has been closed)' using errcode = '22023';
  end if;
  return s;
end $$;

-- Cashier counts the drawer. Expected = opening float + all cash posted to this drawer during the shift.
create or replace function public.shift_close(p_shift uuid, p_counted bigint, p_reason text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; s public.shifts; v_expected bigint; v_var bigint;
begin
  v_me := public.require_permission('pos.sell');
  select * into s from public.shifts where id = p_shift for update;  -- waits for in-flight postings holding FOR SHARE
  if s.id is null or s.opened_by <> v_me.id then raise exception 'not your shift' using errcode = '42501'; end if;
  if s.status <> 'open' then raise exception 'shift already closed' using errcode = '22023'; end if;
  if p_counted is null or p_counted < 0 then raise exception 'enter the counted cash' using errcode = '22023'; end if;
  v_expected := s.opening_float + public._shift_cash_movement(s.id);
  v_var := p_counted - v_expected;
  if v_var <> 0 and coalesce(btrim(p_reason),'') = '' then raise exception 'explain the difference' using errcode = '22023'; end if;
  update public.shifts set status = case when v_var = 0 then 'closed'::public.shift_status else 'pending_review'::public.shift_status end,
         closed_at = now(), expected_cash = v_expected, counted_cash = p_counted, variance = v_var, variance_reason = nullif(btrim(p_reason),'')
   where id = s.id;
  perform public.write_audit(v_me.business_id, 'shift.close', 'shift', s.id::text, null,
    jsonb_build_object('expected', v_expected, 'counted', p_counted, 'variance', v_var), p_reason);
  return jsonb_build_object('expected', v_expected, 'counted', p_counted, 'variance', v_var);
end $$;

-- Independent review of a variance. Posts the over/short so the book drawer matches the count.
create or replace function public.shift_review(p_shift uuid, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; s public.shifts;
begin
  v_me := public.require_permission('shift.review');
  if coalesce(btrim(p_note),'') = '' then raise exception 'review note required' using errcode = '22023'; end if;
  select * into s from public.shifts where id = p_shift and business_id = v_me.business_id for update;
  if s.id is null or s.status <> 'pending_review' then raise exception 'shift not awaiting review' using errcode = '22023'; end if;
  if s.opened_by = v_me.id then raise exception 'cannot review your own shift' using errcode = '42501'; end if;
  perform public._post_journal(s.business_id, public._business_date(s.business_id, s.closed_at), 'shift_variance', s.id,
    'Cash over/short ' || s.ref_no, v_me.id,
    case when s.variance > 0
      then jsonb_build_array(public._jl('1000', s.variance, 0, s.cash_account_id), public._jl('6300', 0, s.variance))
      else jsonb_build_array(public._jl('6300', -s.variance, 0), public._jl('1000', 0, -s.variance, s.cash_account_id)) end);
  update public.shifts set status = 'closed', reviewed_by = v_me.id, reviewed_at = now(), review_note = p_note where id = s.id;
  perform public.write_audit(v_me.business_id, 'shift.review', 'shift', s.id::text, null, jsonb_build_object('variance', s.variance), p_note);
end $$;

-- ---------------------------------------------------------------------------
-- Approvals (bound to the exact request payload)
-- ---------------------------------------------------------------------------
create type public.approval_status as enum ('pending', 'approved', 'rejected');

create table public.approval_requests (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null references public.businesses(id),
  operation       text not null,
  reasons         text[] not null,
  payload_hash    text not null,
  summary         jsonb not null,
  requested_by    uuid not null references public.memberships(id),
  status          public.approval_status not null default 'pending',
  decided_by      uuid references public.memberships(id),
  decided_at      timestamptz,
  decision_note   text,
  consumed_at     timestamptz,
  created_at      timestamptz not null default now()
);

create or replace function public._payload_hash(p jsonb) returns text
language sql immutable set search_path = '' as $$ select encode(extensions.digest(p::text, 'sha256'), 'hex') $$;

create or replace function public._approval_request(p_business uuid, p_op text, p_reasons text[], p_payload jsonb, p_summary jsonb, p_me uuid)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  -- reuse an identical pending request instead of piling up duplicates
  select id into v from public.approval_requests
   where requested_by = p_me and operation = p_op and payload_hash = public._payload_hash(p_payload) and status = 'pending';
  if v is null then
    insert into public.approval_requests (business_id, operation, reasons, payload_hash, summary, requested_by)
    values (p_business, p_op, p_reasons, public._payload_hash(p_payload), p_summary, p_me) returning id into v;
  end if;
  return v;
end $$;

create or replace function public._approval_consume(p_approval uuid, p_op text, p_reasons text[], p_payload jsonb, p_me uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare a public.approval_requests;
begin
  select * into a from public.approval_requests where id = p_approval for update;
  if a.id is null or a.operation <> p_op or a.requested_by <> p_me then raise exception 'approval does not belong to this request' using errcode = '42501'; end if;
  if a.status <> 'approved' then raise exception 'approval is %', a.status using errcode = '42501'; end if;
  if a.consumed_at is not null then raise exception 'approval already used' using errcode = '42501'; end if;
  if a.payload_hash <> public._payload_hash(p_payload) then raise exception 'request changed after approval; ask again' using errcode = '42501'; end if;
  if not (a.reasons @> p_reasons) then raise exception 'approval does not cover: %', p_reasons using errcode = '42501'; end if;
  update public.approval_requests set consumed_at = now() where id = a.id;
end $$;

create or replace function public.approval_decide(p_approval uuid, p_approve boolean, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; a public.approval_requests; v_limit numeric;
begin
  v_me := public.require_permission('approvals.decide');
  select * into a from public.approval_requests where id = p_approval and business_id = v_me.business_id for update;
  if a.id is null or a.status <> 'pending' then raise exception 'request is not pending' using errcode = '22023'; end if;
  if a.requested_by = v_me.id then raise exception 'cannot approve your own request' using errcode = '42501'; end if;
  if not p_approve and coalesce(btrim(p_note),'') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  if p_approve and 'discount' = any (a.reasons) then
    select max_pct into v_limit from public.discount_limits where role = v_me.role;
    if coalesce((a.summary->>'discount_pct')::numeric, 0) > coalesce(v_limit, 0) then
      raise exception 'discount %%% is above your approval limit (%%%)', a.summary->>'discount_pct', v_limit using errcode = '42501';
    end if;
  end if;
  update public.approval_requests set status = case when p_approve then 'approved'::public.approval_status else 'rejected'::public.approval_status end,
         decided_by = v_me.id, decided_at = now(), decision_note = p_note where id = a.id;
  perform public.write_audit(v_me.business_id, case when p_approve then 'approval.approve' else 'approval.reject' end,
    'approval', a.id::text, null, jsonb_build_object('operation', a.operation, 'reasons', a.reasons, 'summary', a.summary), p_note);
end $$;

-- ---------------------------------------------------------------------------
-- Sales
-- ---------------------------------------------------------------------------
create type public.payment_status as enum ('unpaid', 'partial', 'paid');
create type public.fulfillment_status as enum ('collected', 'awaiting_delivery', 'delivered', 'failed_delivery');

create table public.sales (
  id                  uuid primary key default gen_random_uuid(),
  business_id         uuid not null references public.businesses(id),
  ref_no              text not null,
  location_id         uuid not null references public.locations(id),
  shift_id            uuid not null references public.shifts(id),
  customer_id         uuid references public.customers(id),
  channel             text not null check (channel in ('retail','wholesale')),
  source              text,
  gross_amount        bigint not null check (gross_amount >= 0),
  discount_amount     bigint not null check (discount_amount >= 0),
  delivery_fee        bigint not null default 0 check (delivery_fee >= 0),
  total               bigint not null check (total >= 0),
  payment_status      public.payment_status not null,
  fulfillment_status  public.fulfillment_status not null,
  sold_at             timestamptz not null,
  entered_at          timestamptz not null default now(),
  sold_by             uuid not null references public.memberships(id),
  approval_id         uuid references public.approval_requests(id),
  note                text,
  unique (business_id, ref_no)
);
create index sales_customer on public.sales (customer_id) where customer_id is not null;
create index sales_loc_date on public.sales (location_id, sold_at desc);

create table public.sale_lines (
  id            uuid primary key default gen_random_uuid(),
  sale_id       uuid not null references public.sales(id),
  variant_id    uuid not null references public.variants(id),
  qty           int not null check (qty > 0),
  list_price    bigint not null check (list_price > 0),  -- snapshot of the channel price
  discount      bigint not null default 0 check (discount >= 0),
  line_total    bigint not null check (line_total >= 0),
  check (line_total = list_price * qty - discount)
);
create index sale_lines_sale on public.sale_lines (sale_id);

-- Confidential cost snapshot at sale time.
create table public.sale_line_costs (
  sale_line_id  uuid primary key references public.sale_lines(id),
  unit_cost     bigint,           -- NULL = cost unknown (profit flagged incomplete, never assumed zero)
  cost_known    boolean not null
);

create type public.settlement_kind as enum ('payment', 'customer_credit', 'return');

create table public.payments (
  id                uuid primary key default gen_random_uuid(),
  business_id       uuid not null references public.businesses(id),
  ref_no            text not null,
  customer_id       uuid references public.customers(id),
  money_account_id  uuid not null references public.money_accounts(id),
  method            public.money_kind not null,
  amount            bigint not null check (amount > 0),
  provider_ref      text,
  verification      text not null default 'manual' check (verification in ('manual','verified')),
  shift_id          uuid references public.shifts(id),
  location_id       uuid references public.locations(id),
  received_by       uuid not null references public.memberships(id),
  received_at       timestamptz not null default now(),
  unique (business_id, ref_no)
);

create table public.sale_settlements (
  id          bigint generated always as identity primary key,
  sale_id     uuid not null references public.sales(id),
  kind        public.settlement_kind not null,
  payment_id  uuid references public.payments(id),
  return_id   uuid,
  amount      bigint not null check (amount > 0),
  created_at  timestamptz not null default now()
);
create index sale_settlements_sale on public.sale_settlements (sale_id);

create or replace function public._sale_balance(p_sale uuid) returns bigint
language sql stable security definer set search_path = '' as $$
  select s.total - coalesce((select sum(amount) from public.sale_settlements where sale_id = s.id), 0)
  from public.sales s where s.id = p_sale
$$;

create or replace function public._refresh_payment_status(p_sale uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_bal bigint; v_total bigint;
begin
  select total into v_total from public.sales where id = p_sale;
  v_bal := public._sale_balance(p_sale);
  update public.sales set payment_status = case when v_bal <= 0 then 'paid'::public.payment_status
      when v_bal < v_total then 'partial'::public.payment_status else 'unpaid'::public.payment_status end
   where id = p_sale;
end $$;

-- Records one payment received against a customer/sale: Dr money account, Cr receivable.
create or replace function public._receive_payment(p_business uuid, p_me uuid, p_customer uuid, p_account public.money_accounts,
                                                   p_amount bigint, p_provider_ref text, p_shift uuid, p_location uuid,
                                                   p_date date, p_source text, p_source_id uuid)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  insert into public.payments (business_id, ref_no, customer_id, money_account_id, method, amount, provider_ref, shift_id, location_id, received_by)
  values (p_business, public._next_ref(p_business, 'PAY'), p_customer, p_account.id, p_account.kind, p_amount, nullif(btrim(p_provider_ref),''),
          p_shift, p_location, p_me)
  returning id into v;
  return v;
end $$;

-- Validates a money account for receiving/paying money; cash must be the caller's own shift drawer.
create or replace function public._usable_account(p_business uuid, p_account uuid, p_shift public.shifts) returns public.money_accounts
language plpgsql stable security definer set search_path = '' as $$
declare a public.money_accounts;
begin
  select * into a from public.money_accounts where id = p_account and business_id = p_business and is_active;
  if a.id is null then raise exception 'unknown money account' using errcode = '22023'; end if;
  if a.kind = 'cash' and (p_shift.id is null or p_shift.cash_account_id <> a.id) then
    raise exception 'cash must go through your own open shift drawer' using errcode = '22023';
  end if;
  return a;
end $$;

/*
  POS sale. p_lines: [{variant_id, qty, discount}] (discount = TZS off the line)
            p_payments: [{account_id, amount, provider_ref}] or [{method:'customer_credit', amount}]
  Returns {status:'posted', sale_id, ref_no} or {status:'approval_required', approval_id, reasons}.
*/
create or replace function public.sale_post(p_idem uuid, p_location uuid, p_shift uuid, p_customer uuid, p_channel text,
                                            p_lines jsonb, p_delivery_fee bigint, p_fulfillment text, p_payments jsonb,
                                            p_sold_at timestamptz, p_source text, p_note text, p_approval uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_me public.memberships; v_payload jsonb; v_prev jsonb; s public.shifts; c public.customers; v_sale uuid; v_ref text;
  v_gross bigint := 0; v_disc bigint := 0; v_goods bigint := 0; v_total bigint; v_paid bigint := 0; v_due bigint;
  v_reasons text[] := '{}'; v_limit numeric; v_pct numeric := 0; v_sold_at timestamptz := coalesce(p_sold_at, now());
  r record; v_price bigint; v_cost bigint; v_doc uuid; v_line uuid; v_cogs bigint := 0; v_date date; a public.money_accounts;
  v_pay uuid; v_lines jsonb := '[]'; v_credit_used bigint := 0; v_appr uuid; v_unknown int := 0;
begin
  v_me := public.require_permission('pos.sell');
  v_payload := jsonb_build_object('location', p_location, 'shift', p_shift, 'customer', p_customer, 'channel', p_channel,
    'lines', p_lines, 'delivery_fee', coalesce(p_delivery_fee,0), 'fulfillment', p_fulfillment, 'payments', coalesce(p_payments,'[]'),
    'sold_at', p_sold_at, 'source', p_source, 'note', p_note);
  v_prev := public._idem_get(p_idem, 'sale_post', v_payload);
  if v_prev is not null then return v_prev; end if;

  perform public._require_location(p_location, array['shop']::public.location_kind[]);
  s := public._lock_my_shift(p_shift, v_me.id);
  if s.location_id <> p_location then raise exception 'shift belongs to another shop' using errcode = '22023'; end if;
  if p_channel not in ('retail','wholesale') then raise exception 'channel must be retail or wholesale' using errcode = '22023'; end if;
  if p_fulfillment not in ('collected','awaiting_delivery') then raise exception 'invalid fulfillment' using errcode = '22023'; end if;
  if coalesce(p_delivery_fee,0) < 0 then raise exception 'invalid delivery fee' using errcode = '22023'; end if;
  if v_sold_at > now() + interval '5 minutes' then raise exception 'sale time cannot be in the future' using errcode = '22023'; end if;
  if p_customer is not null then
    select * into c from public.customers where id = p_customer and business_id = v_me.business_id for update;
    if c.id is null then raise exception 'unknown customer' using errcode = '22023'; end if;
  end if;
  if p_channel = 'wholesale' and coalesce(c.kind::text, '') <> 'wholesale' then
    raise exception 'wholesale prices need a wholesale customer' using errcode = '22023';
  end if;

  -- price every line from the catalogue (client prices are never trusted)
  for r in select x.variant_id, x.qty, coalesce(x.discount, 0) as discount
           from jsonb_to_recordset(p_lines) as x(variant_id uuid, qty int, discount bigint) loop
    if r.qty is null or r.qty <= 0 then raise exception 'quantity must be positive' using errcode = '22023'; end if;
    select case when p_channel = 'wholesale' then v.wholesale_price else v.retail_price end into v_price
      from public.variants v where v.id = r.variant_id and v.business_id = v_me.business_id and v.is_active;
    if not found then raise exception 'unknown variant' using errcode = '22023'; end if;
    if v_price is null then raise exception 'this size/colour has no % price yet', p_channel using errcode = '22023'; end if;
    if r.discount < 0 or r.discount > v_price * r.qty then raise exception 'invalid discount' using errcode = '22023'; end if;
    v_gross := v_gross + v_price * r.qty; v_disc := v_disc + r.discount;
    v_lines := v_lines || jsonb_build_object('variant_id', r.variant_id, 'qty', r.qty, 'price', v_price, 'discount', r.discount);
  end loop;
  if jsonb_array_length(v_lines) = 0 then raise exception 'empty sale' using errcode = '22023'; end if;
  v_goods := v_gross - v_disc;
  v_total := v_goods + coalesce(p_delivery_fee, 0);

  -- payments: amounts only here; posting happens after the sale exists
  for r in select * from jsonb_to_recordset(coalesce(p_payments,'[]')) as x(account_id uuid, amount bigint, method text, provider_ref text) loop
    if r.amount is null or r.amount <= 0 then raise exception 'payment amounts must be positive' using errcode = '22023'; end if;
    v_paid := v_paid + r.amount;
    if r.method = 'customer_credit' then
      if c.id is null then raise exception 'customer credit needs a customer' using errcode = '22023'; end if;
      v_credit_used := v_credit_used + r.amount;
    end if;
  end loop;
  if v_paid > v_total then raise exception 'payments exceed the sale total (give change outside the system)' using errcode = '22023'; end if;
  if v_credit_used > 0 and v_credit_used > public._customer_credit(c.id) then raise exception 'not enough customer credit' using errcode = '22023'; end if;
  v_due := v_total - v_paid;

  -- controls that need someone else's approval
  if v_gross > 0 then v_pct := round(v_disc::numeric * 100 / v_gross, 2); end if;
  select max_pct into v_limit from public.discount_limits where role = v_me.role;
  if v_pct > coalesce(v_limit, 0) then v_reasons := array_append(v_reasons, 'discount'); end if;
  if v_sold_at < now() - interval '30 minutes' then v_reasons := array_append(v_reasons, 'backdate'); end if;
  if v_due > 0 then
    if c.id is null then raise exception 'walk-in sales must be paid in full; choose or create the customer for credit' using errcode = '22023'; end if;
    if public._customer_receivable(c.id) + v_due > c.credit_limit then v_reasons := array_append(v_reasons, 'credit_limit'); end if;
  end if;
  if cardinality(v_reasons) > 0 then
    if p_approval is null then
      v_appr := public._approval_request(v_me.business_id, 'sale_post', v_reasons, v_payload,
        jsonb_build_object('total', v_total, 'discount', v_disc, 'discount_pct', v_pct, 'due', v_due, 'customer', c.name,
                           'sold_at', v_sold_at, 'lines', jsonb_array_length(v_lines)), v_me.id);
      return jsonb_build_object('status', 'approval_required', 'approval_id', v_appr, 'reasons', v_reasons);
    end if;
    perform public._approval_consume(p_approval, 'sale_post', v_reasons, v_payload, v_me.id);
  end if;

  -- post the sale
  v_ref := public._next_ref(v_me.business_id, 'RCP');
  v_date := public._business_date(v_me.business_id, v_sold_at);
  insert into public.sales (business_id, ref_no, location_id, shift_id, customer_id, channel, source, gross_amount, discount_amount,
                            delivery_fee, total, payment_status, fulfillment_status, sold_at, sold_by, approval_id, note)
  values (v_me.business_id, v_ref, p_location, s.id, c.id, p_channel, nullif(btrim(p_source),''), v_gross, v_disc,
          coalesce(p_delivery_fee,0), v_total, 'unpaid', p_fulfillment::public.fulfillment_status, v_sold_at, v_me.id,
          case when cardinality(v_reasons) > 0 then p_approval end, nullif(btrim(p_note),''))
  returning id into v_sale;
  v_doc := public._new_doc(v_me.business_id, 'sale', 'DOC', v_me.id, v_sale, v_ref);
  for r in select * from jsonb_to_recordset(v_lines) as x(variant_id uuid, qty int, price bigint, discount bigint) loop
    insert into public.sale_lines (sale_id, variant_id, qty, list_price, discount, line_total)
    values (v_sale, r.variant_id, r.qty, r.price, r.discount, r.price * r.qty - r.discount) returning id into v_line;
    select avg_cost into v_cost from public.variant_costs where variant_id = r.variant_id;
    insert into public.sale_line_costs (sale_line_id, unit_cost, cost_known) values (v_line, v_cost, v_cost is not null);
    if v_cost is not null then v_cogs := v_cogs + v_cost * r.qty; else v_unknown := v_unknown + 1; end if;
    perform public._move(v_me.business_id, v_doc, r.variant_id, p_location, -r.qty);   -- fails atomically if not in stock
  end loop;

  perform public._post_journal(v_me.business_id, v_date, 'sale', v_sale, v_ref, v_me.id, jsonb_build_array(
    public._jl('1100', v_total, 0, null, c.id),
    public._jl('4000', 0, v_goods),
    public._jl('4100', 0, coalesce(p_delivery_fee,0)),
    public._jl('5000', v_cogs, 0),
    public._jl('1200', 0, v_cogs)));

  for r in select * from jsonb_to_recordset(coalesce(p_payments,'[]')) as x(account_id uuid, amount bigint, method text, provider_ref text) loop
    if r.method = 'customer_credit' then
      perform public._post_journal(v_me.business_id, v_date, 'credit_applied', v_sale, v_ref, v_me.id, jsonb_build_array(
        public._jl('2000', r.amount, 0, null, c.id), public._jl('1100', 0, r.amount, null, c.id)));
      insert into public.sale_settlements (sale_id, kind, amount) values (v_sale, 'customer_credit', r.amount);
    else
      a := public._usable_account(v_me.business_id, r.account_id, s);
      v_pay := public._receive_payment(v_me.business_id, v_me.id, c.id, a, r.amount, r.provider_ref, s.id, p_location, v_date, 'sale', v_sale);
      perform public._post_journal(v_me.business_id, v_date, 'payment', v_pay, v_ref, v_me.id, jsonb_build_array(
        public._jl('1000', r.amount, 0, a.id, null, case when a.kind = 'cash' then s.id end),
        public._jl('1100', 0, r.amount, null, c.id)));
      insert into public.sale_settlements (sale_id, kind, payment_id, amount) values (v_sale, 'payment', v_pay, r.amount);
    end if;
  end loop;
  perform public._refresh_payment_status(v_sale);

  if cardinality(v_reasons) > 0 then
    perform public.write_audit(v_me.business_id, 'sale.approved_exception', 'sale', v_sale::text, null,
      jsonb_build_object('reasons', v_reasons, 'approval', p_approval, 'discount_pct', v_pct, 'sold_at', v_sold_at), null);
  end if;
  return public._idem_put(p_idem, v_me.business_id, 'sale_post', v_payload,
    jsonb_build_object('status', 'posted', 'sale_id', v_sale, 'ref_no', v_ref, 'total', v_total, 'due', v_due, 'cost_unknown_lines', v_unknown));
end $$;

create or replace function public.sale_set_fulfillment(p_sale uuid, p_status public.fulfillment_status, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; s public.sales;
begin
  v_me := public.require_permission('pos.sell');
  select * into s from public.sales where id = p_sale and business_id = v_me.business_id for update;
  if s.id is null then raise exception 'not found' using errcode = '22023'; end if;
  perform public._require_location(s.location_id);
  if s.fulfillment_status not in ('awaiting_delivery','failed_delivery') or p_status not in ('delivered','failed_delivery','awaiting_delivery') then
    raise exception 'invalid fulfilment change' using errcode = '22023';
  end if;
  -- A failed delivery is only a status: goods come back through a return + inspection, never straight to saleable stock.
  update public.sales set fulfillment_status = p_status where id = s.id;
  perform public.write_audit(v_me.business_id, 'sale.fulfillment', 'sale', s.id::text,
    jsonb_build_object('status', s.fulfillment_status), jsonb_build_object('status', p_status), p_note);
end $$;

-- ---------------------------------------------------------------------------
-- Collections (old debt is never new revenue)
-- ---------------------------------------------------------------------------
create or replace function public.payment_collect(p_idem uuid, p_customer uuid, p_account uuid, p_amount bigint, p_provider_ref text,
                                                  p_shift uuid, p_allocations jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; c public.customers; s public.shifts; a public.money_accounts;
        v_pay uuid; v_left bigint; r record; v_take bigint; v_alloc bigint := 0; v_date date; v_lines jsonb;
begin
  v_me := public.require_permission('payments.collect');
  v_payload := jsonb_build_object('customer', p_customer, 'account', p_account, 'amount', p_amount, 'ref', p_provider_ref,
                                  'shift', p_shift, 'allocations', p_allocations);
  v_prev := public._idem_get(p_idem, 'payment_collect', v_payload);
  if v_prev is not null then return v_prev; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'amount must be positive' using errcode = '22023'; end if;
  select * into c from public.customers where id = p_customer and business_id = v_me.business_id for update;  -- serialises allocation
  if c.id is null then raise exception 'unknown customer' using errcode = '22023'; end if;
  if p_shift is not null then s := public._lock_my_shift(p_shift, v_me.id); end if;
  a := public._usable_account(v_me.business_id, p_account, s);
  v_date := public._business_date(v_me.business_id, now());
  v_pay := public._receive_payment(v_me.business_id, v_me.id, c.id, a, p_amount, p_provider_ref, s.id, s.location_id, v_date, 'collection', null);
  v_left := p_amount;

  if p_allocations is not null then
    -- explicit allocation chosen by the cashier
    for r in select x.sale_id, x.amount from jsonb_to_recordset(p_allocations) as x(sale_id uuid, amount bigint) loop
      if not exists (select 1 from public.sales where id = r.sale_id and customer_id = c.id) then
        raise exception 'sale does not belong to this customer' using errcode = '22023';
      end if;
      if r.amount is null or r.amount <= 0 or r.amount > public._sale_balance(r.sale_id) or r.amount > v_left then
        raise exception 'allocation exceeds balance due or payment' using errcode = '22023';
      end if;
      insert into public.sale_settlements (sale_id, kind, payment_id, amount) values (r.sale_id, 'payment', v_pay, r.amount);
      perform public._refresh_payment_status(r.sale_id);
      v_left := v_left - r.amount; v_alloc := v_alloc + r.amount;
    end loop;
  else
    -- default: oldest open sale first (FIFO)
    for r in select sa.id as sale_id from public.sales sa
             where sa.customer_id = c.id and sa.payment_status <> 'paid' order by sa.sold_at, sa.ref_no loop
      exit when v_left = 0;
      v_take := least(v_left, public._sale_balance(r.sale_id));
      if v_take > 0 then
        insert into public.sale_settlements (sale_id, kind, payment_id, amount) values (r.sale_id, 'payment', v_pay, v_take);
        perform public._refresh_payment_status(r.sale_id);
        v_left := v_left - v_take; v_alloc := v_alloc + v_take;
      end if;
    end loop;
  end if;

  v_lines := jsonb_build_array(
    public._jl('1000', p_amount, 0, a.id, null, case when a.kind = 'cash' then s.id end),
    public._jl('1100', 0, v_alloc, null, c.id),
    public._jl('2000', 0, v_left, null, c.id));   -- overpayment becomes customer credit
  perform public._post_journal(v_me.business_id, v_date, 'collection', v_pay, 'Collection from ' || c.name, v_me.id, v_lines);
  perform public.write_audit(v_me.business_id, 'payment.collect', 'payment', v_pay::text, null,
    jsonb_build_object('customer', c.id, 'amount', p_amount, 'allocated', v_alloc, 'credit', v_left), null);
  return public._idem_put(p_idem, v_me.business_id, 'payment_collect', v_payload,
    jsonb_build_object('payment_id', v_pay, 'allocated', v_alloc, 'credit', v_left));
end $$;

-- Open (unpaid / partly paid) sales of a customer, oldest first.
create or replace function public.customer_open_sales(p_customer uuid)
returns table (sale_id uuid, ref_no text, sold_at timestamptz, total bigint, balance bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('customers.view') then raise exception 'not authorized' using errcode = '42501'; end if;
  return query select s.id, s.ref_no, s.sold_at, s.total, public._sale_balance(s.id)
    from public.sales s where s.customer_id = p_customer and s.business_id = (public.current_membership()).business_id
      and s.payment_status <> 'paid' order by s.sold_at, s.ref_no;
end $$;

-- ---------------------------------------------------------------------------
-- Returns, refunds, inspection
-- ---------------------------------------------------------------------------
create type public.return_status as enum ('requested', 'approved', 'rejected');

create table public.sale_returns (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references public.businesses(id),
  ref_no         text not null,
  sale_id        uuid not null references public.sales(id),
  status         public.return_status not null default 'requested',
  settlement     text not null check (settlement in ('credit','refund')),
  reason         text not null,
  amount         bigint not null check (amount >= 0),
  applied_to_sale bigint not null default 0,
  credit_amount  bigint not null default 0,   -- owed to customer after reducing the sale's own balance
  refunded       bigint not null default 0,
  requested_by   uuid not null references public.memberships(id),
  decided_by     uuid references public.memberships(id),
  decided_at     timestamptz,
  decision_note  text,
  created_at     timestamptz not null default now(),
  check (refunded <= credit_amount),
  unique (business_id, ref_no)
);
create table public.sale_return_lines (
  id            uuid primary key default gen_random_uuid(),
  return_id     uuid not null references public.sale_returns(id),
  sale_line_id  uuid not null references public.sale_lines(id),
  variant_id    uuid not null references public.variants(id),
  qty           int not null check (qty > 0),
  amount        bigint not null check (amount >= 0),
  released_qty  int not null default 0,
  check (released_qty <= qty)
);

create or replace function public._special_location(p_business uuid, p_kind public.location_kind, p_code text, p_name text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  select id into v from public.locations where business_id = p_business and kind = p_kind and is_active order by created_at limit 1;
  if v is null then
    insert into public.locations (business_id, code, name, kind) values (p_business, p_code, p_name, p_kind) returning id into v;
  end if;
  return v;
end $$;

create or replace function public.return_request(p_idem uuid, p_sale uuid, p_lines jsonb, p_reason text, p_settlement text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; s public.sales; v_ret uuid; v_ref text; r record;
        v_already int; v_amount bigint := 0; v_line_amount bigint;
begin
  v_me := public.require_permission('returns.request');
  v_payload := jsonb_build_object('sale', p_sale, 'lines', p_lines, 'reason', p_reason, 'settlement', p_settlement);
  v_prev := public._idem_get(p_idem, 'return_request', v_payload);
  if v_prev is not null then return v_prev; end if;
  if coalesce(btrim(p_reason),'') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  if p_settlement not in ('credit','refund') then raise exception 'settlement must be credit or refund' using errcode = '22023'; end if;
  select * into s from public.sales where id = p_sale and business_id = v_me.business_id for update;
  if s.id is null then raise exception 'not found' using errcode = '22023'; end if;
  perform public._require_location(s.location_id);
  if s.customer_id is null and p_settlement = 'credit' then raise exception 'walk-in returns are refunded, not credited' using errcode = '22023'; end if;
  v_ref := public._next_ref(v_me.business_id, 'RTN');
  insert into public.sale_returns (business_id, ref_no, sale_id, settlement, reason, amount, requested_by)
  values (v_me.business_id, v_ref, s.id, p_settlement, p_reason, 0, v_me.id) returning id into v_ret;
  for r in select x.sale_line_id, x.qty, sl.qty as sold_qty, sl.line_total, sl.variant_id
           from jsonb_to_recordset(p_lines) as x(sale_line_id uuid, qty int)
           join public.sale_lines sl on sl.id = x.sale_line_id and sl.sale_id = s.id loop
    select coalesce(sum(rl.qty), 0) into v_already from public.sale_return_lines rl join public.sale_returns rt on rt.id = rl.return_id
     where rl.sale_line_id = r.sale_line_id and rt.status <> 'rejected';
    if r.qty is null or r.qty <= 0 or v_already + r.qty > r.sold_qty then
      raise exception 'return quantity exceeds what was sold and not yet returned' using errcode = '22023';
    end if;
    v_line_amount := round(r.line_total::numeric * r.qty / r.sold_qty);
    insert into public.sale_return_lines (return_id, sale_line_id, variant_id, qty, amount) values (v_ret, r.sale_line_id, r.variant_id, r.qty, v_line_amount);
    v_amount := v_amount + v_line_amount;
  end loop;
  if v_amount = 0 and not exists (select 1 from public.sale_return_lines where return_id = v_ret) then raise exception 'no lines' using errcode = '22023'; end if;
  update public.sale_returns set amount = v_amount where id = v_ret;
  perform public.write_audit(v_me.business_id, 'return.request', 'sale_return', v_ret::text, null, jsonb_build_object('sale', s.ref_no, 'amount', v_amount), p_reason);
  return public._idem_put(p_idem, v_me.business_id, 'return_request', v_payload, jsonb_build_object('return_id', v_ret, 'ref_no', v_ref, 'amount', v_amount));
end $$;

-- Independent approval. Goods enter INSPECTION (not saleable). The sale's own balance is reduced first; the rest is owed to the customer.
create or replace function public.return_decide(p_return uuid, p_approve boolean, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; rt public.sale_returns; s public.sales; v_insp uuid; v_doc uuid; r record; v_cost bigint := 0;
        v_apply bigint; v_credit bigint; v_date date := public._business_date((public.current_membership()).business_id, now());
begin
  v_me := public.require_permission('returns.approve');
  select * into rt from public.sale_returns where id = p_return and business_id = v_me.business_id for update;
  if rt.id is null or rt.status <> 'requested' then raise exception 'return is not awaiting a decision' using errcode = '22023'; end if;
  if rt.requested_by = v_me.id then raise exception 'cannot approve your own return request' using errcode = '42501'; end if;
  if not p_approve then
    if coalesce(btrim(p_note),'') = '' then raise exception 'reason required' using errcode = '22023'; end if;
    update public.sale_returns set status = 'rejected', decided_by = v_me.id, decided_at = now(), decision_note = p_note where id = rt.id;
    perform public.write_audit(v_me.business_id, 'return.reject', 'sale_return', rt.id::text, null, null, p_note);
    return;
  end if;
  select * into s from public.sales where id = rt.sale_id for update;
  v_insp := public._special_location(v_me.business_id, 'inspection', 'INSPECT', 'Inspection / Ukaguzi');
  v_doc := public._new_doc(v_me.business_id, 'return_receipt', 'DOC', v_me.id, rt.id, rt.ref_no);
  for r in select rl.variant_id, rl.qty, slc.unit_cost from public.sale_return_lines rl
           join public.sale_line_costs slc on slc.sale_line_id = rl.sale_line_id where rl.return_id = rt.id loop
    perform public._move(v_me.business_id, v_doc, r.variant_id, v_insp, r.qty);
    v_cost := v_cost + coalesce(r.unit_cost, 0) * r.qty;   -- reverse COGS at the original snapshot cost
  end loop;
  v_apply := least(rt.amount, greatest(public._sale_balance(s.id), 0));
  v_credit := rt.amount - v_apply;
  if v_apply > 0 then insert into public.sale_settlements (sale_id, kind, return_id, amount) values (s.id, 'return', rt.id, v_apply); end if;
  perform public._post_journal(v_me.business_id, v_date, 'sale_return', rt.id, rt.ref_no, v_me.id, jsonb_build_array(
    public._jl('4900', rt.amount, 0),
    public._jl('1100', 0, v_apply, null, s.customer_id),
    public._jl('2000', 0, v_credit, null, s.customer_id),
    public._jl('1200', v_cost, 0),
    public._jl('5000', 0, v_cost)));
  perform public._refresh_payment_status(s.id);
  update public.sale_returns set status = 'approved', decided_by = v_me.id, decided_at = now(), decision_note = p_note,
         applied_to_sale = v_apply, credit_amount = v_credit where id = rt.id;
  perform public.write_audit(v_me.business_id, 'return.approve', 'sale_return', rt.id::text, null,
    jsonb_build_object('amount', rt.amount, 'applied', v_apply, 'credit', v_credit), p_note);
end $$;

create or replace function public.refund_pay(p_idem uuid, p_return uuid, p_account uuid, p_shift uuid, p_amount bigint, p_provider_ref text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; rt public.sale_returns; s public.shifts; a public.money_accounts; sa public.sales;
begin
  v_me := public.require_permission('refunds.pay');
  v_payload := jsonb_build_object('return', p_return, 'account', p_account, 'shift', p_shift, 'amount', p_amount, 'ref', p_provider_ref);
  v_prev := public._idem_get(p_idem, 'refund_pay', v_payload);
  if v_prev is not null then return v_prev; end if;
  select * into rt from public.sale_returns where id = p_return and business_id = v_me.business_id for update;  -- serialises refunds
  if rt.id is null or rt.status <> 'approved' then raise exception 'return is not approved' using errcode = '22023'; end if;
  if p_amount is null or p_amount <= 0 or rt.refunded + p_amount > rt.credit_amount then
    raise exception 'refund exceeds what is owed on this return (% of %)', rt.refunded, rt.credit_amount using errcode = '22023';
  end if;
  select * into sa from public.sales where id = rt.sale_id;
  if sa.customer_id is not null and p_amount > public._customer_credit(sa.customer_id) then
    raise exception 'customer credit already used' using errcode = '22023';
  end if;
  if p_shift is not null then s := public._lock_my_shift(p_shift, v_me.id); end if;
  a := public._usable_account(v_me.business_id, p_account, s);
  perform public._post_journal(v_me.business_id, public._business_date(v_me.business_id, now()), 'refund', rt.id, rt.ref_no, v_me.id,
    jsonb_build_array(public._jl('2000', p_amount, 0, null, sa.customer_id),
                      public._jl('1000', 0, p_amount, a.id, null, case when a.kind = 'cash' then s.id end)));
  update public.sale_returns set refunded = refunded + p_amount where id = rt.id;
  perform public.write_audit(v_me.business_id, 'refund.pay', 'sale_return', rt.id::text, null,
    jsonb_build_object('amount', p_amount, 'account', a.code, 'provider_ref', p_provider_ref), null);
  return public._idem_put(p_idem, v_me.business_id, 'refund_pay', v_payload, jsonb_build_object('return_id', rt.id, 'refunded', rt.refunded + p_amount));
end $$;

-- Inspection result: restock (back to the selling shop) or quarantine (damaged; stays company stock, not saleable).
create or replace function public.inspection_release(p_idem uuid, p_return_line uuid, p_qty int, p_outcome text, p_reason text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; rl public.sale_return_lines; rt public.sale_returns; s public.sales;
        v_insp uuid; v_dest uuid; v_doc uuid;
begin
  v_me := public.require_permission('inspection.release');
  v_payload := jsonb_build_object('line', p_return_line, 'qty', p_qty, 'outcome', p_outcome, 'reason', p_reason);
  v_prev := public._idem_get(p_idem, 'inspection_release', v_payload);
  if v_prev is not null then return v_prev; end if;
  if p_outcome not in ('restock','quarantine') then raise exception 'outcome must be restock or quarantine' using errcode = '22023'; end if;
  if coalesce(btrim(p_reason),'') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  select * into rl from public.sale_return_lines where id = p_return_line for update;
  select * into rt from public.sale_returns where id = rl.return_id and business_id = v_me.business_id;
  if rt.id is null or rt.status <> 'approved' then raise exception 'return not approved' using errcode = '22023'; end if;
  if p_qty is null or p_qty <= 0 or rl.released_qty + p_qty > rl.qty then raise exception 'quantity exceeds goods in inspection' using errcode = '22023'; end if;
  select * into s from public.sales where id = rt.sale_id;
  v_insp := public._special_location(v_me.business_id, 'inspection', 'INSPECT', 'Inspection / Ukaguzi');
  v_dest := case when p_outcome = 'restock' then s.location_id
                 else public._special_location(v_me.business_id, 'quarantine', 'QUARANTINE', 'Damaged / Zilizoharibika') end;
  v_doc := public._new_doc(v_me.business_id, 'inspection_release', 'DOC', v_me.id, rt.id, p_reason);
  perform public._move(v_me.business_id, v_doc, rl.variant_id, v_insp, -p_qty);
  perform public._move(v_me.business_id, v_doc, rl.variant_id, v_dest, p_qty);
  update public.sale_return_lines set released_qty = released_qty + p_qty where id = rl.id;
  perform public.write_audit(v_me.business_id, 'inspection.release', 'sale_return', rt.id::text, null,
    jsonb_build_object('qty', p_qty, 'outcome', p_outcome), p_reason);
  return public._idem_put(p_idem, v_me.business_id, 'inspection_release', v_payload, jsonb_build_object('released', rl.released_qty + p_qty));
end $$;

-- ---------------------------------------------------------------------------
-- Expenses
-- ---------------------------------------------------------------------------
create type public.expense_status as enum ('requested', 'approved', 'rejected', 'paid');

create table public.expenses (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references public.businesses(id),
  ref_no         text not null,
  location_id    uuid references public.locations(id),
  category       text not null check (length(btrim(category)) between 2 and 60),
  amount         bigint not null check (amount > 0),
  payee          text,
  description    text,
  expense_date   date not null,
  evidence_path  text,
  status         public.expense_status not null default 'requested',
  requested_by   uuid not null references public.memberships(id),
  decided_by     uuid references public.memberships(id),
  decided_at     timestamptz,
  decision_note  text,
  paid_by        uuid references public.memberships(id),
  paid_at        timestamptz,
  money_account_id uuid references public.money_accounts(id),
  provider_ref   text,
  created_at     timestamptz not null default now(),
  unique (business_id, ref_no)
);

create or replace function public.expense_request(p_idem uuid, p_location uuid, p_category text, p_amount bigint, p_payee text,
                                                  p_description text, p_expense_date date, p_evidence_path text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; v uuid; v_ref text;
begin
  v_me := public.require_permission('expenses.request');
  v_payload := jsonb_build_object('location', p_location, 'category', p_category, 'amount', p_amount, 'payee', p_payee,
                                  'description', p_description, 'date', p_expense_date, 'evidence', p_evidence_path);
  v_prev := public._idem_get(p_idem, 'expense_request', v_payload);
  if v_prev is not null then return v_prev; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'amount must be positive' using errcode = '22023'; end if;
  if p_location is not null then perform public._require_location(p_location); end if;
  v_ref := public._next_ref(v_me.business_id, 'EXP');
  insert into public.expenses (business_id, ref_no, location_id, category, amount, payee, description, expense_date, evidence_path, requested_by)
  values (v_me.business_id, v_ref, p_location, btrim(p_category), p_amount, nullif(btrim(p_payee),''), nullif(btrim(p_description),''),
          coalesce(p_expense_date, public._business_date(v_me.business_id, now())), nullif(btrim(p_evidence_path),''), v_me.id)
  returning id into v;
  perform public.write_audit(v_me.business_id, 'expense.request', 'expense', v::text, null, v_payload, null);
  return public._idem_put(p_idem, v_me.business_id, 'expense_request', v_payload, jsonb_build_object('expense_id', v, 'ref_no', v_ref));
end $$;

create or replace function public.expense_decide(p_expense uuid, p_approve boolean, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; e public.expenses;
begin
  v_me := public.require_permission('expenses.approve');
  select * into e from public.expenses where id = p_expense and business_id = v_me.business_id for update;
  if e.id is null or e.status <> 'requested' then raise exception 'expense is not awaiting a decision' using errcode = '22023'; end if;
  if e.requested_by = v_me.id then raise exception 'cannot approve your own expense' using errcode = '42501'; end if;
  if not p_approve and coalesce(btrim(p_note),'') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  update public.expenses set status = case when p_approve then 'approved'::public.expense_status else 'rejected'::public.expense_status end,
         decided_by = v_me.id, decided_at = now(), decision_note = p_note where id = e.id;
  perform public.write_audit(v_me.business_id, case when p_approve then 'expense.approve' else 'expense.reject' end, 'expense', e.id::text, null,
    jsonb_build_object('amount', e.amount, 'category', e.category), p_note);
end $$;

-- Payment and expense recognition: the expense is recognised in its own accounting date (expense_date), paid from one account once.
create or replace function public.expense_pay(p_idem uuid, p_expense uuid, p_account uuid, p_shift uuid, p_provider_ref text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; e public.expenses; s public.shifts; a public.money_accounts;
begin
  v_me := public.require_permission('expenses.pay');
  v_payload := jsonb_build_object('expense', p_expense, 'account', p_account, 'shift', p_shift, 'ref', p_provider_ref);
  v_prev := public._idem_get(p_idem, 'expense_pay', v_payload);
  if v_prev is not null then return v_prev; end if;
  select * into e from public.expenses where id = p_expense and business_id = v_me.business_id for update;
  if e.id is null or e.status <> 'approved' then raise exception 'expense is not approved (or already paid)' using errcode = '22023'; end if;
  if p_shift is not null then s := public._lock_my_shift(p_shift, v_me.id); end if;
  a := public._usable_account(v_me.business_id, p_account, s);
  perform public._post_journal(v_me.business_id, e.expense_date, 'expense', e.id, e.ref_no || ' ' || e.category, v_me.id, jsonb_build_array(
    public._jl('6000', e.amount, 0, null, null, null, e.category),
    public._jl('1000', 0, e.amount, a.id, null, case when a.kind = 'cash' then s.id end)));
  update public.expenses set status = 'paid', paid_by = v_me.id, paid_at = now(), money_account_id = a.id,
         provider_ref = nullif(btrim(p_provider_ref),'') where id = e.id;
  perform public.write_audit(v_me.business_id, 'expense.pay', 'expense', e.id::text, null, jsonb_build_object('account', a.code), null);
  return public._idem_put(p_idem, v_me.business_id, 'expense_pay', v_payload, jsonb_build_object('expense_id', e.id, 'status', 'paid'));
end $$;

-- ---------------------------------------------------------------------------
-- Deposits / transfers between money accounts (asset transfers, never revenue or expense)
-- ---------------------------------------------------------------------------
create type public.transfer_money_status as enum ('in_transit', 'confirmed');

create table public.money_transfers (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references public.businesses(id),
  ref_no         text not null,
  from_account   uuid not null references public.money_accounts(id),
  to_account     uuid not null references public.money_accounts(id),
  amount         bigint not null check (amount > 0),
  fee            bigint not null default 0 check (fee >= 0),
  reference      text,
  evidence_note  text,
  status         public.transfer_money_status not null default 'in_transit',
  sent_by        uuid not null references public.memberships(id),
  sent_at        timestamptz not null default now(),
  shift_id       uuid references public.shifts(id),
  confirmed_by   uuid references public.memberships(id),
  confirmed_at   timestamptz,
  provider_ref   text,
  check (from_account <> to_account),
  check (fee < amount),
  unique (business_id, ref_no)
);

create or replace function public.money_transfer_send(p_idem uuid, p_from uuid, p_to uuid, p_amount bigint, p_reference text,
                                                      p_evidence_note text, p_shift uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; s public.shifts; a public.money_accounts; b public.money_accounts; v uuid; v_ref text;
begin
  v_me := public.current_membership();
  if v_me.id is null then raise exception 'not authorized' using errcode = '42501'; end if;
  v_payload := jsonb_build_object('from', p_from, 'to', p_to, 'amount', p_amount, 'reference', p_reference, 'evidence', p_evidence_note, 'shift', p_shift);
  v_prev := public._idem_get(p_idem, 'money_transfer_send', v_payload);
  if v_prev is not null then return v_prev; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'amount must be positive' using errcode = '22023'; end if;
  if p_shift is not null then s := public._lock_my_shift(p_shift, v_me.id); end if;
  -- managers/owner move money; a cashier may deposit cash from their own open shift drawer
  if not public.has_permission('money.transfer') and not (public.has_permission('pos.sell') and s.id is not null and s.cash_account_id = p_from) then
    raise exception 'not authorized: money.transfer' using errcode = '42501';
  end if;
  a := public._usable_account(v_me.business_id, p_from, s);
  select * into b from public.money_accounts where id = p_to and business_id = v_me.business_id and is_active;
  if b.id is null or b.id = a.id then raise exception 'invalid destination account' using errcode = '22023'; end if;
  v_ref := public._next_ref(v_me.business_id, 'DEP');
  insert into public.money_transfers (business_id, ref_no, from_account, to_account, amount, reference, evidence_note, sent_by, shift_id)
  values (v_me.business_id, v_ref, a.id, b.id, p_amount, nullif(btrim(p_reference),''), nullif(btrim(p_evidence_note),''), v_me.id, s.id)
  returning id into v;
  perform public._post_journal(v_me.business_id, public._business_date(v_me.business_id, now()), 'money_transfer_send', v, v_ref, v_me.id,
    jsonb_build_array(public._jl('1050', p_amount, 0),
                      public._jl('1000', 0, p_amount, a.id, null, case when a.kind = 'cash' then s.id end)));
  perform public.write_audit(v_me.business_id, 'money.transfer_send', 'money_transfer', v::text, null,
    jsonb_build_object('from', a.code, 'to', b.code, 'amount', p_amount), p_reference);
  return public._idem_put(p_idem, v_me.business_id, 'money_transfer_send', v_payload, jsonb_build_object('transfer_id', v, 'ref_no', v_ref));
end $$;

create or replace function public.money_transfer_confirm(p_transfer uuid, p_fee bigint, p_provider_ref text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; t public.money_transfers;
begin
  v_me := public.require_permission('money.transfer');
  select * into t from public.money_transfers where id = p_transfer and business_id = v_me.business_id for update;
  if t.id is null or t.status <> 'in_transit' then raise exception 'transfer is not awaiting confirmation' using errcode = '22023'; end if;
  if t.sent_by = v_me.id then raise exception 'the receiver must confirm, not the sender' using errcode = '42501'; end if;
  if coalesce(p_fee,0) < 0 or coalesce(p_fee,0) >= t.amount then raise exception 'invalid fee' using errcode = '22023'; end if;
  perform public._post_journal(v_me.business_id, public._business_date(v_me.business_id, now()), 'money_transfer_confirm', t.id, t.ref_no, v_me.id,
    jsonb_build_array(public._jl('1000', t.amount - coalesce(p_fee,0), 0, t.to_account),
                      public._jl('6400', coalesce(p_fee,0), 0),
                      public._jl('1050', 0, t.amount)));
  update public.money_transfers set status = 'confirmed', confirmed_by = v_me.id, confirmed_at = now(), fee = coalesce(p_fee,0),
         provider_ref = nullif(btrim(p_provider_ref),'') where id = t.id;
  perform public.write_audit(v_me.business_id, 'money.transfer_confirm', 'money_transfer', t.id::text, null,
    jsonb_build_object('fee', p_fee, 'provider_ref', p_provider_ref), null);
end $$;

-- ---------------------------------------------------------------------------
-- Runner advances (delivery): advance ≠ expense; the expense is recognised once, at settlement.
-- ---------------------------------------------------------------------------
create type public.advance_status as enum ('outstanding', 'settled');

create table public.runner_advances (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references public.businesses(id),
  ref_no         text not null,
  runner_name    text not null,
  sale_id        uuid references public.sales(id),
  money_account_id uuid not null references public.money_accounts(id),
  amount         bigint not null check (amount > 0),
  status         public.advance_status not null default 'outstanding',
  issued_by      uuid not null references public.memberships(id),
  issued_at      timestamptz not null default now(),
  issue_shift    uuid references public.shifts(id),
  expense_amount bigint,
  returned_amount bigint,
  settled_by     uuid references public.memberships(id),
  settled_at     timestamptz,
  evidence_note  text,
  unique (business_id, ref_no)
);

create or replace function public.advance_issue(p_idem uuid, p_runner_name text, p_sale uuid, p_account uuid, p_amount bigint, p_shift uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; s public.shifts; a public.money_accounts; v uuid; v_ref text;
begin
  v_me := public.require_permission('deliveries.manage');
  v_payload := jsonb_build_object('runner', p_runner_name, 'sale', p_sale, 'account', p_account, 'amount', p_amount, 'shift', p_shift);
  v_prev := public._idem_get(p_idem, 'advance_issue', v_payload);
  if v_prev is not null then return v_prev; end if;
  if coalesce(btrim(p_runner_name),'') = '' then raise exception 'runner name required' using errcode = '22023'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'amount must be positive' using errcode = '22023'; end if;
  if p_sale is not null and not exists (select 1 from public.sales where id = p_sale and business_id = v_me.business_id) then
    raise exception 'unknown sale' using errcode = '22023';
  end if;
  if p_shift is not null then s := public._lock_my_shift(p_shift, v_me.id); end if;
  a := public._usable_account(v_me.business_id, p_account, s);
  v_ref := public._next_ref(v_me.business_id, 'ADV');
  insert into public.runner_advances (business_id, ref_no, runner_name, sale_id, money_account_id, amount, issued_by, issue_shift)
  values (v_me.business_id, v_ref, btrim(p_runner_name), p_sale, a.id, p_amount, v_me.id, s.id) returning id into v;
  perform public._post_journal(v_me.business_id, public._business_date(v_me.business_id, now()), 'advance_issue', v, v_ref, v_me.id,
    jsonb_build_array(public._jl('1150', p_amount, 0), public._jl('1000', 0, p_amount, a.id, null, case when a.kind = 'cash' then s.id end)));
  perform public.write_audit(v_me.business_id, 'advance.issue', 'runner_advance', v::text, null, v_payload, null);
  return public._idem_put(p_idem, v_me.business_id, 'advance_issue', v_payload, jsonb_build_object('advance_id', v, 'ref_no', v_ref));
end $$;

create or replace function public.advance_settle(p_advance uuid, p_expense bigint, p_returned bigint, p_return_account uuid, p_shift uuid, p_evidence_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; ad public.runner_advances; s public.shifts; a public.money_accounts;
begin
  v_me := public.require_permission('deliveries.manage');
  select * into ad from public.runner_advances where id = p_advance and business_id = v_me.business_id for update;
  if ad.id is null or ad.status <> 'outstanding' then raise exception 'advance is not outstanding' using errcode = '22023'; end if;
  if coalesce(p_expense,-1) < 0 or coalesce(p_returned,-1) < 0 or p_expense + p_returned <> ad.amount then
    raise exception 'expense + returned must equal the advance (%)', ad.amount using errcode = '22023';
  end if;
  if coalesce(btrim(p_evidence_note),'') = '' then raise exception 'evidence note required (receipt / recipient)' using errcode = '22023'; end if;
  if p_returned > 0 then
    if p_shift is not null then s := public._lock_my_shift(p_shift, v_me.id); end if;
    a := public._usable_account(v_me.business_id, p_return_account, s);
  end if;
  perform public._post_journal(v_me.business_id, public._business_date(v_me.business_id, now()), 'advance_settle', ad.id, ad.ref_no, v_me.id,
    jsonb_build_array(public._jl('6100', p_expense, 0, null, null, null, 'delivery'),
                      public._jl('1000', p_returned, 0, a.id, null, case when a.kind = 'cash' then s.id end),
                      public._jl('1150', 0, ad.amount)));
  update public.runner_advances set status = 'settled', expense_amount = p_expense, returned_amount = p_returned,
         settled_by = v_me.id, settled_at = now(), evidence_note = p_evidence_note where id = ad.id;
  perform public.write_audit(v_me.business_id, 'advance.settle', 'runner_advance', ad.id::text, null,
    jsonb_build_object('expense', p_expense, 'returned', p_returned), p_evidence_note);
end $$;

-- ---------------------------------------------------------------------------
-- Inventory accounting hooks for Milestone B documents
-- ---------------------------------------------------------------------------
-- Approved receipt costs: Dr Inventory / Cr Supplier payables.
create or replace function public.tg_receipt_costs_journal() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_total bigint;
begin
  if new.cost_status = 'approved' and old.cost_status = 'pending' then
    select coalesce(sum(l.qty_received::bigint * c.unit_cost + c.landed_alloc), 0) into v_total
      from public.goods_receipt_lines l join public.goods_receipt_costs c on c.receipt_line_id = l.id where l.receipt_id = new.id;
    perform public._post_journal(new.business_id, public._business_date(new.business_id, coalesce(new.cost_approved_at, now())),
      'goods_receipt_costs', new.id, new.ref_no, new.cost_approved_by,
      jsonb_build_array(public._jl('1200', v_total, 0), public._jl('2100', 0, v_total)));
  end if;
  return new;
end $$;
create trigger goods_receipts_costs_journal after update of cost_status on public.goods_receipts
  for each row execute function public.tg_receipt_costs_journal();

-- Written-off transit shortages: Dr Stock losses / Cr Inventory at average cost (if known).
create or replace function public.tg_discrepancy_writeoff_journal() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_cost bigint; v_variant uuid;
begin
  if new.status = 'resolved' and old.status = 'open' and new.resolution = 'written_off' then
    select tl.variant_id into v_variant from public.transfer_lines tl where tl.id = new.transfer_line_id;
    select avg_cost into v_cost from public.variant_costs where variant_id = v_variant;
    if v_cost is not null then
      perform public._post_journal(new.business_id, public._business_date(new.business_id, now()), 'stock_writeoff', new.id,
        'Transit shortage written off', new.resolved_by,
        jsonb_build_array(public._jl('6200', v_cost * new.qty, 0), public._jl('1200', 0, v_cost * new.qty)));
    end if;
  end if;
  return new;
end $$;
create trigger transfer_discrepancies_writeoff_journal after update of status on public.transfer_discrepancies
  for each row execute function public.tg_discrepancy_writeoff_journal();

-- Approved count variances: loss (or gain) against inventory at average cost (if known).
create or replace function public.tg_count_variance_journal() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_cost bigint; c public.stock_counts; v_amt bigint;
begin
  if new.variance is not null and new.variance <> 0 and old.variance is null then
    select * into c from public.stock_counts where id = new.count_id;
    select avg_cost into v_cost from public.variant_costs where variant_id = new.variant_id;
    if v_cost is not null then
      v_amt := v_cost * abs(new.variance);
      perform public._post_journal(c.business_id, public._business_date(c.business_id, now()), 'count_variance', new.id, c.ref_no, null,
        case when new.variance < 0 then jsonb_build_array(public._jl('6200', v_amt, 0), public._jl('1200', 0, v_amt))
             else jsonb_build_array(public._jl('1200', v_amt, 0), public._jl('6200', 0, v_amt)) end);
    end if;
  end if;
  return new;
end $$;
create trigger stock_count_lines_variance_journal after update of variance on public.stock_count_lines
  for each row execute function public.tg_count_variance_journal();

-- ---------------------------------------------------------------------------
-- Read models
-- ---------------------------------------------------------------------------
create or replace function public.money_balances()
returns table (account_id uuid, code text, name text, kind public.money_kind, location_id uuid, balance bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('money.view') then raise exception 'not authorized' using errcode = '42501'; end if;
  return query select a.id, a.code, a.name, a.kind, a.location_id,
      coalesce((select sum(jl.debit - jl.credit) from public.journal_lines jl where jl.account_code = '1000' and jl.money_account_id = a.id), 0)::bigint
    from public.money_accounts a where a.business_id = (public.current_membership()).business_id and a.is_active order by a.kind, a.code;
end $$;

create or replace function public.customer_balances()
returns table (customer_id uuid, receivable bigint, credit bigint, oldest_open timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('customers.view') then raise exception 'not authorized' using errcode = '42501'; end if;
  return query select c.id, public._customer_receivable(c.id), public._customer_credit(c.id),
      (select min(s.sold_at) from public.sales s where s.customer_id = c.id and s.payment_status <> 'paid')
    from public.customers c where c.business_id = (public.current_membership()).business_id;
end $$;

-- My open shift summary (the cashier sees their own expected cash only after counting — the UI shows totals by method instead).
create or replace function public.my_shift()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_me public.memberships; s public.shifts;
begin
  v_me := public.current_membership();
  if v_me.id is null then return null; end if;
  select * into s from public.shifts where opened_by = v_me.id and status = 'open';
  if s.id is null then return null; end if;
  return jsonb_build_object('id', s.id, 'ref_no', s.ref_no, 'location_id', s.location_id, 'cash_account_id', s.cash_account_id,
    'opened_at', s.opened_at, 'opening_float', s.opening_float,
    'sales_count', (select count(*) from public.sales where shift_id = s.id),
    'sales_total', (select coalesce(sum(total),0) from public.sales where shift_id = s.id),
    'by_method', (select coalesce(jsonb_object_agg(method, amt), '{}') from (select p.method, sum(p.amount) amt from public.payments p where p.shift_id = s.id group by p.method) m));
end $$;

-- Owner overview with explicit bases: net sales by sale date, collections by payment date, balances as of now.
create or replace function public.business_overview(p_from date, p_to date)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_me public.memberships; b uuid;
begin
  if not public.has_permission('money.view') then raise exception 'not authorized' using errcode = '42501'; end if;
  v_me := public.current_membership(); b := v_me.business_id;
  return jsonb_build_object(
    'period', jsonb_build_object('from', p_from, 'to', p_to, 'timezone', (select timezone from public.businesses where id = b)),
    'net_sales', (select coalesce(sum(jl.credit - jl.debit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
                   where je.business_id = b and je.entry_date between p_from and p_to and jl.account_code in ('4000','4900')),
    'delivery_income', (select coalesce(sum(jl.credit - jl.debit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
                   where je.business_id = b and je.entry_date between p_from and p_to and jl.account_code = '4100'),
    'collections', (select coalesce(sum(p.amount),0) from public.payments p
                    where p.business_id = b and public._business_date(b, p.received_at) between p_from and p_to),
    'collections_old_debt', (select coalesce(sum(ss.amount),0) from public.sale_settlements ss join public.payments p on p.id = ss.payment_id
                    join public.sales s on s.id = ss.sale_id
                    where p.business_id = b and public._business_date(b, p.received_at) between p_from and p_to
                      and public._business_date(b, s.sold_at) < p_from),
    'cogs', (select coalesce(sum(jl.debit - jl.credit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
              where je.business_id = b and je.entry_date between p_from and p_to and jl.account_code = '5000'),
    'expenses', (select coalesce(sum(jl.debit - jl.credit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
              where je.business_id = b and je.entry_date between p_from and p_to and jl.account_code in ('6000','6100','6200','6300','6400')),
    'units_sold', (select coalesce(sum(sl.qty),0) from public.sale_lines sl join public.sales s on s.id = sl.sale_id
                    where s.business_id = b and public._business_date(b, s.sold_at) between p_from and p_to),
    'units_cost_unknown', (select coalesce(sum(sl.qty),0) from public.sale_lines sl join public.sales s on s.id = sl.sale_id
                    join public.sale_line_costs c on c.sale_line_id = sl.id
                    where s.business_id = b and not c.cost_known and public._business_date(b, s.sold_at) between p_from and p_to),
    'cash_by_kind', (select coalesce(jsonb_object_agg(kind, bal), '{}') from (select a.kind, sum(jl.debit - jl.credit) bal from public.money_accounts a
                    join public.journal_lines jl on jl.money_account_id = a.id and jl.account_code = '1000' where a.business_id = b group by a.kind) k),
    'funds_in_transit', (select coalesce(sum(jl.debit - jl.credit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
                    where je.business_id = b and jl.account_code = '1050'),
    'receivables', (select coalesce(sum(jl.debit - jl.credit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
                    where je.business_id = b and jl.account_code = '1100'),
    'customer_credits', (select coalesce(sum(jl.credit - jl.debit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
                    where je.business_id = b and jl.account_code = '2000'),
    'saleable_units', (select coalesce(sum(sb.on_hand - sb.reserved),0) from public.stock_balances sb join public.locations l on l.id = sb.location_id
                    where l.business_id = b and l.kind in ('warehouse','shop')),
    'units_not_saleable', (select coalesce(sum(sb.on_hand),0) from public.stock_balances sb join public.locations l on l.id = sb.location_id
                    where l.business_id = b and l.kind in ('transit','inspection','quarantine')),
    'inventory_value_known', (select coalesce(sum(sb.on_hand::bigint * vc.avg_cost),0) from public.stock_balances sb
                    join public.locations l on l.id = sb.location_id join public.variant_costs vc on vc.variant_id = sb.variant_id
                    where l.business_id = b),
    'units_without_cost', (select coalesce(sum(sb.on_hand),0) from public.stock_balances sb join public.locations l on l.id = sb.location_id
                    left join public.variant_costs vc on vc.variant_id = sb.variant_id where l.business_id = b and vc.avg_cost is null),
    'pending_approvals', (select count(*) from public.approval_requests where business_id = b and status = 'pending'),
    'shifts_open', (select count(*) from public.shifts where business_id = b and status = 'open'),
    'shifts_pending_review', (select count(*) from public.shifts where business_id = b and status = 'pending_review')
  );
end $$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.discount_limits enable row level security;
alter table public.ledger_accounts enable row level security;
alter table public.money_accounts enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_lines enable row level security;
alter table public.customers enable row level security;
alter table public.shifts enable row level security;
alter table public.approval_requests enable row level security;
alter table public.sales enable row level security;
alter table public.sale_lines enable row level security;
alter table public.sale_line_costs enable row level security;
alter table public.payments enable row level security;
alter table public.sale_settlements enable row level security;
alter table public.sale_returns enable row level security;
alter table public.sale_return_lines enable row level security;
alter table public.expenses enable row level security;
alter table public.money_transfers enable row level security;
alter table public.runner_advances enable row level security;

create policy discount_limits_read on public.discount_limits for select to authenticated using (true);
create policy ledger_accounts_read on public.ledger_accounts for select to authenticated using (true);

create policy money_accounts_read on public.money_accounts for select to authenticated
  using (public.is_business_member(business_id)
         and (public.has_permission('money.view') or public.has_permission('money.transfer')
              or (location_id is not null and public.can_access_location(location_id))
              or kind <> 'cash'));
create policy journal_entries_read on public.journal_entries for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('journal.view'));
create policy journal_lines_read on public.journal_lines for select to authenticated
  using (public.has_permission('journal.view') and exists (select 1 from public.journal_entries e where e.id = entry_id and public.is_business_member(e.business_id)));

create policy customers_read on public.customers for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('customers.view'));

create policy shifts_read on public.shifts for select to authenticated
  using (public.is_business_member(business_id)
         and (opened_by = (public.current_membership()).id or public.has_permission('shift.review') or public.has_permission('money.view')));

create policy approvals_read on public.approval_requests for select to authenticated
  using (public.is_business_member(business_id)
         and (requested_by = (public.current_membership()).id or public.has_permission('approvals.decide')));

create policy sales_read on public.sales for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('sales.view')
         and (public.can_access_location(location_id) or public.has_permission('money.view')));
create policy sale_lines_read on public.sale_lines for select to authenticated
  using (exists (select 1 from public.sales s where s.id = sale_id and public.is_business_member(s.business_id) and public.has_permission('sales.view')
                 and (public.can_access_location(s.location_id) or public.has_permission('money.view'))));
create policy sale_line_costs_read on public.sale_line_costs for select to authenticated
  using (public.has_permission('costs.view') and exists (select 1 from public.sale_lines l join public.sales s on s.id = l.sale_id
         where l.id = sale_line_id and public.is_business_member(s.business_id)));
create policy payments_read on public.payments for select to authenticated
  using (public.is_business_member(business_id)
         and (public.has_permission('money.view') or received_by = (public.current_membership()).id
              or (location_id is not null and public.can_access_location(location_id) and public.has_permission('sales.view'))));
create policy settlements_read on public.sale_settlements for select to authenticated
  using (exists (select 1 from public.sales s where s.id = sale_id and public.is_business_member(s.business_id) and public.has_permission('sales.view')
                 and (public.can_access_location(s.location_id) or public.has_permission('money.view'))));
create policy returns_read on public.sale_returns for select to authenticated
  using (public.is_business_member(business_id) and (public.has_permission('returns.request') or public.has_permission('returns.approve')
         or public.has_permission('inspection.release')));
create policy return_lines_read on public.sale_return_lines for select to authenticated
  using (exists (select 1 from public.sale_returns r where r.id = return_id and public.is_business_member(r.business_id)
                 and (public.has_permission('returns.request') or public.has_permission('returns.approve') or public.has_permission('inspection.release'))));
create policy expenses_read on public.expenses for select to authenticated
  using (public.is_business_member(business_id)
         and (requested_by = (public.current_membership()).id or public.has_permission('expenses.approve')
              or public.has_permission('expenses.pay') or public.has_permission('money.view')));
create policy money_transfers_read on public.money_transfers for select to authenticated
  using (public.is_business_member(business_id)
         and (sent_by = (public.current_membership()).id or public.has_permission('money.transfer') or public.has_permission('money.view')));
create policy advances_read on public.runner_advances for select to authenticated
  using (public.is_business_member(business_id) and (public.has_permission('deliveries.manage') or public.has_permission('money.view')));

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
revoke all on public.discount_limits, public.ledger_accounts, public.money_accounts, public.journal_entries, public.journal_lines,
  public.customers, public.shifts, public.approval_requests, public.sales, public.sale_lines, public.sale_line_costs, public.payments,
  public.sale_settlements, public.sale_returns, public.sale_return_lines, public.expenses, public.money_transfers, public.runner_advances
from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant select on public.discount_limits, public.ledger_accounts, public.money_accounts, public.journal_entries, public.journal_lines,
  public.customers, public.shifts, public.approval_requests, public.sales, public.sale_lines, public.sale_line_costs, public.payments,
  public.sale_settlements, public.sale_returns, public.sale_return_lines, public.expenses, public.money_transfers, public.runner_advances
to authenticated;

grant execute on function
  public.customer_save(uuid, text, text, public.customer_kind, bigint, int, text, text, text),
  public.money_account_create(text, text, public.money_kind, uuid),
  public.money_account_opening(uuid, bigint, date, text),
  public.shift_open(uuid, uuid, bigint), public.shift_close(uuid, bigint, text), public.shift_review(uuid, text),
  public.approval_decide(uuid, boolean, text),
  public.sale_post(uuid, uuid, uuid, uuid, text, jsonb, bigint, text, jsonb, timestamptz, text, text, uuid),
  public.sale_set_fulfillment(uuid, public.fulfillment_status, text),
  public.payment_collect(uuid, uuid, uuid, bigint, text, uuid, jsonb),
  public.customer_open_sales(uuid),
  public.return_request(uuid, uuid, jsonb, text, text), public.return_decide(uuid, boolean, text),
  public.refund_pay(uuid, uuid, uuid, uuid, bigint, text),
  public.inspection_release(uuid, uuid, int, text, text),
  public.expense_request(uuid, uuid, text, bigint, text, text, date, text), public.expense_decide(uuid, boolean, text),
  public.expense_pay(uuid, uuid, uuid, uuid, text),
  public.money_transfer_send(uuid, uuid, uuid, bigint, text, text, uuid), public.money_transfer_confirm(uuid, bigint, text),
  public.advance_issue(uuid, text, uuid, uuid, bigint, uuid), public.advance_settle(uuid, bigint, bigint, uuid, uuid, text),
  public.money_balances(), public.customer_balances(), public.my_shift(), public.business_overview(date, date)
to authenticated;

commit;
