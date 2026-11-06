-- DIROMA Business OS — Milestone D: Wholesale customers & consignment partners.
--
-- Two modes:
--   A. Outright wholesale sale  — goods leave a Store/Shop and are invoiced at once on agreed terms.
--   B. Consignment              — DIROMA-owned goods move into the partner's custody (a 'partner' location in the
--                                 same stock ledger). No revenue, no debt at dispatch. The partner later reports:
--                                   sold      → invoice at the agreed dispatch price (revenue + receivable + COGS)
--                                   returned  → goods go to INSPECTION (not straight to saleable stock)
--                                   lost      → pending until an independent approver charges the partner or writes it off
-- Per dispatch line: qty = sold + returned + lost + pending_loss + still_held   (enforced by CHECK)
-- Partner-held quantity always equals the partner location's on-hand balance (tested).

alter type public.stock_doc_type add value if not exists 'consignment_dispatch';
alter type public.stock_doc_type add value if not exists 'consignment_return';
alter type public.stock_doc_type add value if not exists 'consignment_loss';

begin;

-- Wholesale invoices are not POS sales: they have no cash-drawer shift.
alter table public.sales alter column shift_id drop not null;

alter table public.customers
  add column consignment_enabled boolean not null default false,
  add column partner_location_id uuid references public.locations(id),
  add column update_interval_days int not null default 7 check (update_interval_days between 1 and 90),
  add column last_report_at timestamptz;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create type public.consignment_order_status as enum ('approved', 'partially_dispatched', 'dispatched', 'cancelled');

create table public.consignment_orders (
  id               uuid primary key default gen_random_uuid(),
  business_id      uuid not null references public.businesses(id),
  ref_no           text not null,
  partner_id       uuid not null references public.customers(id),
  source_location  uuid not null references public.locations(id),
  status           public.consignment_order_status not null default 'approved',
  created_by       uuid not null references public.memberships(id),
  notes            text,
  created_at       timestamptz not null default now(),
  unique (business_id, ref_no)
);
create table public.consignment_order_lines (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references public.consignment_orders(id),
  variant_id      uuid not null references public.variants(id),
  qty_ordered     int not null check (qty_ordered > 0),
  qty_dispatched  int not null default 0 check (qty_dispatched >= 0),
  unit_price      bigint not null check (unit_price > 0),   -- agreed partner price, TZS
  check (qty_dispatched <= qty_ordered),
  unique (order_id, variant_id)
);

create table public.consignment_dispatches (
  id                uuid primary key default gen_random_uuid(),
  business_id       uuid not null references public.businesses(id),
  ref_no            text not null,
  order_id          uuid not null references public.consignment_orders(id),
  partner_id        uuid not null references public.customers(id),
  source_location   uuid not null references public.locations(id),
  partner_location  uuid not null references public.locations(id),
  dispatched_by     uuid not null references public.memberships(id),
  recipient_name    text not null,
  evidence_note     text,
  override_reason   text,
  document_id       uuid not null references public.stock_documents(id),
  created_at        timestamptz not null default now(),
  unique (business_id, ref_no)
);
create table public.consignment_dispatch_lines (
  id                uuid primary key default gen_random_uuid(),
  dispatch_id       uuid not null references public.consignment_dispatches(id),
  order_line_id     uuid not null references public.consignment_order_lines(id),
  partner_id        uuid not null references public.customers(id),
  variant_id        uuid not null references public.variants(id),
  qty               int not null check (qty > 0),
  unit_price        bigint not null check (unit_price > 0),
  qty_sold          int not null default 0 check (qty_sold >= 0),
  qty_returned      int not null default 0 check (qty_returned >= 0),
  qty_lost          int not null default 0 check (qty_lost >= 0),
  qty_pending_loss  int not null default 0 check (qty_pending_loss >= 0),
  created_at        timestamptz not null default now(),
  check (qty_sold + qty_returned + qty_lost + qty_pending_loss <= qty)
);
create index cdl_partner_variant on public.consignment_dispatch_lines (partner_id, variant_id, created_at);

create table public.consignment_reports (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id),
  ref_no       text not null,
  partner_id   uuid not null references public.customers(id),
  report_date  date not null,
  reported_by  uuid not null references public.memberships(id),
  sale_id      uuid references public.sales(id),
  note         text,
  created_at   timestamptz not null default now(),
  unique (business_id, ref_no)
);
create table public.consignment_report_lines (
  id          uuid primary key default gen_random_uuid(),
  report_id   uuid not null references public.consignment_reports(id),
  variant_id  uuid not null references public.variants(id),
  sold        int not null default 0 check (sold >= 0),
  returned    int not null default 0 check (returned >= 0),
  lost        int not null default 0 check (lost >= 0)
);

create type public.consignment_loss_status as enum ('pending', 'charged', 'written_off', 'rejected');

create table public.consignment_losses (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id),
  partner_id   uuid not null references public.customers(id),
  report_id    uuid not null references public.consignment_reports(id),
  variant_id   uuid not null references public.variants(id),
  qty          int not null check (qty > 0),
  allocation   jsonb not null,              -- [{line_id, qty}] reserved as pending on dispatch lines
  status       public.consignment_loss_status not null default 'pending',
  reported_by  uuid not null references public.memberships(id),
  decided_by   uuid references public.memberships(id),
  decided_at   timestamptz,
  decision_note text,
  sale_id      uuid references public.sales(id),
  created_at   timestamptz not null default now()
);

