-- DIROMA Business OS — Milestone B: catalogue, one stock ledger, Store/Stoo workflows, purchasing.
--
-- Stock model
--   * stock_balances(variant, location): on_hand >= 0, 0 <= reserved <= on_hand  (CHECK constraints)
--   * every change is a stock_movements row linked to a stock_documents row (source, actor, server time)
--   * Store, Shop and Wholesale views all read this single ledger
--   * transfers move warehouse -> TRANSIT -> shop; nothing is assumed received at dispatch
--   * all posting functions take an idempotency key: same key + same payload returns the first result,
--     same key + different payload is rejected
-- Costs are confidential: variant_costs / receipt cost tables are readable only with costs.view.

begin;

-- ---------------------------------------------------------------------------
-- Permissions for Milestone B
-- ---------------------------------------------------------------------------
insert into public.permissions (code, description) values
  ('purchasing.manage',     'Suppliers and purchase orders'),
  ('costs.approve',         'Approve buying and landed costs'),
  ('stock.request',         'Raise shop stock requisitions'),
  ('stock.approve',         'Approve requisitions, resolve discrepancies, approve counts, ad-hoc transfers'),
  ('stock.confirm_receipt', 'Confirm receipt of transferred goods at an assigned location'),
  ('stock.opening',         'Post controlled opening stock');

insert into public.role_permissions (role, permission)
select 'owner', code from public.permissions
where code in ('purchasing.manage','costs.approve','stock.request','stock.approve','stock.confirm_receipt','stock.opening');

insert into public.role_permissions (role, permission) values
  ('manager', 'products.manage'), ('manager', 'purchasing.manage'), ('manager', 'stock.request'),
  ('manager', 'stock.approve'), ('manager', 'stock.confirm_receipt'),
  ('sales_staff', 'stock.request'), ('sales_staff', 'stock.confirm_receipt'),
  ('storekeeper', 'stock.confirm_receipt');

-- ---------------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------------
create table public.size_sets (
  code  text primary key,
  name  text not null
);
create table public.size_set_sizes (
  size_set text not null references public.size_sets(code),
  size     text not null,
  sort     int  not null,
  primary key (size_set, size)
);
insert into public.size_sets values ('suit', 'Suits / jackets 42–60'), ('shoes', 'Shoes 39–46'),
  ('shirt', 'Shirts S–3XL'), ('one', 'One size');
insert into public.size_set_sizes select 'suit', s::text, s from generate_series(42, 60, 2) s;
insert into public.size_set_sizes select 'shoes', s::text, s from generate_series(39, 46) s;
insert into public.size_set_sizes values ('shirt','S',1),('shirt','M',2),('shirt','L',3),('shirt','XL',4),
  ('shirt','2XL',5),('shirt','3XL',6),('one','ONE',1);

create table public.categories (
  code      text primary key,
  name_en   text not null,
  name_sw   text not null,
  size_set  text not null references public.size_sets(code)
);
insert into public.categories values
  ('suit_2pc','Suit 2pc','Suti vipande 2','suit'), ('suit_3pc','Suit 3pc','Suti vipande 3','suit'),
  ('tuxedo','Tuxedo','Tuxedo','suit'), ('jacket','Jacket / blazer','Koti','suit'),
  ('waistcoat','Waistcoat','Kizibao','suit'), ('trousers','Trousers','Suruali','suit'),
  ('shirt','Shirt','Shati','shirt'), ('shoes','Shoes','Viatu','shoes'),
  ('accessory','Accessory','Vifaa (tai, mkanda…)','one');

create table public.suppliers (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  name        text not null check (length(btrim(name)) between 2 and 120),
  phone       text,
  country     text,
  notes       text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (business_id, name)
);

create table public.designs (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id),
  code         text not null check (length(btrim(code)) between 1 and 60), -- original code, may contain '#'
  name         text not null check (length(btrim(name)) between 2 and 120),
  category     text not null references public.categories(code),
  supplier_id  uuid references public.suppliers(id),
  description  text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  unique (business_id, code)
);

create sequence public.barcode_seq start 100001;

create table public.variants (
  id               uuid primary key default gen_random_uuid(),
  business_id      uuid not null references public.businesses(id),
  design_id        uuid not null references public.designs(id),
  color            text not null check (length(btrim(color)) between 1 and 40),
  size             text not null check (length(btrim(size)) between 1 and 10),
  sku              text not null,
  barcode          text not null check (barcode ~ '^[0-9A-Z-]{4,32}$'),
  retail_price     bigint check (retail_price is null or retail_price > 0),     -- TZS, integer
  wholesale_price  bigint check (wholesale_price is null or wholesale_price > 0),
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  unique (design_id, color, size),
  unique (business_id, sku),
  unique (business_id, barcode)
);
create index variants_design on public.variants (design_id);

