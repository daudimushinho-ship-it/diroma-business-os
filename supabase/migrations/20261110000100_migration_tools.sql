-- DIROMA Business OS — Milestone G: controlled migration from MauzoTrack (or any spreadsheet).
-- Opening figures are posted as OPENING DOCUMENTS, never silent overwrites, and never as revenue:
--   * customers (create-only or update by phone) with optional opening receivable → an "opening balance" invoice
--     (sales.is_opening = true, no lines, Dr Receivable / Cr Opening balance equity), so collections, FIFO and ageing
--     work, while every sales/commission/target report excludes it;
--   * opening stock from a CSV (design code + colour + size + location code) → one opening stock document per location.
-- Both are all-or-nothing and idempotent by import id.

begin;

alter table public.sales add column is_opening boolean not null default false;
create index sales_opening on public.sales (customer_id) where is_opening;

create table public.data_imports (
  id           uuid primary key,
  business_id  uuid not null references public.businesses(id),
  kind         text not null check (kind in ('customers','opening_stock')),
  row_count    int not null,
  result       jsonb not null,
  imported_by  uuid not null references public.memberships(id),
  created_at   timestamptz not null default now()
);
alter table public.data_imports enable row level security;
create policy data_imports_read on public.data_imports for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('settings.manage'));

-- rows: [{name, phone (E.164 or null), kind, credit_limit, terms_days, region, source, opening_balance}]
create or replace function public.customer_import(p_import uuid, p_rows jsonb, p_mode text, p_as_of date, p_location uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_prev jsonb; r record; c public.customers; v_cust uuid; v_sale uuid; v_ref text;
        n_new int := 0; n_upd int := 0; n_open int := 0; v_open_total bigint := 0; v_payload jsonb; v_n int := 0; v_result jsonb;
begin
  v_me := public.require_permission('settings.manage');
  perform public.require_permission('credit.manage');
  if p_mode not in ('create_only','update') then raise exception 'mode must be create_only or update' using errcode = '22023'; end if;
  v_payload := jsonb_build_object('rows', p_rows, 'mode', p_mode, 'as_of', p_as_of, 'location', p_location);
  v_prev := public._idem_get(p_import, 'customer_import', v_payload);
  if v_prev is not null then return v_prev; end if;
  if p_as_of is null or p_as_of > public._business_date(v_me.business_id, now()) then raise exception 'as-of date must not be in the future' using errcode = '22023'; end if;

  for r in select e.rn::int rn, x.* from jsonb_array_elements(p_rows) with ordinality as e(j, rn)
           cross join lateral jsonb_to_record(e.j) as x(name text, phone text, kind text, credit_limit bigint, terms_days int,
                region text, source text, opening_balance bigint)
           order by e.rn loop
    v_n := v_n + 1;
    if coalesce(btrim(r.name), '') = '' then raise exception 'row %: name required', r.rn using errcode = '22023'; end if;
    if r.phone is not null and r.phone !~ '^\+[1-9][0-9]{7,14}$' then raise exception 'row %: phone must be E.164', r.rn using errcode = '22023'; end if;
    if coalesce(r.kind, 'retail') not in ('retail','wholesale') then raise exception 'row %: kind must be retail or wholesale', r.rn using errcode = '22023'; end if;
    if coalesce(r.opening_balance, 0) < 0 or coalesce(r.credit_limit, 0) < 0 then raise exception 'row %: amounts cannot be negative', r.rn using errcode = '22023'; end if;
    c := null;
    if r.phone is not null then select * into c from public.customers where business_id = v_me.business_id and phone_e164 = r.phone for update; end if;
    if c.id is not null then
      if p_mode = 'create_only' then raise exception 'row %: customer with phone % already exists', r.rn, r.phone using errcode = '22023'; end if;
      update public.customers set name = btrim(r.name), kind = coalesce(r.kind, c.kind)::public.customer_kind,
             credit_limit = coalesce(r.credit_limit, c.credit_limit), terms_days = coalesce(r.terms_days, c.terms_days),
             region = coalesce(nullif(btrim(r.region), ''), c.region), source = coalesce(nullif(btrim(r.source), ''), c.source)
       where id = c.id;
      v_cust := c.id; n_upd := n_upd + 1;
    else
      insert into public.customers (business_id, name, phone_e164, kind, credit_limit, terms_days, region, source, created_by)
      values (v_me.business_id, btrim(r.name), r.phone, coalesce(r.kind, 'retail')::public.customer_kind, coalesce(r.credit_limit, 0),
              coalesce(r.terms_days, 0), nullif(btrim(r.region), ''), nullif(btrim(r.source), ''), v_me.id) returning id into v_cust;
      n_new := n_new + 1;
    end if;
    if coalesce(r.opening_balance, 0) > 0 then
      if p_location is null or not exists (select 1 from public.locations where id = p_location and business_id = v_me.business_id and kind = 'shop') then
        raise exception 'choose the shop that will own opening balances' using errcode = '22023';
      end if;
      if exists (select 1 from public.sales where customer_id = v_cust and is_opening) then
        raise exception 'row %: customer already has an opening balance', r.rn using errcode = '22023';
      end if;
      v_ref := public._next_ref(v_me.business_id, 'OPB');
      insert into public.sales (business_id, ref_no, location_id, shift_id, customer_id, channel, source, gross_amount, discount_amount, delivery_fee,
                                total, payment_status, fulfillment_status, sold_at, sold_by, note, is_opening)
      values (v_me.business_id, v_ref, p_location, null, v_cust, 'retail', 'opening_balance', r.opening_balance, 0, 0, r.opening_balance,
              'unpaid', 'delivered', ((p_as_of + 1)::timestamp at time zone (select timezone from public.businesses where id = v_me.business_id)) - interval '1 second',
              v_me.id, 'Opening balance migrated from previous system', true)
      returning id into v_sale;
      perform public._post_journal(v_me.business_id, p_as_of, 'opening_receivable', v_sale, v_ref, v_me.id,
        jsonb_build_array(public._jl('1100', r.opening_balance, 0, null, v_cust), public._jl('3000', 0, r.opening_balance)));
      n_open := n_open + 1; v_open_total := v_open_total + r.opening_balance;
    end if;
  end loop;
  if v_n = 0 then raise exception 'no rows' using errcode = '22023'; end if;
  v_result := jsonb_build_object('rows', v_n, 'created', n_new, 'updated', n_upd, 'opening_balances', n_open, 'opening_total', v_open_total);
  insert into public.data_imports (id, business_id, kind, row_count, result, imported_by) values (p_import, v_me.business_id, 'customers', v_n, v_result, v_me.id);
  perform public.write_audit(v_me.business_id, 'import.customers', 'data_import', p_import::text, null, v_result, null);
  return public._idem_put(p_import, v_me.business_id, 'customer_import', v_payload, v_result);
end $$;

-- rows: [{design_code, color, size, location_code, qty}]
create or replace function public.opening_stock_import(p_import uuid, p_rows jsonb, p_reason text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_prev jsonb; v_payload jsonb; r record; v_var uuid; v_loc public.locations; v_docs jsonb := '{}'; v_doc uuid;
        v_n int := 0; v_units bigint := 0; v_result jsonb;
begin
  v_me := public.require_permission('stock.opening');
  if coalesce(btrim(p_reason), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  v_payload := jsonb_build_object('rows', p_rows, 'reason', p_reason);
  v_prev := public._idem_get(p_import, 'opening_stock_import', v_payload);
  if v_prev is not null then return v_prev; end if;
  for r in select e.rn::int rn, x.* from jsonb_array_elements(p_rows) with ordinality as e(j, rn)
           cross join lateral jsonb_to_record(e.j) as x(design_code text, color text, size text, location_code text, qty int)
           order by e.rn loop
    v_n := v_n + 1;
    if r.qty is null or r.qty <= 0 then raise exception 'row %: quantity must be positive', r.rn using errcode = '22023'; end if;
    select v.id into v_var from public.variants v join public.designs d on d.id = v.design_id
     where d.business_id = v_me.business_id and d.code = btrim(r.design_code) and lower(v.color) = lower(btrim(r.color)) and v.size = upper(btrim(r.size));
    if v_var is null then raise exception 'row %: no variant % / % / % (import the catalogue first)', r.rn, r.design_code, r.color, r.size using errcode = '22023'; end if;
    select * into v_loc from public.locations where business_id = v_me.business_id and code = upper(btrim(r.location_code)) and is_active and kind in ('warehouse','shop');
    if v_loc.id is null then raise exception 'row %: unknown Store/Shop code %', r.rn, r.location_code using errcode = '22023'; end if;
    if not (v_docs ? v_loc.id::text) then
      v_doc := public._new_doc(v_me.business_id, 'opening', 'OPN', v_me.id, p_import, p_reason);
      v_docs := v_docs || jsonb_build_object(v_loc.id::text, v_doc);
    end if;
    perform public._move(v_me.business_id, (v_docs ->> v_loc.id::text)::uuid, v_var, v_loc.id, r.qty);
    v_units := v_units + r.qty;
    v_var := null;
  end loop;
  if v_n = 0 then raise exception 'no rows' using errcode = '22023'; end if;
  v_result := jsonb_build_object('rows', v_n, 'units', v_units, 'documents', (select count(*) from jsonb_object_keys(v_docs)));
  insert into public.data_imports (id, business_id, kind, row_count, result, imported_by) values (p_import, v_me.business_id, 'opening_stock', v_n, v_result, v_me.id);
  perform public.write_audit(v_me.business_id, 'import.opening_stock', 'data_import', p_import::text, null, v_result, p_reason);
  return public._idem_put(p_import, v_me.business_id, 'opening_stock_import', v_payload, v_result);
end $$;

revoke all on public.data_imports from anon, authenticated;
grant select on public.data_imports to authenticated;
revoke all on function public.customer_import(uuid, jsonb, text, date, uuid), public.opening_stock_import(uuid, jsonb, text) from public, anon, authenticated;
grant execute on function public.customer_import(uuid, jsonb, text, date, uuid), public.opening_stock_import(uuid, jsonb, text) to authenticated;

commit;