create table public.consignment_reminders (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  partner_id  uuid not null references public.customers(id),
  channel     text not null check (channel in ('whatsapp','sms','call','visit')),
  note        text,
  created_by  uuid not null references public.memberships(id),
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public._partner(p_business uuid, p_partner uuid, p_lock boolean default false) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare c public.customers;
begin
  if p_lock then
    select * into c from public.customers where id = p_partner and business_id = p_business for update;
  else
    select * into c from public.customers where id = p_partner and business_id = p_business;
  end if;
  if c.id is null then raise exception 'unknown partner' using errcode = '22023'; end if;
  if c.kind <> 'wholesale' then raise exception 'partner must be a wholesale customer' using errcode = '22023'; end if;
  return c;
end $$;

-- Posts a wholesale invoice (no shift): stock out of p_location, Dr Receivable / Cr Sales, COGS at average cost.
-- p_lines: [{variant_id, qty, price, discount}]
create or replace function public._wholesale_invoice(p_business uuid, p_me uuid, p_customer uuid, p_location uuid, p_lines jsonb,
                                                     p_doc_type public.stock_doc_type, p_note text, p_approval uuid)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_sale uuid; v_ref text; v_doc uuid; r record; v_line uuid; v_cost bigint; v_cogs bigint := 0;
        v_gross bigint := 0; v_disc bigint := 0; v_date date := public._business_date(p_business, now());
begin
  select coalesce(sum(x.price * x.qty), 0), coalesce(sum(coalesce(x.discount, 0)), 0) into v_gross, v_disc
    from jsonb_to_recordset(p_lines) as x(variant_id uuid, qty int, price bigint, discount bigint);
  if v_gross <= 0 then raise exception 'empty invoice' using errcode = '22023'; end if;
  v_ref := public._next_ref(p_business, 'INV');
  insert into public.sales (business_id, ref_no, location_id, shift_id, customer_id, channel, source, gross_amount, discount_amount,
                            delivery_fee, total, payment_status, fulfillment_status, sold_at, sold_by, approval_id, note)
  values (p_business, v_ref, p_location, null, p_customer, 'wholesale', 'wholesale', v_gross, v_disc, 0, v_gross - v_disc,
          'unpaid', 'delivered', now(), p_me, p_approval, p_note)
  returning id into v_sale;
  v_doc := public._new_doc(p_business, p_doc_type, 'DOC', p_me, v_sale, v_ref);
  for r in select x.variant_id, x.qty, x.price, coalesce(x.discount, 0) as discount
           from jsonb_to_recordset(p_lines) as x(variant_id uuid, qty int, price bigint, discount bigint) loop
    insert into public.sale_lines (sale_id, variant_id, qty, list_price, discount, line_total)
    values (v_sale, r.variant_id, r.qty, r.price, r.discount, r.price * r.qty - r.discount) returning id into v_line;
    select avg_cost into v_cost from public.variant_costs where variant_id = r.variant_id;
    insert into public.sale_line_costs (sale_line_id, unit_cost, cost_known) values (v_line, v_cost, v_cost is not null);
    v_cogs := v_cogs + coalesce(v_cost, 0) * r.qty;
    perform public._move(p_business, v_doc, r.variant_id, p_location, -r.qty);
  end loop;
  perform public._post_journal(p_business, v_date, 'sale', v_sale, v_ref, p_me, jsonb_build_array(
    public._jl('1100', v_gross - v_disc, 0, null, p_customer), public._jl('4000', 0, v_gross - v_disc),
    public._jl('5000', v_cogs, 0), public._jl('1200', 0, v_cogs)));
  perform public._refresh_payment_status(v_sale);
  return v_sale;
end $$;

-- Quantity of a variant the partner can still account for (not yet sold/returned/lost/pending).
create or replace function public._partner_reportable(p_partner uuid, p_variant uuid) returns int
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(qty - qty_sold - qty_returned - qty_lost - qty_pending_loss), 0)::int
  from public.consignment_dispatch_lines where partner_id = p_partner and variant_id = p_variant
$$;

-- ---------------------------------------------------------------------------
-- Partner configuration
-- ---------------------------------------------------------------------------
create or replace function public.partner_configure(p_customer uuid, p_enabled boolean, p_interval_days int)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; c public.customers; v_loc uuid;
begin
  v_me := public.require_permission('wholesale.manage');
  c := public._partner(v_me.business_id, p_customer, true);
  v_loc := c.partner_location_id;
  if p_enabled and v_loc is null then
    insert into public.locations (business_id, code, name, kind)
    values (v_me.business_id, 'P-' || upper(substr(replace(c.id::text, '-', ''), 1, 8)), 'Partner: ' || c.name, 'partner')
    returning id into v_loc;
  end if;
  update public.customers set consignment_enabled = p_enabled, partner_location_id = v_loc,
         update_interval_days = coalesce(p_interval_days, update_interval_days) where id = c.id;
  perform public.write_audit(v_me.business_id, 'partner.configure', 'customer', c.id::text,
    jsonb_build_object('enabled', c.consignment_enabled, 'interval', c.update_interval_days),
    jsonb_build_object('enabled', p_enabled, 'interval', p_interval_days), null);
  return v_loc;