-- Confidential: buying cost. Separate table so RLS can hide it completely from non-cost roles.
create table public.variant_costs (
  variant_id     uuid primary key references public.variants(id),
  costed_qty     bigint not null default 0,
  total_cost     bigint not null default 0,  -- TZS
  avg_cost       bigint generated always as (case when costed_qty > 0 then round(total_cost::numeric / costed_qty)::bigint end) stored,
  last_unit_cost bigint,
  updated_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Ledger
-- ---------------------------------------------------------------------------
create type public.stock_doc_type as enum
  ('opening', 'goods_receipt', 'transfer_dispatch', 'transfer_receipt', 'discrepancy_resolution', 'count_adjustment');

create table public.stock_documents (
  id                  uuid primary key default gen_random_uuid(),
  business_id         uuid not null references public.businesses(id),
  doc_type            public.stock_doc_type not null,
  ref_no              text not null,
  source_id           uuid,
  actor_membership_id uuid not null references public.memberships(id),
  reason              text,
  created_at          timestamptz not null default now(),
  unique (business_id, ref_no)
);

create table public.stock_movements (
  id           bigint generated always as identity primary key,
  business_id  uuid not null references public.businesses(id),
  document_id  uuid not null references public.stock_documents(id),
  variant_id   uuid not null references public.variants(id),
  location_id  uuid not null references public.locations(id),
  qty_delta    int  not null check (qty_delta <> 0),
  created_at   timestamptz not null default now()
);
create index stock_movements_vl on public.stock_movements (variant_id, location_id, id);
create index stock_movements_loc on public.stock_movements (location_id, id desc);

create table public.stock_balances (
  variant_id   uuid not null references public.variants(id),
  location_id  uuid not null references public.locations(id),
  business_id  uuid not null references public.businesses(id),
  on_hand      int not null default 0 check (on_hand >= 0),
  reserved     int not null default 0 check (reserved >= 0),
  updated_at   timestamptz not null default now(),
  primary key (variant_id, location_id),
  check (reserved <= on_hand)
);
create index stock_balances_loc on public.stock_balances (location_id);

create table public.doc_sequences (
  business_id uuid not null references public.businesses(id),
  prefix      text not null,
  next_no     bigint not null default 1,
  primary key (business_id, prefix)
);

create table public.idempotency_keys (
  key           uuid primary key,
  business_id   uuid not null,
  actor_user_id uuid not null,
  operation     text not null,
  payload_hash  text not null,
  result        jsonb not null,
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Purchasing & receiving
-- ---------------------------------------------------------------------------
create type public.po_status as enum ('ordered', 'partially_received', 'received', 'cancelled');

create table public.purchase_orders (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id),
  ref_no       text not null,
  supplier_id  uuid not null references public.suppliers(id),
  status       public.po_status not null default 'ordered',
  currency     char(3) not null default 'TZS',
  fx_rate      numeric(18,6) not null default 1 check (fx_rate > 0),  -- TZS per 1 unit of currency
  expected_at  date,
  notes        text,
  created_by   uuid not null references public.memberships(id),
  created_at   timestamptz not null default now(),
  unique (business_id, ref_no)
);
create table public.purchase_order_lines (
  id            uuid primary key default gen_random_uuid(),
  po_id         uuid not null references public.purchase_orders(id),
  variant_id    uuid not null references public.variants(id),
  qty_ordered   int not null check (qty_ordered > 0),
  qty_received  int not null default 0 check (qty_received >= 0),
  unit_price_fx numeric(18,4) check (unit_price_fx is null or unit_price_fx >= 0), -- agreed price in PO currency
  unique (po_id, variant_id)
);

create type public.cost_status as enum ('pending', 'approved');

create table public.goods_receipts (
  id                 uuid primary key default gen_random_uuid(),
  business_id        uuid not null references public.businesses(id),
  ref_no             text not null,
  location_id        uuid not null references public.locations(id),
  supplier_id        uuid references public.suppliers(id),
  po_id              uuid references public.purchase_orders(id),
  supplier_ref       text,
  received_by        uuid not null references public.memberships(id),
  received_at        timestamptz not null default now(),
  notes              text,
  cost_status        public.cost_status not null default 'pending',
  cost_approved_by   uuid references public.memberships(id),
  cost_approved_at   timestamptz,
  document_id        uuid not null references public.stock_documents(id),
  unique (business_id, ref_no)
);
create table public.goods_receipt_lines (
  id            uuid primary key default gen_random_uuid(),
  receipt_id    uuid not null references public.goods_receipts(id),
  variant_id    uuid not null references public.variants(id),
  qty_expected  int check (qty_expected is null or qty_expected >= 0),
  qty_received  int not null check (qty_received >= 0),
  unique (receipt_id, variant_id)
);
-- Confidential cost detail for a receipt.
create table public.goods_receipt_costs (
  receipt_line_id  uuid primary key references public.goods_receipt_lines(id),
  unit_cost        bigint not null check (unit_cost >= 0),  -- supplier price in TZS
  landed_alloc     bigint not null default 0 check (landed_alloc >= 0), -- this line's share of extra costs, TZS
  unit_landed_cost bigint not null check (unit_landed_cost >= 0)
);
create table public.goods_receipt_extra_costs (
  id          uuid primary key default gen_random_uuid(),
  receipt_id  uuid not null references public.goods_receipts(id),
  label       text not null,
  amount      bigint not null check (amount >= 0),
  allocation  text not null check (allocation in ('value','qty'))
);

-- ---------------------------------------------------------------------------
-- Requisitions, transfers, discrepancies
-- ---------------------------------------------------------------------------
create type public.requisition_status as enum ('submitted', 'approved', 'rejected', 'partially_dispatched', 'dispatched', 'cancelled');

create table public.requisitions (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references public.businesses(id),
  ref_no         text not null,
  from_location  uuid not null references public.locations(id),
  to_location    uuid not null references public.locations(id),
  status         public.requisition_status not null default 'submitted',
  requested_by   uuid not null references public.memberships(id),
  decided_by     uuid references public.memberships(id),
  decided_at     timestamptz,
  decision_note  text,
  notes          text,
  created_at     timestamptz not null default now(),
  check (from_location <> to_location),
  unique (business_id, ref_no)
);
create table public.requisition_lines (
  id              uuid primary key default gen_random_uuid(),
  requisition_id  uuid not null references public.requisitions(id),
  variant_id      uuid not null references public.variants(id),
  qty_requested   int not null check (qty_requested > 0),
  qty_approved    int not null default 0 check (qty_approved >= 0),
  qty_dispatched  int not null default 0 check (qty_dispatched >= 0),
  check (qty_dispatched <= qty_approved)
);

create type public.transfer_status as enum ('in_transit', 'received', 'received_with_discrepancy');

create table public.transfers (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null references public.businesses(id),
  ref_no          text not null,
  requisition_id  uuid references public.requisitions(id),
  from_location   uuid not null references public.locations(id),
  to_location     uuid not null references public.locations(id),
  transit_location uuid not null references public.locations(id),
  status          public.transfer_status not null default 'in_transit',
  dispatched_by   uuid not null references public.memberships(id),
  dispatched_at   timestamptz not null default now(),
  received_by     uuid references public.memberships(id),
  received_at     timestamptz,
  receipt_override_reason text,
  notes           text,
  dispatch_doc    uuid not null references public.stock_documents(id),
  receipt_doc     uuid references public.stock_documents(id),
  unique (business_id, ref_no)
);
create table public.transfer_lines (
  id                  uuid primary key default gen_random_uuid(),
  transfer_id         uuid not null references public.transfers(id),
  variant_id          uuid not null references public.variants(id),
  requisition_line_id uuid references public.requisition_lines(id),
  qty_sent            int not null check (qty_sent > 0),
  qty_received        int check (qty_received is null or (qty_received >= 0 and qty_received <= qty_sent))
);

create type public.discrepancy_status as enum ('open', 'resolved');
create type public.discrepancy_resolution as enum ('found_delivered', 'returned_to_source', 'written_off');

create table public.transfer_discrepancies (
  id               uuid primary key default gen_random_uuid(),
  business_id      uuid not null references public.businesses(id),
  transfer_line_id uuid not null unique references public.transfer_lines(id),
  qty              int not null check (qty > 0),
  status           public.discrepancy_status not null default 'open',
  resolution       public.discrepancy_resolution,
  resolved_by      uuid references public.memberships(id),
  resolved_at      timestamptz,
  reason           text,
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Counts (blind, with intervening-movement reconciliation)
-- ---------------------------------------------------------------------------
create type public.count_status as enum ('open', 'submitted', 'approved', 'rejected');

create table public.stock_counts (
  id                uuid primary key default gen_random_uuid(),
  business_id       uuid not null references public.businesses(id),
  ref_no            text not null,
  location_id       uuid not null references public.locations(id),
  status            public.count_status not null default 'open',
  started_by        uuid not null references public.memberships(id),
  started_at        timestamptz not null default now(),
  start_movement_id bigint not null,   -- ledger watermark at start
  submitted_by      uuid references public.memberships(id),
  submitted_at      timestamptz,
  submit_movement_id bigint,           -- ledger watermark at submission
  decided_by        uuid references public.memberships(id),
  decided_at        timestamptz,
  decision_reason   text,
  unique (business_id, ref_no)
);
create table public.stock_count_lines (
  id            uuid primary key default gen_random_uuid(),
  count_id      uuid not null references public.stock_counts(id),
  variant_id    uuid not null references public.variants(id),
  snapshot_qty  int not null,           -- hidden from the counter (blind count)
  counted_qty   int check (counted_qty is null or counted_qty >= 0),
  variance      int,                    -- set at approval
  unique (count_id, variant_id)
);

-- ---------------------------------------------------------------------------
-- Internal helpers (never granted to clients)
-- ---------------------------------------------------------------------------
create or replace function public._next_ref(p_business uuid, p_prefix text) returns text
language plpgsql security definer set search_path = '' as $$
declare v bigint;
begin
  insert into public.doc_sequences (business_id, prefix) values (p_business, p_prefix)
  on conflict (business_id, prefix) do update set next_no = public.doc_sequences.next_no + 1
  returning next_no into v;
  return p_prefix || '-' || lpad(v::text, 6, '0');
end $$;

create or replace function public._idem_get(p_key uuid, p_op text, p_payload jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.idempotency_keys;
begin
  if p_key is null then raise exception 'idempotency key required' using errcode = '22023'; end if;
  -- serialize concurrent retries of the same key
  perform pg_advisory_xact_lock(hashtextextended(p_key::text, 0));
  select * into r from public.idempotency_keys where key = p_key;
  if r.key is null then return null; end if;
  if r.actor_user_id <> auth.uid() or r.operation <> p_op
     or r.payload_hash <> encode(extensions.digest(p_payload::text, 'sha256'), 'hex') then
    raise exception 'idempotency key reused with a different request' using errcode = '22023';
  end if;
  return r.result;
end $$;

create or replace function public._idem_put(p_key uuid, p_business uuid, p_op text, p_payload jsonb, p_result jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.idempotency_keys (key, business_id, actor_user_id, operation, payload_hash, result)
  values (p_key, p_business, auth.uid(), p_op, encode(extensions.digest(p_payload::text, 'sha256'), 'hex'), p_result);
  return p_result;
end $$;

create or replace function public._new_doc(p_business uuid, p_type public.stock_doc_type, p_prefix text,
                                           p_actor uuid, p_source uuid, p_reason text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  insert into public.stock_documents (business_id, doc_type, ref_no, source_id, actor_membership_id, reason)
  values (p_business, p_type, public._next_ref(p_business, p_prefix), p_source, p_actor, p_reason)
  returning id into v;
  return v;
end $$;

-- Apply one quantity change. Row lock + CHECK constraints make concurrent final-unit sales/dispatches safe.
create or replace function public._move(p_business uuid, p_doc uuid, p_variant uuid, p_location uuid, p_delta int)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_on int; v_res int;
begin
  if p_delta = 0 then return; end if;
  insert into public.stock_balances (variant_id, location_id, business_id) values (p_variant, p_location, p_business)
  on conflict do nothing;
  select on_hand, reserved into v_on, v_res from public.stock_balances
   where variant_id = p_variant and location_id = p_location for update;
  if v_on + p_delta < 0 then
    raise exception 'insufficient stock' using errcode = 'P0001', detail = format('variant %s location %s on_hand %s change %s', p_variant, p_location, v_on, p_delta);
  end if;
  if p_delta < 0 and v_on + p_delta < v_res then
    raise exception 'stock is reserved' using errcode = 'P0001';
  end if;
  update public.stock_balances set on_hand = on_hand + p_delta, updated_at = now()
   where variant_id = p_variant and location_id = p_location;
  insert into public.stock_movements (business_id, document_id, variant_id, location_id, qty_delta)
  values (p_business, p_doc, p_variant, p_location, p_delta);
end $$;

create or replace function public._reserve(p_business uuid, p_variant uuid, p_location uuid, p_delta int)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_on int; v_res int;
begin
  insert into public.stock_balances (variant_id, location_id, business_id) values (p_variant, p_location, p_business)
  on conflict do nothing;
  select on_hand, reserved into v_on, v_res from public.stock_balances
   where variant_id = p_variant and location_id = p_location for update;
  if v_res + p_delta < 0 then raise exception 'reservation underflow' using errcode = 'P0001'; end if;
  if v_res + p_delta > v_on then raise exception 'insufficient available stock to reserve' using errcode = 'P0001'; end if;
  update public.stock_balances set reserved = reserved + p_delta, updated_at = now()
   where variant_id = p_variant and location_id = p_location;
end $$;

create or replace function public._require_location(p_location uuid, p_kinds public.location_kind[] default null)
returns public.locations
language plpgsql stable security definer set search_path = '' as $$
declare l public.locations;
begin
  select * into l from public.locations where id = p_location;
  if l.id is null or not l.is_active or not public.can_access_location(p_location) then
    raise exception 'location not accessible' using errcode = '42501';
  end if;
  if p_kinds is not null and not (l.kind = any (p_kinds)) then
    raise exception 'location type % not allowed here', l.kind using errcode = '22023';
  end if;
  return l;
end $$;

create or replace function public._transit_location(p_business uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  select id into v from public.locations where business_id = p_business and kind = 'transit' and is_active order by created_at limit 1;
  if v is null then
    insert into public.locations (business_id, code, name, kind) values (p_business, 'TRANSIT', 'In transit / Njiani', 'transit')
    returning id into v;
  end if;
  return v;
end $$;

create or replace function public._check_variant(p_business uuid, p_variant uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.variants where id = p_variant and business_id = p_business) then
    raise exception 'unknown variant' using errcode = '22023';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Catalogue functions
-- ---------------------------------------------------------------------------
create or replace function public.supplier_save(p_id uuid, p_name text, p_phone text, p_country text, p_notes text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v uuid;
begin
  v_me := public.require_permission('purchasing.manage');
  if p_id is null then
    insert into public.suppliers (business_id, name, phone, country, notes)
    values (v_me.business_id, btrim(p_name), nullif(btrim(p_phone), ''), nullif(btrim(p_country), ''), nullif(btrim(p_notes), ''))
    returning id into v;
  else
    update public.suppliers set name = btrim(p_name), phone = nullif(btrim(p_phone), ''), country = nullif(btrim(p_country), ''),
           notes = nullif(btrim(p_notes), '')
     where id = p_id and business_id = v_me.business_id returning id into v;
    if v is null then raise exception 'not found' using errcode = '22023'; end if;
  end if;
  perform public.write_audit(v_me.business_id, 'supplier.save', 'supplier', v::text, null,
    jsonb_build_object('name', p_name, 'country', p_country), null);
  return v;
end $$;

create or replace function public._variant_sku(p_code text, p_color text, p_size text) returns text
language sql immutable set search_path = '' as $$
  select upper(regexp_replace(btrim(p_code), '\s+', '', 'g')) || '-' ||
         upper(regexp_replace(btrim(p_color), '[^A-Za-z0-9]+', '', 'g')) || '-' || upper(btrim(p_size))
$$;

create or replace function public._add_variant(p_business uuid, p_design uuid, p_code text, p_color text, p_size text,
                                               p_retail bigint, p_wholesale bigint, p_barcode text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  insert into public.variants (business_id, design_id, color, size, sku, barcode, retail_price, wholesale_price)
  values (p_business, p_design, btrim(p_color), upper(btrim(p_size)), public._variant_sku(p_code, p_color, p_size),
          coalesce(nullif(upper(btrim(p_barcode)), ''), 'DR' || lpad(nextval('public.barcode_seq')::text, 8, '0')),
          p_retail, p_wholesale)
  returning id into v;
  return v;
end $$;

-- Creates a design and its colour × size matrix. Prices may be NULL ("not yet priced": cannot be sold in Milestone C).
create or replace function public.design_create(p_code text, p_name text, p_category text, p_supplier uuid,
                                                p_description text, p_colors text[], p_sizes text[],
                                                p_retail bigint, p_wholesale bigint)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_design uuid; v_set text; c text; s text; n int := 0;
begin
  v_me := public.require_permission('products.manage');
  select size_set into v_set from public.categories where code = p_category;
  if v_set is null then raise exception 'unknown category' using errcode = '22023'; end if;
  if coalesce(array_length(p_colors, 1), 0) = 0 or coalesce(array_length(p_sizes, 1), 0) = 0 then
    raise exception 'at least one colour and one size required' using errcode = '22023';
  end if;
  if p_supplier is not null and not exists (select 1 from public.suppliers where id = p_supplier and business_id = v_me.business_id) then
    raise exception 'unknown supplier' using errcode = '22023';
  end if;
  insert into public.designs (business_id, code, name, category, supplier_id, description)
  values (v_me.business_id, btrim(p_code), btrim(p_name), p_category, p_supplier, nullif(btrim(p_description), ''))
  returning id into v_design;
  foreach c in array p_colors loop
    foreach s in array p_sizes loop
      if not exists (select 1 from public.size_set_sizes where size_set = v_set and size = upper(btrim(s))) then
        raise exception 'size % is not configured for this category', s using errcode = '22023';
      end if;
      perform public._add_variant(v_me.business_id, v_design, p_code, c, s, p_retail, p_wholesale, null);
      n := n + 1;
    end loop;
  end loop;
  perform public.write_audit(v_me.business_id, 'design.create', 'design', v_design::text, null,
    jsonb_build_object('code', p_code, 'name', p_name, 'variants', n, 'retail', p_retail, 'wholesale', p_wholesale), null);
  return v_design;
end $$;

create or replace function public.variant_add(p_design uuid, p_color text, p_size text, p_retail bigint, p_wholesale bigint)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; d public.designs; v_set text; v uuid;
begin
  v_me := public.require_permission('products.manage');
  select * into d from public.designs where id = p_design and business_id = v_me.business_id;
  if d.id is null then raise exception 'not found' using errcode = '22023'; end if;
  select size_set into v_set from public.categories where code = d.category;
  if not exists (select 1 from public.size_set_sizes where size_set = v_set and size = upper(btrim(p_size))) then
    raise exception 'size % is not configured for this category', p_size using errcode = '22023';
  end if;
  v := public._add_variant(v_me.business_id, d.id, d.code, p_color, p_size, p_retail, p_wholesale, null);
  perform public.write_audit(v_me.business_id, 'variant.add', 'variant', v::text, null,
    jsonb_build_object('color', p_color, 'size', p_size), null);
  return v;
end $$;

create or replace function public.variant_set_prices(p_variant uuid, p_retail bigint, p_wholesale bigint, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v public.variants;
begin
  v_me := public.require_permission('products.manage');
  select * into v from public.variants where id = p_variant and business_id = v_me.business_id for update;
  if v.id is null then raise exception 'not found' using errcode = '22023'; end if;
  update public.variants set retail_price = p_retail, wholesale_price = p_wholesale where id = v.id;
  perform public.write_audit(v_me.business_id, 'variant.prices', 'variant', v.id::text,
    jsonb_build_object('retail', v.retail_price, 'wholesale', v.wholesale_price),
    jsonb_build_object('retail', p_retail, 'wholesale', p_wholesale), p_reason);
end $$;

-- ---------------------------------------------------------------------------
-- Opening stock (controlled document, Owner)
-- ---------------------------------------------------------------------------
create or replace function public.opening_stock_post(p_idem uuid, p_location uuid, p_lines jsonb, p_reason text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_prev jsonb; v_doc uuid; r record; v_payload jsonb; n int := 0;
begin
  v_me := public.require_permission('stock.opening');
  v_payload := jsonb_build_object('location', p_location, 'lines', p_lines, 'reason', p_reason);
  v_prev := public._idem_get(p_idem, 'opening_stock_post', v_payload);
  if v_prev is not null then return v_prev; end if;
  if coalesce(btrim(p_reason), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  perform public._require_location(p_location, array['warehouse','shop']::public.location_kind[]);
  v_doc := public._new_doc(v_me.business_id, 'opening', 'OPN', v_me.id, null, p_reason);
  for r in select * from jsonb_to_recordset(p_lines) as x(variant_id uuid, qty int) loop
    if r.qty is null or r.qty <= 0 then raise exception 'quantity must be positive' using errcode = '22023'; end if;
    perform public._check_variant(v_me.business_id, r.variant_id);
    perform public._move(v_me.business_id, v_doc, r.variant_id, p_location, r.qty);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'no lines' using errcode = '22023'; end if;
  perform public.write_audit(v_me.business_id, 'stock.opening', 'stock_document', v_doc::text, null,
    jsonb_build_object('location', p_location, 'lines', n), p_reason);
  return public._idem_put(p_idem, v_me.business_id, 'opening_stock_post', v_payload,
    jsonb_build_object('document_id', v_doc, 'lines', n));
end $$;

-- ---------------------------------------------------------------------------
-- Purchase orders
-- ---------------------------------------------------------------------------
create or replace function public.po_create(p_idem uuid, p_supplier uuid, p_currency text, p_fx_rate numeric,
                                            p_expected date, p_lines jsonb, p_notes text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_prev jsonb; v_payload jsonb; v_po uuid; v_ref text; r record; n int := 0;
begin
  v_me := public.require_permission('purchasing.manage');
  v_payload := jsonb_build_object('supplier', p_supplier, 'currency', p_currency, 'fx', p_fx_rate, 'expected', p_expected, 'lines', p_lines, 'notes', p_notes);
  v_prev := public._idem_get(p_idem, 'po_create', v_payload);
  if v_prev is not null then return v_prev; end if;
  if not exists (select 1 from public.suppliers where id = p_supplier and business_id = v_me.business_id) then
    raise exception 'unknown supplier' using errcode = '22023';
  end if;
  v_ref := public._next_ref(v_me.business_id, 'PO');
  insert into public.purchase_orders (business_id, ref_no, supplier_id, currency, fx_rate, expected_at, notes, created_by)
  values (v_me.business_id, v_ref, p_supplier, upper(coalesce(p_currency, 'TZS')), coalesce(p_fx_rate, 1), p_expected, p_notes, v_me.id)
  returning id into v_po;
  for r in select * from jsonb_to_recordset(p_lines) as x(variant_id uuid, qty int, unit_price_fx numeric) loop
    perform public._check_variant(v_me.business_id, r.variant_id);
    insert into public.purchase_order_lines (po_id, variant_id, qty_ordered, unit_price_fx)
    values (v_po, r.variant_id, r.qty, r.unit_price_fx);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'no lines' using errcode = '22023'; end if;
  perform public.write_audit(v_me.business_id, 'po.create', 'purchase_order', v_po::text, null,
    jsonb_build_object('ref', v_ref, 'lines', n), null);
  return public._idem_put(p_idem, v_me.business_id, 'po_create', v_payload, jsonb_build_object('po_id', v_po, 'ref_no', v_ref));
end $$;

-- Quantities a Storekeeper may see for an open PO (no prices).
create or replace function public.po_expected_lines(p_po uuid)
returns table (line_id uuid, variant_id uuid, design_code text, design_name text, color text, size text,
               qty_ordered int, qty_received int)
language plpgsql stable security definer set search_path = '' as $$
declare v_me public.memberships;
begin
  if not (public.has_permission('store.operate') or public.has_permission('purchasing.manage')) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  v_me := public.current_membership();
  return query
    select l.id, l.variant_id, d.code, d.name, v.color, v.size, l.qty_ordered, l.qty_received
    from public.purchase_order_lines l
    join public.purchase_orders po on po.id = l.po_id and po.business_id = v_me.business_id
    join public.variants v on v.id = l.variant_id
    join public.designs d on d.id = v.design_id
    where l.po_id = p_po
    order by d.code, v.color, v.size;
end $$;

create or replace function public.po_open_list()
returns table (po_id uuid, ref_no text, supplier text, status public.po_status, expected_at date, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare v_me public.memberships;
begin
  if not (public.has_permission('store.operate') or public.has_permission('purchasing.manage')) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  v_me := public.current_membership();
  return query
    select po.id, po.ref_no, s.name, po.status, po.expected_at, po.created_at
    from public.purchase_orders po join public.suppliers s on s.id = po.supplier_id
    where po.business_id = v_me.business_id and po.status in ('ordered','partially_received')
    order by po.created_at;
end $$;

-- ---------------------------------------------------------------------------
-- Physical receipt (quantities only; cost approval is separate)
-- ---------------------------------------------------------------------------
create or replace function public.goods_receive(p_idem uuid, p_location uuid, p_supplier uuid, p_po uuid,
                                                p_supplier_ref text, p_lines jsonb, p_notes text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_prev jsonb; v_payload jsonb; v_doc uuid; v_gr uuid; v_ref text; r record;
        n int := 0; v_pol public.purchase_order_lines; v_supplier uuid := p_supplier;
begin
  v_me := public.require_permission('store.operate');
  v_payload := jsonb_build_object('location', p_location, 'supplier', p_supplier, 'po', p_po, 'ref', p_supplier_ref, 'lines', p_lines, 'notes', p_notes);
  v_prev := public._idem_get(p_idem, 'goods_receive', v_payload);
  if v_prev is not null then return v_prev; end if;
  perform public._require_location(p_location, array['warehouse','shop']::public.location_kind[]);
  if p_po is not null then
    select supplier_id into v_supplier from public.purchase_orders
     where id = p_po and business_id = v_me.business_id and status in ('ordered','partially_received') for update;
    if v_supplier is null then raise exception 'purchase order not open' using errcode = '22023'; end if;
  end if;
  v_ref := public._next_ref(v_me.business_id, 'GRN');
  v_doc := public._new_doc(v_me.business_id, 'goods_receipt', 'DOC', v_me.id, null, p_notes);
  insert into public.goods_receipts (business_id, ref_no, location_id, supplier_id, po_id, supplier_ref, received_by, notes, document_id)
  values (v_me.business_id, v_ref, p_location, v_supplier, p_po, nullif(btrim(p_supplier_ref), ''), v_me.id, p_notes, v_doc)
  returning id into v_gr;
  update public.stock_documents set source_id = v_gr where id = v_doc;

  for r in select * from jsonb_to_recordset(p_lines) as x(variant_id uuid, qty_expected int, qty_received int) loop
    perform public._check_variant(v_me.business_id, r.variant_id);
    if r.qty_received is null or r.qty_received < 0 then raise exception 'invalid quantity' using errcode = '22023'; end if;
    insert into public.goods_receipt_lines (receipt_id, variant_id, qty_expected, qty_received)
    values (v_gr, r.variant_id, r.qty_expected, r.qty_received);
    perform public._move(v_me.business_id, v_doc, r.variant_id, p_location, r.qty_received);
    if p_po is not null then
      select * into v_pol from public.purchase_order_lines where po_id = p_po and variant_id = r.variant_id for update;
      if v_pol.id is null then raise exception 'variant not on this purchase order' using errcode = '22023'; end if;
      if v_pol.qty_received + r.qty_received > v_pol.qty_ordered then
        raise exception 'receiving more than ordered' using errcode = '22023';
      end if;
      update public.purchase_order_lines set qty_received = qty_received + r.qty_received where id = v_pol.id;
    end if;
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'no lines' using errcode = '22023'; end if;
  if p_po is not null then
    update public.purchase_orders po set status = case
        when not exists (select 1 from public.purchase_order_lines l where l.po_id = po.id and l.qty_received < l.qty_ordered)
        then 'received'::public.po_status else 'partially_received'::public.po_status end
     where po.id = p_po;
  end if;
  perform public.write_audit(v_me.business_id, 'stock.receive', 'goods_receipt', v_gr::text, null,
    jsonb_build_object('ref', v_ref, 'lines', n, 'po', p_po), null);
  return public._idem_put(p_idem, v_me.business_id, 'goods_receive', v_payload,
    jsonb_build_object('receipt_id', v_gr, 'ref_no', v_ref));
end $$;

-- Owner approves supplier costs and allocates landed costs (freight, duty, clearing...).
-- Allocation: by line value or by quantity, largest-remainder rounding so the TZS total is exact.
-- Interim costing: variant_costs keeps a cumulative purchase-weighted average of landed unit cost;
-- perpetual average against COGS is introduced with sales in Milestone C.
create or replace function public.receipt_approve_costs(p_receipt uuid, p_lines jsonb, p_extras jsonb, p_allocation text, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; g public.goods_receipts; v_extra bigint; v_base numeric; r record;
        v_missing int; v_allocated bigint := 0;
begin
  v_me := public.require_permission('costs.approve');
  if p_allocation not in ('value','qty') then raise exception 'allocation must be value or qty' using errcode = '22023'; end if;
  select * into g from public.goods_receipts where id = p_receipt and business_id = v_me.business_id for update;
  if g.id is null then raise exception 'not found' using errcode = '22023'; end if;
  if g.cost_status = 'approved' then raise exception 'costs already approved (use a correction document)' using errcode = '22023'; end if;

  drop table if exists pg_temp._c;
  create temp table _c (line_id uuid primary key, variant_id uuid, qty int, unit_cost bigint, share numeric, alloc bigint default 0)
    on commit drop;
  insert into pg_temp._c (line_id, variant_id, qty, unit_cost)
  select l.id, l.variant_id, l.qty_received, x.unit_cost
  from public.goods_receipt_lines l
  join jsonb_to_recordset(p_lines) as x(line_id uuid, unit_cost bigint) on x.line_id = l.id
  where l.receipt_id = g.id;
  select count(*) into v_missing from public.goods_receipt_lines l
   where l.receipt_id = g.id and l.qty_received > 0 and not exists (select 1 from pg_temp._c where pg_temp._c.line_id = l.id and pg_temp._c.unit_cost is not null);
  if v_missing > 0 then raise exception 'every received line needs a unit cost' using errcode = '22023'; end if;
  if exists (select 1 from pg_temp._c where unit_cost < 0) then raise exception 'negative cost' using errcode = '22023'; end if;

  insert into public.goods_receipt_extra_costs (receipt_id, label, amount, allocation)
  select g.id, x.label, x.amount, p_allocation from jsonb_to_recordset(coalesce(p_extras, '[]')) as x(label text, amount bigint)
  where x.amount > 0;
  select coalesce(sum(amount), 0) into v_extra from public.goods_receipt_extra_costs where receipt_id = g.id;

  select sum(case when p_allocation = 'value' then qty::numeric * unit_cost else qty end) into v_base from pg_temp._c;
  if v_extra > 0 and coalesce(v_base, 0) = 0 then raise exception 'cannot allocate extra costs onto zero base' using errcode = '22023'; end if;
  if v_extra > 0 then
    update pg_temp._c set share = v_extra * (case when p_allocation = 'value' then qty::numeric * unit_cost else qty end) / v_base;
    update pg_temp._c set alloc = floor(share);
    select sum(alloc) into v_allocated from pg_temp._c;
    -- largest remainder: hand out the leftover shillings one by one
    update pg_temp._c set alloc = alloc + 1 where line_id in (
      select line_id from pg_temp._c order by (share - floor(share)) desc, line_id limit (v_extra - v_allocated));
  end if;

  insert into public.goods_receipt_costs (receipt_line_id, unit_cost, landed_alloc, unit_landed_cost)
  select line_id, unit_cost, alloc, case when qty > 0 then round((qty::numeric * unit_cost + alloc) / qty)::bigint else unit_cost end
  from pg_temp._c;

  for r in select variant_id, sum(qty) qty, sum(qty::bigint * unit_cost + alloc) total from pg_temp._c where qty > 0 group by variant_id loop
    insert into public.variant_costs (variant_id, costed_qty, total_cost, last_unit_cost)
    values (r.variant_id, r.qty, r.total, round(r.total::numeric / r.qty)::bigint)
    on conflict (variant_id) do update set costed_qty = public.variant_costs.costed_qty + excluded.costed_qty,
      total_cost = public.variant_costs.total_cost + excluded.total_cost, last_unit_cost = excluded.last_unit_cost, updated_at = now();
  end loop;

  update public.goods_receipts set cost_status = 'approved', cost_approved_by = v_me.id, cost_approved_at = now() where id = g.id;
  perform public.write_audit(v_me.business_id, 'costs.approve', 'goods_receipt', g.id::text, null,
    jsonb_build_object('extra_costs', v_extra, 'allocation', p_allocation), p_reason);
end $$;

-- ---------------------------------------------------------------------------
-- Requisitions (shop asks the Store)
-- ---------------------------------------------------------------------------
create or replace function public.requisition_create(p_idem uuid, p_from uuid, p_to uuid, p_lines jsonb, p_notes text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_prev jsonb; v_payload jsonb; v_req uuid; v_ref text; r record; n int := 0; v_from public.locations;
begin
  v_me := public.require_permission('stock.request');
  v_payload := jsonb_build_object('from', p_from, 'to', p_to, 'lines', p_lines, 'notes', p_notes);
  v_prev := public._idem_get(p_idem, 'requisition_create', v_payload);
  if v_prev is not null then return v_prev; end if;
  perform public._require_location(p_to, array['shop','warehouse']::public.location_kind[]);
  select * into v_from from public.locations where id = p_from and business_id = v_me.business_id and is_active
    and kind in ('warehouse','shop');
  if v_from.id is null then raise exception 'unknown source location' using errcode = '22023'; end if;
  v_ref := public._next_ref(v_me.business_id, 'REQ');
  insert into public.requisitions (business_id, ref_no, from_location, to_location, requested_by, notes)
  values (v_me.business_id, v_ref, p_from, p_to, v_me.id, p_notes) returning id into v_req;
  for r in select * from jsonb_to_recordset(p_lines) as x(variant_id uuid, qty int) loop
    perform public._check_variant(v_me.business_id, r.variant_id);
    if r.qty is null or r.qty <= 0 then raise exception 'quantity must be positive' using errcode = '22023'; end if;
    insert into public.requisition_lines (requisition_id, variant_id, qty_requested) values (v_req, r.variant_id, r.qty);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'no lines' using errcode = '22023'; end if;
  perform public.write_audit(v_me.business_id, 'requisition.create', 'requisition', v_req::text, null,
    jsonb_build_object('ref', v_ref, 'lines', n), null);
  return public._idem_put(p_idem, v_me.business_id, 'requisition_create', v_payload, jsonb_build_object('requisition_id', v_req, 'ref_no', v_ref));
end $$;

-- Approve (reserving stock at the source) or reject. Requester cannot approve their own request.
create or replace function public.requisition_decide(p_req uuid, p_approve boolean, p_lines jsonb, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; q public.requisitions; r record;
begin
  v_me := public.require_permission('stock.approve');
  select * into q from public.requisitions where id = p_req and business_id = v_me.business_id for update;
  if q.id is null then raise exception 'not found' using errcode = '22023'; end if;
  if q.status <> 'submitted' then raise exception 'requisition already decided' using errcode = '22023'; end if;
  if q.requested_by = v_me.id then raise exception 'cannot approve your own request' using errcode = '42501'; end if;
  if not p_approve then
    if coalesce(btrim(p_note), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
    update public.requisitions set status = 'rejected', decided_by = v_me.id, decided_at = now(), decision_note = p_note where id = q.id;
  else
    for r in select l.id, l.variant_id, l.qty_requested, coalesce(x.qty_approved, l.qty_requested) qty_approved
             from public.requisition_lines l
             left join jsonb_to_recordset(coalesce(p_lines, '[]')) as x(line_id uuid, qty_approved int) on x.line_id = l.id
             where l.requisition_id = q.id loop
      if r.qty_approved < 0 or r.qty_approved > r.qty_requested then raise exception 'approved quantity out of range' using errcode = '22023'; end if;
      update public.requisition_lines set qty_approved = r.qty_approved where id = r.id;
      if r.qty_approved > 0 then perform public._reserve(v_me.business_id, r.variant_id, q.from_location, r.qty_approved); end if;
    end loop;
    update public.requisitions set status = 'approved', decided_by = v_me.id, decided_at = now(), decision_note = p_note where id = q.id;
  end if;
  perform public.write_audit(v_me.business_id, case when p_approve then 'requisition.approve' else 'requisition.reject' end,
    'requisition', q.id::text, null, coalesce(p_lines, '[]'::jsonb), p_note);
end $$;

-- ---------------------------------------------------------------------------
-- Dispatch and receipt
-- ---------------------------------------------------------------------------
-- Dispatch against an approved requisition (Storekeeper), or ad-hoc (needs stock.approve).
-- Moves stock source -> TRANSIT exactly once; releases matching reservations.
create or replace function public.transfer_dispatch(p_idem uuid, p_requisition uuid, p_from uuid, p_to uuid, p_lines jsonb, p_notes text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_prev jsonb; v_payload jsonb; q public.requisitions; v_tr uuid; v_ref text; v_doc uuid;
        v_transit uuid; r record; n int := 0; rl public.requisition_lines; v_from uuid := p_from; v_to uuid := p_to;
begin
  v_me := public.require_permission('store.operate');
  v_payload := jsonb_build_object('requisition', p_requisition, 'from', p_from, 'to', p_to, 'lines', p_lines, 'notes', p_notes);
  v_prev := public._idem_get(p_idem, 'transfer_dispatch', v_payload);
  if v_prev is not null then return v_prev; end if;

  if p_requisition is not null then
    select * into q from public.requisitions where id = p_requisition and business_id = v_me.business_id for update;
    if q.id is null or q.status not in ('approved','partially_dispatched') then
      raise exception 'requisition is not approved for dispatch' using errcode = '22023';
    end if;
    v_from := q.from_location; v_to := q.to_location;
  else
    if not public.has_permission('stock.approve') then
      raise exception 'ad-hoc transfers need stock.approve' using errcode = '42501';
    end if;
  end if;
  perform public._require_location(v_from, array['warehouse','shop']::public.location_kind[]);
  if not exists (select 1 from public.locations where id = v_to and business_id = v_me.business_id and is_active
                 and kind in ('warehouse','shop','partner')) or v_to = v_from then
    raise exception 'invalid destination' using errcode = '22023';
  end if;

  v_transit := public._transit_location(v_me.business_id);
  v_ref := public._next_ref(v_me.business_id, 'TRF');
  v_doc := public._new_doc(v_me.business_id, 'transfer_dispatch', 'DOC', v_me.id, null, p_notes);
  insert into public.transfers (business_id, ref_no, requisition_id, from_location, to_location, transit_location, dispatched_by, notes, dispatch_doc)
  values (v_me.business_id, v_ref, p_requisition, v_from, v_to, v_transit, v_me.id, p_notes, v_doc) returning id into v_tr;
  update public.stock_documents set source_id = v_tr where id = v_doc;

  for r in select * from jsonb_to_recordset(p_lines) as x(variant_id uuid, qty int, requisition_line_id uuid) loop
    if r.qty is null or r.qty <= 0 then raise exception 'quantity must be positive' using errcode = '22023'; end if;
    perform public._check_variant(v_me.business_id, r.variant_id);
    if p_requisition is not null then
      select * into rl from public.requisition_lines where id = r.requisition_line_id and requisition_id = p_requisition for update;
      if rl.id is null or rl.variant_id <> r.variant_id then raise exception 'line not on requisition' using errcode = '22023'; end if;
      if rl.qty_dispatched + r.qty > rl.qty_approved then raise exception 'dispatch exceeds approved quantity' using errcode = '22023'; end if;
      update public.requisition_lines set qty_dispatched = qty_dispatched + r.qty where id = rl.id;
      perform public._reserve(v_me.business_id, r.variant_id, v_from, -r.qty);
    end if;
    insert into public.transfer_lines (transfer_id, variant_id, requisition_line_id, qty_sent) values (v_tr, r.variant_id, r.requisition_line_id, r.qty);
    perform public._move(v_me.business_id, v_doc, r.variant_id, v_from, -r.qty);
    perform public._move(v_me.business_id, v_doc, r.variant_id, v_transit, r.qty);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'no lines' using errcode = '22023'; end if;

  if p_requisition is not null then
    update public.requisitions set status = case
        when exists (select 1 from public.requisition_lines where requisition_id = p_requisition and qty_dispatched < qty_approved)
        then 'partially_dispatched'::public.requisition_status else 'dispatched'::public.requisition_status end
     where id = p_requisition;
  end if;
  perform public.write_audit(v_me.business_id, 'transfer.dispatch', 'transfer', v_tr::text, null,
    jsonb_build_object('ref', v_ref, 'from', v_from, 'to', v_to, 'lines', n), null);
  return public._idem_put(p_idem, v_me.business_id, 'transfer_dispatch', v_payload, jsonb_build_object('transfer_id', v_tr, 'ref_no', v_ref));
end $$;

-- Receiver confirms actual quantities. Shortages stay in TRANSIT as open discrepancies.
-- Default custody rule: receiver must differ from dispatcher; only the Owner may override, with a reason.
create or replace function public.transfer_receive(p_idem uuid, p_transfer uuid, p_lines jsonb, p_override_reason text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_prev jsonb; v_payload jsonb; t public.transfers; v_doc uuid; r record; v_short int := 0;
begin
  v_me := public.require_permission('stock.confirm_receipt');
  v_payload := jsonb_build_object('transfer', p_transfer, 'lines', p_lines, 'override', p_override_reason);
  v_prev := public._idem_get(p_idem, 'transfer_receive', v_payload);
  if v_prev is not null then return v_prev; end if;
  select * into t from public.transfers where id = p_transfer and business_id = v_me.business_id for update;
  if t.id is null then raise exception 'not found' using errcode = '22023'; end if;
  if t.status <> 'in_transit' then raise exception 'transfer already received' using errcode = '22023'; end if;
  if (select kind from public.locations where id = t.to_location) <> 'partner' then
    perform public._require_location(t.to_location);
  end if;
  if t.dispatched_by = v_me.id then
    if v_me.role <> 'owner' or coalesce(btrim(p_override_reason), '') = '' then
      raise exception 'receiver must be a different person from the dispatcher' using errcode = '42501';
    end if;
  end if;
  v_doc := public._new_doc(v_me.business_id, 'transfer_receipt', 'DOC', v_me.id, t.id, p_override_reason);

  for r in select l.id, l.variant_id, l.qty_sent, x.qty_received
           from public.transfer_lines l
           left join jsonb_to_recordset(p_lines) as x(line_id uuid, qty_received int) on x.line_id = l.id
           where l.transfer_id = t.id for update of l loop
    if r.qty_received is null then raise exception 'every line needs a received quantity' using errcode = '22023'; end if;
    if r.qty_received < 0 or r.qty_received > r.qty_sent then raise exception 'received quantity out of range' using errcode = '22023'; end if;
    update public.transfer_lines set qty_received = r.qty_received where id = r.id;
    if r.qty_received > 0 then
      perform public._move(v_me.business_id, v_doc, r.variant_id, t.transit_location, -r.qty_received);
      perform public._move(v_me.business_id, v_doc, r.variant_id, t.to_location, r.qty_received);
    end if;
    if r.qty_received < r.qty_sent then
      insert into public.transfer_discrepancies (business_id, transfer_line_id, qty) values (v_me.business_id, r.id, r.qty_sent - r.qty_received);
      v_short := v_short + (r.qty_sent - r.qty_received);
    end if;
  end loop;

  update public.transfers set status = case when v_short > 0 then 'received_with_discrepancy'::public.transfer_status else 'received'::public.transfer_status end,
         received_by = v_me.id, received_at = now(), receipt_override_reason = nullif(btrim(p_override_reason), ''), receipt_doc = v_doc
   where id = t.id;
  perform public.write_audit(v_me.business_id, 'transfer.receive', 'transfer', t.id::text, null,
    jsonb_build_object('shortage', v_short), p_override_reason);
  return public._idem_put(p_idem, v_me.business_id, 'transfer_receive', v_payload, jsonb_build_object('transfer_id', t.id, 'shortage', v_short));
end $$;

-- Manager/Owner resolves a shortage that is still sitting in TRANSIT.
create or replace function public.discrepancy_resolve(p_discrepancy uuid, p_resolution public.discrepancy_resolution, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; d public.transfer_discrepancies; l public.transfer_lines; t public.transfers; v_doc uuid;
begin
  v_me := public.require_permission('stock.approve');
  if coalesce(btrim(p_reason), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  select * into d from public.transfer_discrepancies where id = p_discrepancy and business_id = v_me.business_id for update;
  if d.id is null or d.status <> 'open' then raise exception 'discrepancy not open' using errcode = '22023'; end if;
  select * into l from public.transfer_lines where id = d.transfer_line_id;
  select * into t from public.transfers where id = l.transfer_id;
  if v_me.id in (t.dispatched_by, t.received_by) then
    raise exception 'resolver must be independent of dispatcher and receiver' using errcode = '42501';
  end if;
  v_doc := public._new_doc(v_me.business_id, 'discrepancy_resolution', 'DOC', v_me.id, d.id, p_reason);
  perform public._move(v_me.business_id, v_doc, l.variant_id, t.transit_location, -d.qty);
  if p_resolution = 'found_delivered' then
    perform public._move(v_me.business_id, v_doc, l.variant_id, t.to_location, d.qty);
  elsif p_resolution = 'returned_to_source' then
    perform public._move(v_me.business_id, v_doc, l.variant_id, t.from_location, d.qty);
  end if; -- written_off: leaves company stock (loss), financial treatment in Milestone C
  update public.transfer_discrepancies set status = 'resolved', resolution = p_resolution, resolved_by = v_me.id, resolved_at = now(), reason = p_reason
   where id = d.id;
  perform public.write_audit(v_me.business_id, 'discrepancy.resolve', 'transfer_discrepancy', d.id::text, null,
    jsonb_build_object('resolution', p_resolution, 'qty', d.qty), p_reason);
end $$;

-- ---------------------------------------------------------------------------
-- Blind stock counts
-- ---------------------------------------------------------------------------
create or replace function public.count_start(p_location uuid, p_variants uuid[])
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_count uuid; v_mark bigint;
begin
  v_me := public.require_permission('store.operate');
  perform public._require_location(p_location, array['warehouse','shop']::public.location_kind[]);
  -- Lock the location's balances briefly so the watermark and snapshot are consistent.
  perform 1 from public.stock_balances where location_id = p_location for share;
  select coalesce(max(id), 0) into v_mark from public.stock_movements;
  insert into public.stock_counts (business_id, ref_no, location_id, started_by, start_movement_id)
  values (v_me.business_id, public._next_ref(v_me.business_id, 'CNT'), p_location, v_me.id, v_mark) returning id into v_count;
  insert into public.stock_count_lines (count_id, variant_id, snapshot_qty)
  select v_count, v.id, coalesce(b.on_hand, 0)
  from public.variants v
  left join public.stock_balances b on b.variant_id = v.id and b.location_id = p_location
  where v.business_id = v_me.business_id
    and (p_variants is null and coalesce(b.on_hand, 0) > 0 or v.id = any (p_variants));
  perform public.write_audit(v_me.business_id, 'count.start', 'stock_count', v_count::text, null, null, null);
  return v_count;
end $$;

-- The counter's sheet: never exposes system quantities.
create or replace function public.count_sheet(p_count uuid)
returns table (line_id uuid, variant_id uuid, design_code text, design_name text, color text, size text, barcode text, counted_qty int)
language plpgsql stable security definer set search_path = '' as $$
declare v_me public.memberships; c public.stock_counts;
begin
  v_me := public.require_permission('store.operate');
  select * into c from public.stock_counts where id = p_count and business_id = v_me.business_id;
  if c.id is null then raise exception 'not found' using errcode = '22023'; end if;
  perform public._require_location(c.location_id);
  return query select l.id, v.id, d.code, d.name, v.color, v.size, v.barcode, l.counted_qty
    from public.stock_count_lines l join public.variants v on v.id = l.variant_id join public.designs d on d.id = v.design_id
    where l.count_id = c.id order by d.code, v.color, v.size;
end $$;

create or replace function public.count_submit(p_count uuid, p_lines jsonb)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; c public.stock_counts;
begin
  v_me := public.require_permission('store.operate');
  select * into c from public.stock_counts where id = p_count and business_id = v_me.business_id for update;
  if c.id is null or c.status <> 'open' then raise exception 'count not open' using errcode = '22023'; end if;
  perform public._require_location(c.location_id);
  update public.stock_count_lines l set counted_qty = x.counted_qty
  from jsonb_to_recordset(p_lines) as x(line_id uuid, counted_qty int)
  where l.id = x.line_id and l.count_id = c.id;
  if exists (select 1 from public.stock_count_lines where count_id = c.id and (counted_qty is null or counted_qty < 0)) then
    raise exception 'every line needs a counted quantity' using errcode = '22023';
  end if;
  update public.stock_counts set status = 'submitted', submitted_by = v_me.id, submitted_at = now(),
         submit_movement_id = (select coalesce(max(id), 0) from public.stock_movements)
   where id = c.id;
  perform public.write_audit(v_me.business_id, 'count.submit', 'stock_count', c.id::text, null, null, null);
end $$;

-- Independent approval. Variance = counted − (snapshot + movements between start and submission).
-- The adjustment is applied to the CURRENT balance, so movements after submission are preserved.
create or replace function public.count_decide(p_count uuid, p_approve boolean, p_reason text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; c public.stock_counts; v_doc uuid; r record; v_total int := 0;
begin
  v_me := public.require_permission('stock.approve');
  if coalesce(btrim(p_reason), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  select * into c from public.stock_counts where id = p_count and business_id = v_me.business_id for update;
  if c.id is null or c.status <> 'submitted' then raise exception 'count not awaiting approval' using errcode = '22023'; end if;
  if v_me.id in (c.started_by, c.submitted_by) then raise exception 'approver must be independent of the counter' using errcode = '42501'; end if;
  if not p_approve then
    update public.stock_counts set status = 'rejected', decided_by = v_me.id, decided_at = now(), decision_reason = p_reason where id = c.id;
    perform public.write_audit(v_me.business_id, 'count.reject', 'stock_count', c.id::text, null, null, p_reason);
    return jsonb_build_object('status', 'rejected');
  end if;
  v_doc := public._new_doc(v_me.business_id, 'count_adjustment', 'DOC', v_me.id, c.id, p_reason);
  for r in
    select l.id, l.variant_id,
           (l.counted_qty - (l.snapshot_qty + coalesce((select sum(m.qty_delta) from public.stock_movements m
                     where m.variant_id = l.variant_id and m.location_id = c.location_id
                       and m.id > c.start_movement_id and m.id <= c.submit_movement_id), 0)))::int as variance
    from public.stock_count_lines l where l.count_id = c.id
  loop
    update public.stock_count_lines set variance = r.variance where id = r.id;
    if r.variance <> 0 then
      perform public._move(v_me.business_id, v_doc, r.variant_id, c.location_id, r.variance);
      v_total := v_total + abs(r.variance);
    end if;
  end loop;
  update public.stock_counts set status = 'approved', decided_by = v_me.id, decided_at = now(), decision_reason = p_reason where id = c.id;
  perform public.write_audit(v_me.business_id, 'count.approve', 'stock_count', c.id::text, null,
    jsonb_build_object('abs_variance', v_total), p_reason);
  return jsonb_build_object('status', 'approved', 'abs_variance', v_total);
end $$;

-- ---------------------------------------------------------------------------
-- Read models
-- ---------------------------------------------------------------------------
create view public.v_stock with (security_invoker = true) as
select b.variant_id, b.location_id, b.business_id, b.on_hand, b.reserved,
       case when l.kind in ('warehouse','shop') then b.on_hand - b.reserved else 0 end as available,
       l.kind as location_kind, v.design_id, v.color, v.size, v.sku, v.barcode, d.code as design_code, d.name as design_name, d.category
from public.stock_balances b
join public.locations l on l.id = b.location_id
join public.variants v on v.id = b.variant_id
join public.designs d on d.id = v.design_id;

create view public.v_catalogue with (security_invoker = true) as
select d.id as design_id, d.business_id, d.code, d.name, d.category, d.supplier_id, d.is_active,
       count(v.id) as variant_count,
       min(v.retail_price) as retail_from, max(v.retail_price) as retail_to,
       count(*) filter (where v.retail_price is null) as unpriced_variants,
       array_agg(distinct v.color) as colors
from public.designs d left join public.variants v on v.design_id = d.id and v.is_active
group by d.id;

create or replace function public.store_overview(p_location uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_me public.memberships; l public.locations;
begin
  if not (public.has_permission('store.operate') or public.has_permission('shop_stock.view')) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  v_me := public.current_membership();
  l := public._require_location(p_location);
  return jsonb_build_object(
    'location', jsonb_build_object('id', l.id, 'name', l.name, 'kind', l.kind),
    'on_hand',   (select coalesce(sum(on_hand), 0) from public.stock_balances where location_id = l.id),
    'reserved',  (select coalesce(sum(reserved), 0) from public.stock_balances where location_id = l.id),
    'available', (select coalesce(sum(on_hand - reserved), 0) from public.stock_balances where location_id = l.id),
    'in_transit_out', (select coalesce(sum(tl.qty_sent), 0) from public.transfers t join public.transfer_lines tl on tl.transfer_id = t.id
                        where t.from_location = l.id and t.status = 'in_transit'),
    'incoming_unconfirmed', (select count(*) from public.transfers where to_location = l.id and status = 'in_transit'),
    'pending_requisitions', (select count(*) from public.requisitions where from_location = l.id and status in ('submitted','approved','partially_dispatched')),
    'open_discrepancies', (select count(*) from public.transfer_discrepancies d join public.transfer_lines tl on tl.id = d.transfer_line_id
                            join public.transfers t on t.id = tl.transfer_id
                            where d.status = 'open' and l.id in (t.from_location, t.to_location)),
    'open_counts', (select count(*) from public.stock_counts where location_id = l.id and status in ('open','submitted')),
    'pending_cost_receipts', (select count(*) from public.goods_receipts where location_id = l.id and cost_status = 'pending'),
    'company', jsonb_build_object(
       'warehouse', (select coalesce(sum(b.on_hand), 0) from public.stock_balances b join public.locations x on x.id = b.location_id
                     where x.business_id = v_me.business_id and x.kind = 'warehouse'),
       'shop', (select coalesce(sum(b.on_hand), 0) from public.stock_balances b join public.locations x on x.id = b.location_id
                where x.business_id = v_me.business_id and x.kind = 'shop'),
       'transit', (select coalesce(sum(b.on_hand), 0) from public.stock_balances b join public.locations x on x.id = b.location_id
                   where x.business_id = v_me.business_id and x.kind = 'transit'),
       'inspection_quarantine', (select coalesce(sum(b.on_hand), 0) from public.stock_balances b join public.locations x on x.id = b.location_id
                   where x.business_id = v_me.business_id and x.kind in ('inspection','quarantine')))
  );
end $$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.size_sets enable row level security;
alter table public.size_set_sizes enable row level security;
alter table public.categories enable row level security;
alter table public.suppliers enable row level security;
alter table public.designs enable row level security;
alter table public.variants enable row level security;
alter table public.variant_costs enable row level security;
alter table public.stock_documents enable row level security;
alter table public.stock_movements enable row level security;
alter table public.stock_balances enable row level security;
alter table public.doc_sequences enable row level security;
alter table public.idempotency_keys enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_lines enable row level security;
alter table public.goods_receipts enable row level security;
alter table public.goods_receipt_lines enable row level security;
alter table public.goods_receipt_costs enable row level security;
alter table public.goods_receipt_extra_costs enable row level security;
alter table public.requisitions enable row level security;
alter table public.requisition_lines enable row level security;
alter table public.transfers enable row level security;
alter table public.transfer_lines enable row level security;
alter table public.transfer_discrepancies enable row level security;
alter table public.stock_counts enable row level security;
alter table public.stock_count_lines enable row level security;

create policy ref_read_size_sets on public.size_sets for select to authenticated using (true);
create policy ref_read_sizes on public.size_set_sizes for select to authenticated using (true);
create policy ref_read_categories on public.categories for select to authenticated using (true);

create policy suppliers_read on public.suppliers for select to authenticated
  using (public.is_business_member(business_id)
         and (public.has_permission('purchasing.manage') or public.has_permission('store.operate') or public.has_permission('products.manage')));
create policy designs_read on public.designs for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('products.view'));
create policy variants_read on public.variants for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('products.view'));
create policy variant_costs_read on public.variant_costs for select to authenticated
  using (public.has_permission('costs.view')
         and exists (select 1 from public.variants v where v.id = variant_id and public.is_business_member(v.business_id)));

create policy balances_read on public.stock_balances for select to authenticated
  using (public.can_access_location(location_id)
         or (public.is_business_member(business_id) and public.has_permission('stock.approve')));
create policy movements_read on public.stock_movements for select to authenticated
  using (public.can_access_location(location_id)
         or (public.is_business_member(business_id) and public.has_permission('stock.approve')));
create policy documents_read on public.stock_documents for select to authenticated
  using (public.is_business_member(business_id)
         and (public.has_permission('store.operate') or public.has_permission('stock.approve') or public.has_permission('shop_stock.view')));

create policy po_read on public.purchase_orders for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('purchasing.manage'));
create policy po_lines_read on public.purchase_order_lines for select to authenticated
  using (exists (select 1 from public.purchase_orders po where po.id = po_id and public.is_business_member(po.business_id)
                 and public.has_permission('purchasing.manage')));

create policy gr_read on public.goods_receipts for select to authenticated
  using (public.is_business_member(business_id)
         and (public.can_access_location(location_id) or public.has_permission('purchasing.manage') or public.has_permission('costs.view')));
create policy gr_lines_read on public.goods_receipt_lines for select to authenticated
  using (exists (select 1 from public.goods_receipts g where g.id = receipt_id and public.is_business_member(g.business_id)
                 and (public.can_access_location(g.location_id) or public.has_permission('purchasing.manage') or public.has_permission('costs.view'))));
create policy gr_costs_read on public.goods_receipt_costs for select to authenticated
  using (public.has_permission('costs.view') and exists (select 1 from public.goods_receipt_lines l join public.goods_receipts g on g.id = l.receipt_id
                 where l.id = receipt_line_id and public.is_business_member(g.business_id)));
create policy gr_extra_read on public.goods_receipt_extra_costs for select to authenticated
  using (public.has_permission('costs.view') and exists (select 1 from public.goods_receipts g where g.id = receipt_id and public.is_business_member(g.business_id)));

create policy req_read on public.requisitions for select to authenticated
  using (public.is_business_member(business_id)
         and (public.can_access_location(from_location) or public.can_access_location(to_location) or public.has_permission('stock.approve')));
create policy req_lines_read on public.requisition_lines for select to authenticated
  using (exists (select 1 from public.requisitions q where q.id = requisition_id and public.is_business_member(q.business_id)
                 and (public.can_access_location(q.from_location) or public.can_access_location(q.to_location) or public.has_permission('stock.approve'))));
create policy tr_read on public.transfers for select to authenticated
  using (public.is_business_member(business_id)
         and (public.can_access_location(from_location) or public.can_access_location(to_location) or public.has_permission('stock.approve')));
create policy tr_lines_read on public.transfer_lines for select to authenticated
  using (exists (select 1 from public.transfers t where t.id = transfer_id and public.is_business_member(t.business_id)
                 and (public.can_access_location(t.from_location) or public.can_access_location(t.to_location) or public.has_permission('stock.approve'))));
create policy disc_read on public.transfer_discrepancies for select to authenticated
  using (exists (select 1 from public.transfer_lines tl join public.transfers t on t.id = tl.transfer_id
                 where tl.id = transfer_line_id and public.is_business_member(t.business_id)
                 and (public.can_access_location(t.from_location) or public.can_access_location(t.to_location) or public.has_permission('stock.approve'))));
create policy counts_read on public.stock_counts for select to authenticated
  using (public.is_business_member(business_id) and (public.can_access_location(location_id) or public.has_permission('stock.approve')));
-- Count lines (with system snapshot) only for approvers: counters use count_sheet() which hides quantities.
create policy count_lines_read on public.stock_count_lines for select to authenticated
  using (public.has_permission('stock.approve') and exists (select 1 from public.stock_counts c where c.id = count_id and public.is_business_member(c.business_id)));
-- doc_sequences, idempotency_keys: no policies (server-internal).

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

grant select on public.businesses, public.locations, public.memberships, public.membership_locations,
  public.permissions, public.role_permissions, public.audit_log,
  public.size_sets, public.size_set_sizes, public.categories, public.suppliers, public.designs, public.variants,
  public.variant_costs, public.stock_documents, public.stock_movements, public.stock_balances,
  public.purchase_orders, public.purchase_order_lines, public.goods_receipts, public.goods_receipt_lines,
  public.goods_receipt_costs, public.goods_receipt_extra_costs, public.requisitions, public.requisition_lines,
  public.transfers, public.transfer_lines, public.transfer_discrepancies, public.stock_counts, public.stock_count_lines,
  public.v_stock, public.v_catalogue
to authenticated;

grant execute on function
  public.current_membership(), public.current_aal(), public.has_permission(text),
  public.is_business_member(uuid), public.can_access_location(uuid), public.my_workspace(),
  public.team_invite(text, text, public.app_role, uuid[], text),
  public.team_set_status(uuid, public.membership_status, text),
  public.team_set_role(uuid, public.app_role, text),
  public.team_set_locations(uuid, boolean, uuid[], text),
  public.team_reset_access(uuid, text),
  public.location_create(text, text, public.location_kind),
  public.supplier_save(uuid, text, text, text, text),
  public.design_create(text, text, text, uuid, text, text[], text[], bigint, bigint),
  public.variant_add(uuid, text, text, bigint, bigint),
  public.variant_set_prices(uuid, bigint, bigint, text),
  public.opening_stock_post(uuid, uuid, jsonb, text),
  public.po_create(uuid, uuid, text, numeric, date, jsonb, text),
  public.po_expected_lines(uuid), public.po_open_list(),
  public.goods_receive(uuid, uuid, uuid, uuid, text, jsonb, text),
  public.receipt_approve_costs(uuid, jsonb, jsonb, text, text),
  public.requisition_create(uuid, uuid, uuid, jsonb, text),
  public.requisition_decide(uuid, boolean, jsonb, text),
  public.transfer_dispatch(uuid, uuid, uuid, uuid, jsonb, text),
  public.transfer_receive(uuid, uuid, jsonb, text),
  public.discrepancy_resolve(uuid, public.discrepancy_resolution, text),
  public.count_start(uuid, uuid[]), public.count_sheet(uuid), public.count_submit(uuid, jsonb),
  public.count_decide(uuid, boolean, text),
  public.store_overview(uuid)
to authenticated;

grant execute on function
  public.setup_create_business(text, text, text, int), public.setup_check_owner_code(text),
  public.setup_finalize_owner(text, uuid, text, text),
  public.team_attach_auth_user(uuid, uuid, text, int),
  public.activation_check(text, text), public.activation_finalize(text, text)
to service_role;

commit;