end $$;

-- ---------------------------------------------------------------------------
-- Consignment order → dispatch
-- ---------------------------------------------------------------------------
create or replace function public.consignment_order_create(p_idem uuid, p_partner uuid, p_source uuid, p_lines jsonb, p_notes text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; c public.customers; v_order uuid; v_ref text; r record;
        v_price bigint; n int := 0;
begin
  v_me := public.require_permission('wholesale.manage');
  v_payload := jsonb_build_object('partner', p_partner, 'source', p_source, 'lines', p_lines, 'notes', p_notes);
  v_prev := public._idem_get(p_idem, 'consignment_order_create', v_payload);
  if v_prev is not null then return v_prev; end if;
  c := public._partner(v_me.business_id, p_partner);
  if not c.consignment_enabled then raise exception 'enable consignment for this partner first' using errcode = '22023'; end if;
  if not exists (select 1 from public.locations where id = p_source and business_id = v_me.business_id and is_active and kind in ('warehouse','shop')) then
    raise exception 'source must be a Store or Shop' using errcode = '22023';
  end if;
  v_ref := public._next_ref(v_me.business_id, 'CON');
  insert into public.consignment_orders (business_id, ref_no, partner_id, source_location, created_by, notes)
  values (v_me.business_id, v_ref, c.id, p_source, v_me.id, nullif(btrim(p_notes), '')) returning id into v_order;
  for r in select x.variant_id, x.qty, x.unit_price from jsonb_to_recordset(p_lines) as x(variant_id uuid, qty int, unit_price bigint) loop
    if r.qty is null or r.qty <= 0 then raise exception 'quantity must be positive' using errcode = '22023'; end if;
    select coalesce(r.unit_price, v.wholesale_price) into v_price from public.variants v where v.id = r.variant_id and v.business_id = v_me.business_id;
    if not found then raise exception 'unknown variant' using errcode = '22023'; end if;
    if v_price is null or v_price <= 0 then raise exception 'set a wholesale price (or an agreed price) for every line' using errcode = '22023'; end if;
    insert into public.consignment_order_lines (order_id, variant_id, qty_ordered, unit_price) values (v_order, r.variant_id, r.qty, v_price);
    perform public._reserve(v_me.business_id, r.variant_id, p_source, r.qty);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'no lines' using errcode = '22023'; end if;
  perform public.write_audit(v_me.business_id, 'consignment.order', 'consignment_order', v_order::text, null,
    jsonb_build_object('ref', v_ref, 'partner', c.name, 'lines', n), null);
  return public._idem_put(p_idem, v_me.business_id, 'consignment_order_create', v_payload, jsonb_build_object('order_id', v_order, 'ref_no', v_ref));
end $$;

-- Store hands goods to the partner. Custody moves to the partner location; reservation released; no revenue, no debt.
create or replace function public.consignment_dispatch(p_idem uuid, p_order uuid, p_lines jsonb, p_recipient text, p_evidence text, p_override_reason text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; o public.consignment_orders; c public.customers; v_disp uuid; v_ref text;
        v_doc uuid; r record; ol public.consignment_order_lines; n int := 0;
begin
  v_me := public.require_permission('store.operate');
  v_payload := jsonb_build_object('order', p_order, 'lines', p_lines, 'recipient', p_recipient, 'evidence', p_evidence, 'override', p_override_reason);
  v_prev := public._idem_get(p_idem, 'consignment_dispatch', v_payload);
  if v_prev is not null then return v_prev; end if;
  select * into o from public.consignment_orders where id = p_order and business_id = v_me.business_id for update;
  if o.id is null or o.status not in ('approved','partially_dispatched') then raise exception 'order is not open for dispatch' using errcode = '22023'; end if;
  perform public._require_location(o.source_location);
  if o.created_by = v_me.id and (v_me.role <> 'owner' or coalesce(btrim(p_override_reason), '') = '') then
    raise exception 'the person who created the order cannot also dispatch it' using errcode = '42501';
  end if;
  if coalesce(btrim(p_recipient), '') = '' then raise exception 'recipient name required' using errcode = '22023'; end if;
  c := public._partner(v_me.business_id, o.partner_id);
  v_ref := public._next_ref(v_me.business_id, 'CDS');
  v_doc := public._new_doc(v_me.business_id, 'consignment_dispatch', 'DOC', v_me.id, o.id, v_ref);
  insert into public.consignment_dispatches (business_id, ref_no, order_id, partner_id, source_location, partner_location, dispatched_by,
                                             recipient_name, evidence_note, override_reason, document_id)
  values (v_me.business_id, v_ref, o.id, c.id, o.source_location, c.partner_location_id, v_me.id, btrim(p_recipient),
          nullif(btrim(p_evidence), ''), nullif(btrim(p_override_reason), ''), v_doc) returning id into v_disp;
  for r in select x.order_line_id, x.qty from jsonb_to_recordset(p_lines) as x(order_line_id uuid, qty int) loop
    if r.qty is null or r.qty <= 0 then continue; end if;
    select * into ol from public.consignment_order_lines where id = r.order_line_id and order_id = o.id for update;
    if ol.id is null then raise exception 'line not on this order' using errcode = '22023'; end if;
    if ol.qty_dispatched + r.qty > ol.qty_ordered then raise exception 'dispatch exceeds ordered quantity' using errcode = '22023'; end if;
    update public.consignment_order_lines set qty_dispatched = qty_dispatched + r.qty where id = ol.id;
    perform public._reserve(v_me.business_id, ol.variant_id, o.source_location, -r.qty);
    perform public._move(v_me.business_id, v_doc, ol.variant_id, o.source_location, -r.qty);
    perform public._move(v_me.business_id, v_doc, ol.variant_id, c.partner_location_id, r.qty);
    insert into public.consignment_dispatch_lines (dispatch_id, order_line_id, partner_id, variant_id, qty, unit_price)
    values (v_disp, ol.id, c.id, ol.variant_id, r.qty, ol.unit_price);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'no quantities to dispatch' using errcode = '22023'; end if;
  update public.consignment_orders set status = case
      when exists (select 1 from public.consignment_order_lines where order_id = o.id and qty_dispatched < qty_ordered)
      then 'partially_dispatched'::public.consignment_order_status else 'dispatched'::public.consignment_order_status end
   where id = o.id;
  perform public.write_audit(v_me.business_id, 'consignment.dispatch', 'consignment_dispatch', v_disp::text, null,
    jsonb_build_object('ref', v_ref, 'partner', c.name, 'recipient', p_recipient), p_override_reason);
  return public._idem_put(p_idem, v_me.business_id, 'consignment_dispatch', v_payload, jsonb_build_object('dispatch_id', v_disp, 'ref_no', v_ref));
end $$;

-- Cancel the undispatched remainder of an order (releases reservations).
create or replace function public.consignment_order_cancel(p_order uuid, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; o public.consignment_orders; r record;
begin
  v_me := public.require_permission('wholesale.manage');
  if coalesce(btrim(p_reason), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  select * into o from public.consignment_orders where id = p_order and business_id = v_me.business_id for update;
  if o.id is null or o.status not in ('approved','partially_dispatched') then raise exception 'order is not open' using errcode = '22023'; end if;
  for r in select * from public.consignment_order_lines where order_id = o.id and qty_dispatched < qty_ordered for update loop
    perform public._reserve(v_me.business_id, r.variant_id, o.source_location, -(r.qty_ordered - r.qty_dispatched));
  end loop;
  update public.consignment_orders set status = 'cancelled' where id = o.id;
  perform public.write_audit(v_me.business_id, 'consignment.cancel', 'consignment_order', o.id::text, null, null, p_reason);
end $$;

-- ---------------------------------------------------------------------------
-- Partner settlement report
-- ---------------------------------------------------------------------------
-- Allocate a quantity FIFO over the partner's dispatch lines of one variant. Returns [{line_id, qty, price}].
create or replace function public._cons_allocate(p_partner uuid, p_variant uuid, p_qty int, p_kind text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r record; v_left int := p_qty; v_take int; v_out jsonb := '[]';
begin
  for r in select id, unit_price, qty - qty_sold - qty_returned - qty_lost - qty_pending_loss as open_qty
           from public.consignment_dispatch_lines where partner_id = p_partner and variant_id = p_variant
             and qty - qty_sold - qty_returned - qty_lost - qty_pending_loss > 0
           order by created_at, id for update loop
    exit when v_left = 0;
    v_take := least(v_left, r.open_qty);
    if p_kind = 'sold' then update public.consignment_dispatch_lines set qty_sold = qty_sold + v_take where id = r.id;
    elsif p_kind = 'returned' then update public.consignment_dispatch_lines set qty_returned = qty_returned + v_take where id = r.id;
    else update public.consignment_dispatch_lines set qty_pending_loss = qty_pending_loss + v_take where id = r.id; end if;
    v_out := v_out || jsonb_build_object('line_id', r.id, 'qty', v_take, 'price', r.unit_price);
    v_left := v_left - v_take;
  end loop;
  if v_left > 0 then raise exception 'partner does not hold that many (short by %)', v_left using errcode = '22023'; end if;
  return v_out;
end $$;

create or replace function public.consignment_report(p_idem uuid, p_partner uuid, p_report_date date, p_lines jsonb, p_note text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; c public.customers; v_rep uuid; v_ref text; r record; a jsonb;
        v_inv_lines jsonb := '[]'; v_sale uuid; v_insp uuid; v_doc uuid; v_losses int := 0; v_ret int := 0;
begin
  v_me := public.require_permission('wholesale.manage');
  v_payload := jsonb_build_object('partner', p_partner, 'date', p_report_date, 'lines', p_lines, 'note', p_note);
  v_prev := public._idem_get(p_idem, 'consignment_report', v_payload);
  if v_prev is not null then return v_prev; end if;
  c := public._partner(v_me.business_id, p_partner, true);   -- serialises reports for this partner
  if c.partner_location_id is null then raise exception 'partner has no consignment stock' using errcode = '22023'; end if;
  if p_report_date is null or p_report_date > public._business_date(v_me.business_id, now()) then
    raise exception 'report date cannot be in the future' using errcode = '22023';
  end if;
  v_ref := public._next_ref(v_me.business_id, 'CRP');
  insert into public.consignment_reports (business_id, ref_no, partner_id, report_date, reported_by, note)
  values (v_me.business_id, v_ref, c.id, p_report_date, v_me.id, nullif(btrim(p_note), '')) returning id into v_rep;

  for r in select x.variant_id, coalesce(x.sold, 0) sold, coalesce(x.returned, 0) returned, coalesce(x.lost, 0) lost
           from jsonb_to_recordset(p_lines) as x(variant_id uuid, sold int, returned int, lost int) loop
    if r.sold < 0 or r.returned < 0 or r.lost < 0 then raise exception 'quantities cannot be negative' using errcode = '22023'; end if;
    if r.sold + r.returned + r.lost = 0 then continue; end if;
    if r.sold + r.returned + r.lost > public._partner_reportable(c.id, r.variant_id) then
      raise exception 'reported quantity exceeds what the partner holds' using errcode = '22023';
    end if;
    insert into public.consignment_report_lines (report_id, variant_id, sold, returned, lost) values (v_rep, r.variant_id, r.sold, r.returned, r.lost);
    if r.sold > 0 then
      for a in select * from jsonb_array_elements(public._cons_allocate(c.id, r.variant_id, r.sold, 'sold')) loop
        v_inv_lines := v_inv_lines || jsonb_build_object('variant_id', r.variant_id, 'qty', (a->>'qty')::int, 'price', (a->>'price')::bigint, 'discount', 0);
      end loop;
    end if;
    if r.returned > 0 then
      perform public._cons_allocate(c.id, r.variant_id, r.returned, 'returned');
      v_insp := coalesce(v_insp, public._special_location(v_me.business_id, 'inspection', 'INSPECT', 'Inspection / Ukaguzi'));
      v_doc := coalesce(v_doc, public._new_doc(v_me.business_id, 'consignment_return', 'DOC', v_me.id, v_rep, v_ref));
      perform public._move(v_me.business_id, v_doc, r.variant_id, c.partner_location_id, -r.returned);
      perform public._move(v_me.business_id, v_doc, r.variant_id, v_insp, r.returned);
      v_ret := v_ret + r.returned;
    end if;
    if r.lost > 0 then
      insert into public.consignment_losses (business_id, partner_id, report_id, variant_id, qty, allocation, reported_by)
      values (v_me.business_id, c.id, v_rep, r.variant_id, r.lost, public._cons_allocate(c.id, r.variant_id, r.lost, 'pending'), v_me.id);
      v_losses := v_losses + r.lost;
    end if;
  end loop;

  if jsonb_array_length(v_inv_lines) > 0 then
    v_sale := public._wholesale_invoice(v_me.business_id, v_me.id, c.id, c.partner_location_id, v_inv_lines, 'sale',
                                        'Consignment sales reported ' || p_report_date || ' (' || v_ref || ')', null);
    update public.consignment_reports set sale_id = v_sale where id = v_rep;
  end if;
  update public.customers set last_report_at = now() where id = c.id;
  perform public.write_audit(v_me.business_id, 'consignment.report', 'consignment_report', v_rep::text, null,
    jsonb_build_object('ref', v_ref, 'invoice', v_sale, 'returned', v_ret, 'lost_pending', v_losses), p_note);
  return public._idem_put(p_idem, v_me.business_id, 'consignment_report', v_payload,
    jsonb_build_object('report_id', v_rep, 'ref_no', v_ref, 'sale_id', v_sale, 'returned', v_ret, 'lost_pending', v_losses));
end $$;

-- Independent decision on a reported custody loss: charge the partner, write it off, or reject (goods still held).
create or replace function public.consignment_loss_decide(p_loss uuid, p_decision text, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; l public.consignment_losses; c public.customers; a jsonb; v_lines jsonb := '[]'; v_sale uuid;
        v_doc uuid; v_cost bigint;
begin
  v_me := public.require_permission('approvals.decide');
  if p_decision not in ('charge','write_off','reject') then raise exception 'decision must be charge, write_off or reject' using errcode = '22023'; end if;
  if coalesce(btrim(p_note), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  select * into l from public.consignment_losses where id = p_loss and business_id = v_me.business_id for update;
  if l.id is null or l.status <> 'pending' then raise exception 'loss is not pending' using errcode = '22023'; end if;
  if l.reported_by = v_me.id then raise exception 'cannot decide a loss you reported' using errcode = '42501'; end if;
  c := public._partner(v_me.business_id, l.partner_id, true);
  for a in select * from jsonb_array_elements(l.allocation) loop
    update public.consignment_dispatch_lines set qty_pending_loss = qty_pending_loss - (a->>'qty')::int,
           qty_lost = qty_lost + case when p_decision = 'reject' then 0 else (a->>'qty')::int end
     where id = (a->>'line_id')::uuid;
    if p_decision = 'charge' then
      v_lines := v_lines || jsonb_build_object('variant_id', l.variant_id, 'qty', (a->>'qty')::int, 'price', (a->>'price')::bigint, 'discount', 0);
    end if;
  end loop;
  if p_decision = 'charge' then
    v_sale := public._wholesale_invoice(v_me.business_id, v_me.id, c.id, c.partner_location_id, v_lines, 'consignment_loss',
                                        'Goods lost in partner custody, charged to partner', null);
  elsif p_decision = 'write_off' then
    v_doc := public._new_doc(v_me.business_id, 'consignment_loss', 'DOC', v_me.id, l.id, p_note);
    perform public._move(v_me.business_id, v_doc, l.variant_id, c.partner_location_id, -l.qty);
    select avg_cost into v_cost from public.variant_costs where variant_id = l.variant_id;
    if v_cost is not null then
      perform public._post_journal(v_me.business_id, public._business_date(v_me.business_id, now()), 'consignment_loss', l.id,
        'Consignment custody loss written off', v_me.id,
        jsonb_build_array(public._jl('6200', v_cost * l.qty, 0), public._jl('1200', 0, v_cost * l.qty)));
    end if;
  end if;
  update public.consignment_losses set status = case p_decision when 'charge' then 'charged'::public.consignment_loss_status
         when 'write_off' then 'written_off'::public.consignment_loss_status else 'rejected'::public.consignment_loss_status end,
         decided_by = v_me.id, decided_at = now(), decision_note = p_note, sale_id = v_sale where id = l.id;
  perform public.write_audit(v_me.business_id, 'consignment.loss_' || p_decision, 'consignment_loss', l.id::text, null,
    jsonb_build_object('qty', l.qty), p_note);
end $$;

-- ---------------------------------------------------------------------------
-- Mode A: outright wholesale sale from a Store or Shop (credit terms, approvals for discount/credit limit)
-- ---------------------------------------------------------------------------
create or replace function public.wholesale_sale_post(p_idem uuid, p_partner uuid, p_source uuid, p_lines jsonb, p_note text, p_approval uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_payload jsonb; v_prev jsonb; c public.customers; r record; v_price bigint; v_lines jsonb := '[]';
        v_gross bigint := 0; v_disc bigint := 0; v_total bigint; v_reasons text[] := '{}'; v_limit numeric; v_pct numeric := 0;
        v_appr uuid; v_sale uuid;
begin
  v_me := public.require_permission('wholesale.manage');
  v_payload := jsonb_build_object('partner', p_partner, 'source', p_source, 'lines', p_lines, 'note', p_note);
  v_prev := public._idem_get(p_idem, 'wholesale_sale_post', v_payload);
  if v_prev is not null then return v_prev; end if;
  c := public._partner(v_me.business_id, p_partner, true);
  perform public._require_location(p_source, array['warehouse','shop']::public.location_kind[]);
  for r in select x.variant_id, x.qty, coalesce(x.discount, 0) discount from jsonb_to_recordset(p_lines) as x(variant_id uuid, qty int, discount bigint) loop
    if r.qty is null or r.qty <= 0 then raise exception 'quantity must be positive' using errcode = '22023'; end if;
    select wholesale_price into v_price from public.variants where id = r.variant_id and business_id = v_me.business_id and is_active;
    if not found then raise exception 'unknown variant' using errcode = '22023'; end if;
    if v_price is null then raise exception 'this size/colour has no wholesale price yet' using errcode = '22023'; end if;
    if r.discount < 0 or r.discount > v_price * r.qty then raise exception 'invalid discount' using errcode = '22023'; end if;
    v_gross := v_gross + v_price * r.qty; v_disc := v_disc + r.discount;
    v_lines := v_lines || jsonb_build_object('variant_id', r.variant_id, 'qty', r.qty, 'price', v_price, 'discount', r.discount);
  end loop;
  if jsonb_array_length(v_lines) = 0 then raise exception 'no lines' using errcode = '22023'; end if;
  v_total := v_gross - v_disc;
  if v_gross > 0 then v_pct := round(v_disc::numeric * 100 / v_gross, 2); end if;
  select max_pct into v_limit from public.discount_limits where role = v_me.role;
  if v_pct > coalesce(v_limit, 0) then v_reasons := array_append(v_reasons, 'discount'); end if;
  if public._customer_receivable(c.id) + v_total > c.credit_limit then v_reasons := array_append(v_reasons, 'credit_limit'); end if;
  if cardinality(v_reasons) > 0 then
    if p_approval is null then
      v_appr := public._approval_request(v_me.business_id, 'wholesale_sale_post', v_reasons, v_payload,
        jsonb_build_object('total', v_total, 'discount', v_disc, 'discount_pct', v_pct, 'due', v_total, 'customer', c.name,
                           'sold_at', now(), 'payload', v_payload), v_me.id);
      return jsonb_build_object('status', 'approval_required', 'approval_id', v_appr, 'reasons', v_reasons);
    end if;
    perform public._approval_consume(p_approval, 'wholesale_sale_post', v_reasons, v_payload, v_me.id);
  end if;
  v_sale := public._wholesale_invoice(v_me.business_id, v_me.id, c.id, p_source, v_lines, 'sale', nullif(btrim(p_note), ''),
                                      case when cardinality(v_reasons) > 0 then p_approval end);
  perform public.write_audit(v_me.business_id, 'wholesale.sale', 'sale', v_sale::text, null,
    jsonb_build_object('total', v_total, 'reasons', v_reasons), null);
  return public._idem_put(p_idem, v_me.business_id, 'wholesale_sale_post', v_payload,
    jsonb_build_object('status', 'posted', 'sale_id', v_sale, 'total', v_total));
end $$;

-- ---------------------------------------------------------------------------
-- Reminders (logged; delivery happens outside the system, e.g. WhatsApp share link)
-- ---------------------------------------------------------------------------
create or replace function public.consignment_reminder_log(p_partner uuid, p_channel text, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; c public.customers;
begin
  v_me := public.require_permission('wholesale.manage');
  c := public._partner(v_me.business_id, p_partner);
  insert into public.consignment_reminders (business_id, partner_id, channel, note, created_by)
  values (v_me.business_id, c.id, p_channel, nullif(btrim(p_note), ''), v_me.id);
end $$;

-- ---------------------------------------------------------------------------
-- Read models
-- ---------------------------------------------------------------------------
create or replace function public.partner_overview(p_partner uuid)
returns table (partner_id uuid, name text, phone text, region text, credit_limit bigint, terms_days int, consignment_enabled boolean,
               dispatched bigint, sold bigint, returned bigint, lost bigint, pending_loss bigint, held bigint, held_value bigint,
               invoiced bigint, paid bigint, outstanding bigint, credit bigint, oldest_due date, last_report timestamptz,
               next_update_due date, last_reminder timestamptz, unresolved bigint)
language plpgsql stable security definer set search_path = '' as $$
declare b uuid;
begin
  if not public.has_permission('wholesale.manage') then raise exception 'not authorized' using errcode = '42501'; end if;
  b := (public.current_membership()).business_id;
  return query
  with d as (
    select dl.partner_id, sum(dl.qty) dispatched, sum(dl.qty_sold) sold, sum(dl.qty_returned) returned, sum(dl.qty_lost) lost,
           sum(dl.qty_pending_loss) pending_loss,
           sum(dl.qty - dl.qty_sold - dl.qty_returned - dl.qty_lost) held,
           sum((dl.qty - dl.qty_sold - dl.qty_returned - dl.qty_lost)::bigint * dl.unit_price) held_value,
           min(dl.created_at) first_dispatch
    from public.consignment_dispatch_lines dl group by dl.partner_id
  ), s as (
    select sa.customer_id, sum(sa.total) invoiced,
           sum(coalesce((select sum(st.amount) from public.sale_settlements st where st.sale_id = sa.id and st.kind in ('payment','customer_credit')), 0)) paid,
           min(case when sa.payment_status <> 'paid' then public._business_date(sa.business_id, sa.sold_at) end) oldest_open
    from public.sales sa where sa.channel = 'wholesale' group by sa.customer_id
  )
  select c.id, c.name, c.phone_e164, c.region, c.credit_limit, c.terms_days, c.consignment_enabled,
         coalesce(d.dispatched,0)::bigint, coalesce(d.sold,0)::bigint, coalesce(d.returned,0)::bigint, coalesce(d.lost,0)::bigint,
         coalesce(d.pending_loss,0)::bigint, coalesce(d.held,0)::bigint, coalesce(d.held_value,0)::bigint,
         coalesce(s.invoiced,0)::bigint, coalesce(s.paid,0)::bigint,
         public._customer_receivable(c.id), public._customer_credit(c.id),
         (s.oldest_open + c.terms_days),
         c.last_report_at,
         (coalesce(public._business_date(c.business_id, c.last_report_at), public._business_date(c.business_id, d.first_dispatch)) + c.update_interval_days),
         (select max(r.created_at) from public.consignment_reminders r where r.partner_id = c.id),
         (select count(*) from public.consignment_losses l where l.partner_id = c.id and l.status = 'pending')
           + (select count(*) from public.consignment_orders o where o.partner_id = c.id and o.status in ('approved','partially_dispatched'))
  from public.customers c
  left join d on d.partner_id = c.id
  left join s on s.customer_id = c.id
  where c.business_id = b and c.kind = 'wholesale' and (p_partner is null or c.id = p_partner)
  order by c.name;
end $$;

-- Customer statement: opening balance, then every receivable/credit movement with a running balance (positive = customer owes).
create or replace function public.customer_statement(p_customer uuid, p_from date, p_to date)
returns table (entry_date date, ref_no text, source_type text, memo text, debit bigint, credit bigint, balance bigint, is_opening boolean)
language plpgsql stable security definer set search_path = '' as $$
declare b uuid; v_open bigint;
begin
  if not (public.has_permission('customers.view') and (public.has_permission('wholesale.manage') or public.has_permission('payments.collect'))) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  b := (public.current_membership()).business_id;
  if not exists (select 1 from public.customers where id = p_customer and business_id = b) then raise exception 'not found' using errcode = '22023'; end if;
  select coalesce(sum(jl.debit - jl.credit), 0)::bigint into v_open
    from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
   where jl.customer_id = p_customer and jl.account_code in ('1100','2000') and je.entry_date < p_from;
  return query
    select p_from, null::text, 'opening'::text, 'Opening balance'::text, 0::bigint, 0::bigint, v_open, true
    union all
    select x.entry_date, x.ref_no, x.source_type, x.memo, x.debit, x.credit,
           (v_open + sum(x.debit - x.credit) over (order by x.entry_date, x.created_at, x.ref_no rows unbounded preceding))::bigint, false
    from (
      select je.entry_date, je.ref_no, je.source_type, je.memo, je.created_at,
             sum(jl.debit)::bigint debit, sum(jl.credit)::bigint credit
      from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
      where jl.customer_id = p_customer and jl.account_code in ('1100','2000') and je.entry_date between p_from and p_to
      group by je.id
      having sum(jl.debit) <> sum(jl.credit)
    ) x;
end $$;

-- Partner stock held, by variant (quantities and agreed value; no buying cost).
create or replace function public.partner_holdings(p_partner uuid)
returns table (variant_id uuid, design_code text, design_name text, color text, size text, held bigint, pending_loss bigint, value bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('wholesale.manage') then raise exception 'not authorized' using errcode = '42501'; end if;
  return query
    select dl.variant_id, d.code, d.name, v.color, v.size,
           sum(dl.qty - dl.qty_sold - dl.qty_returned - dl.qty_lost)::bigint, sum(dl.qty_pending_loss)::bigint,
           sum((dl.qty - dl.qty_sold - dl.qty_returned - dl.qty_lost)::bigint * dl.unit_price)::bigint
    from public.consignment_dispatch_lines dl join public.variants v on v.id = dl.variant_id join public.designs d on d.id = v.design_id
    join public.customers c on c.id = dl.partner_id and c.business_id = (public.current_membership()).business_id
    where dl.partner_id = p_partner
    group by dl.variant_id, d.code, d.name, v.color, v.size
    having sum(dl.qty - dl.qty_sold - dl.qty_returned - dl.qty_lost) > 0
    order by d.code, v.color, v.size;
end $$;

-- ---------------------------------------------------------------------------
-- RLS & grants
-- ---------------------------------------------------------------------------
alter table public.consignment_orders enable row level security;
alter table public.consignment_order_lines enable row level security;
alter table public.consignment_dispatches enable row level security;
alter table public.consignment_dispatch_lines enable row level security;
alter table public.consignment_reports enable row level security;
alter table public.consignment_report_lines enable row level security;
alter table public.consignment_losses enable row level security;
alter table public.consignment_reminders enable row level security;

create policy cons_orders_read on public.consignment_orders for select to authenticated
  using (public.is_business_member(business_id)
         and (public.has_permission('wholesale.manage') or (public.has_permission('store.operate') and public.can_access_location(source_location))));
create policy cons_order_lines_read on public.consignment_order_lines for select to authenticated
  using (exists (select 1 from public.consignment_orders o where o.id = order_id and public.is_business_member(o.business_id)
                 and (public.has_permission('wholesale.manage') or (public.has_permission('store.operate') and public.can_access_location(o.source_location)))));
create policy cons_dispatches_read on public.consignment_dispatches for select to authenticated
  using (public.is_business_member(business_id)
         and (public.has_permission('wholesale.manage') or (public.has_permission('store.operate') and public.can_access_location(source_location))));
create policy cons_dispatch_lines_read on public.consignment_dispatch_lines for select to authenticated
  using (exists (select 1 from public.consignment_dispatches d where d.id = dispatch_id and public.is_business_member(d.business_id)
                 and (public.has_permission('wholesale.manage') or (public.has_permission('store.operate') and public.can_access_location(d.source_location)))));
create policy cons_reports_read on public.consignment_reports for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('wholesale.manage'));
create policy cons_report_lines_read on public.consignment_report_lines for select to authenticated
  using (exists (select 1 from public.consignment_reports r where r.id = report_id and public.is_business_member(r.business_id)
                 and public.has_permission('wholesale.manage')));
create policy cons_losses_read on public.consignment_losses for select to authenticated
  using (public.is_business_member(business_id) and (public.has_permission('wholesale.manage') or public.has_permission('approvals.decide')));
create policy cons_reminders_read on public.consignment_reminders for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('wholesale.manage'));

revoke all on public.consignment_orders, public.consignment_order_lines, public.consignment_dispatches, public.consignment_dispatch_lines,
  public.consignment_reports, public.consignment_report_lines, public.consignment_losses, public.consignment_reminders from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
grant select on public.consignment_orders, public.consignment_order_lines, public.consignment_dispatches, public.consignment_dispatch_lines,
  public.consignment_reports, public.consignment_report_lines, public.consignment_losses, public.consignment_reminders to authenticated;

grant execute on function
  public.partner_configure(uuid, boolean, int),
  public.consignment_order_create(uuid, uuid, uuid, jsonb, text),
  public.consignment_dispatch(uuid, uuid, jsonb, text, text, text),
  public.consignment_order_cancel(uuid, text),
  public.consignment_report(uuid, uuid, date, jsonb, text),
  public.consignment_loss_decide(uuid, text, text),
  public.wholesale_sale_post(uuid, uuid, uuid, jsonb, text, uuid),
  public.consignment_reminder_log(uuid, text, text),
  public.partner_overview(uuid), public.customer_statement(uuid, date, date), public.partner_holdings(uuid)
to authenticated;

commit;
