-- Milestone B database acceptance tests: catalogue, single stock ledger, Store/Stoo workflows, purchasing.
\set ON_ERROR_STOP 1
\set QUIET 1
\pset tuples_only on
\pset format unaligned

\ir _framework.sql

create function test.as_user(p_uid uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims', test.claims(p_uid, p_aal), false); select null::void;
$$;
grant execute on function test.as_user(uuid, text) to authenticated, service_role;

-- Ledger invariant: every balance equals the sum of its movements.
create function test.ledger_consistent() returns boolean language sql security definer as $$
  select not exists (
    select 1 from public.stock_balances b
    where b.on_hand <> coalesce((select sum(m.qty_delta) from public.stock_movements m
                                 where m.variant_id = b.variant_id and m.location_id = b.location_id), 0))
$$;
create function test.qty(p_variant uuid, p_loc_code text) returns int language sql security definer as $$
  select coalesce((select b.on_hand from public.stock_balances b join public.locations l on l.id = b.location_id
                   where b.variant_id = p_variant and l.code = p_loc_code), 0)
$$;
create function test.reserved(p_variant uuid, p_loc_code text) returns int language sql security definer as $$
  select coalesce((select b.reserved from public.stock_balances b join public.locations l on l.id = b.location_id
                   where b.variant_id = p_variant and l.code = p_loc_code), 0)
$$;
grant execute on all functions in schema test to authenticated, service_role;

-- ---------------------------------------------------------------- fixture: owner, staff, locations
insert into auth.users (id, phone) values
  ('00000000-0000-0000-0000-0000000000b1', '+255710000001'),  -- owner
  ('00000000-0000-0000-0000-0000000000b2', '+255710000002'),  -- manager
  ('00000000-0000-0000-0000-0000000000b3', '+255710000003'),  -- sales (shop)
  ('00000000-0000-0000-0000-0000000000b4', '+255710000004');  -- storekeeper (warehouse)
\set OWNER   '''00000000-0000-0000-0000-0000000000b1'''
\set MANAGER '''00000000-0000-0000-0000-0000000000b2'''
\set SALES   '''00000000-0000-0000-0000-0000000000b3'''
\set STORE   '''00000000-0000-0000-0000-0000000000b4'''

set role service_role;
select public.setup_create_business('DIROMA', 'Spirit of Fashion', 'FIXTURE-CODE') \gset x_
select public.setup_finalize_owner('FIXTURE-CODE', :OWNER, '+255710000001', 'Owner B') \gset x_
reset role;

set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.location_create('WH', 'Store / Stoo', 'warehouse') as loc_wh \gset
select public.location_create('SHOP', 'Shop / Dukani', 'shop') as loc_shop \gset
select public.team_invite('+255710000002', 'Manager B', 'manager', '{}', null) as m_mgr \gset
select public.team_invite('+255710000003', 'Sales B', 'sales_staff', array[:'loc_shop']::uuid[], null) as m_sales \gset
select public.team_invite('+255710000004', 'Store B', 'storekeeper', array[:'loc_wh']::uuid[], null) as m_store \gset
select public.team_set_locations(:'m_mgr', true, '{}', 'manager covers all') \gset x_
reset role;

set role service_role;
select public.team_attach_auth_user(:'m_mgr', :MANAGER, 'C1') \gset x_
select public.team_attach_auth_user(:'m_sales', :SALES, 'C2') \gset x_
select public.team_attach_auth_user(:'m_store', :STORE, 'C3') \gset x_
select public.activation_finalize('+255710000002', 'C1') \gset x_
select public.activation_finalize('+255710000003', 'C2') \gset x_
select public.activation_finalize('+255710000004', 'C3') \gset x_
reset role;

-- ---------------------------------------------------------------- catalogue
set role authenticated;
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.supplier_save(null, 'Guangzhou Supplier Test', null, 'China', null) as sup \gset
select public.design_create('DR#2516-43', 'Slim suit test', 'suit_2pc', :'sup', null,
  array['Black','Navy'], array['48','50'], 450000, 380000) as design \gset
select test.ok('catalogue: colour × size matrix created (2×2)', (select count(*) from public.variants where design_id = :'design') = 4);
select test.ok('catalogue: original code with # preserved in SKU',
  exists (select 1 from public.variants where sku = 'DR#2516-43-BLACK-48'));
select test.ok('catalogue: barcodes unique and auto-generated',
  (select count(distinct barcode) from public.variants) = 4 and (select bool_and(barcode ~ '^DR[0-9]{8}$') from public.variants));
select test.throws('catalogue: size not configured for category rejected',
  $$select public.design_create('X1', 'Bad size', 'suit_2pc', null, null, array['Black'], array['41'], null, null)$$);
select test.throws('catalogue: duplicate design code rejected',
  $$select public.design_create('DR#2516-43', 'Dup', 'suit_2pc', null, null, array['Black'], array['48'], null, null)$$);
select public.design_create('SHOE-1', 'Oxford test', 'shoes', null, null, array['Brown'], array['42'], null, null) as design_shoe \gset
select test.ok('catalogue: unpriced variant allowed (flagged, not zero)',
  (select retail_price is null from public.variants where design_id = :'design_shoe'));
select id as v_b48 from public.variants where sku = 'DR#2516-43-BLACK-48' \gset
select id as v_b50 from public.variants where sku = 'DR#2516-43-BLACK-50' \gset
select id as v_n48 from public.variants where sku = 'DR#2516-43-NAVY-48' \gset
select id as v_n50 from public.variants where sku = 'DR#2516-43-NAVY-50' \gset

select test.as_user(:SALES, 'aal1') \gset x_
select test.ok('sales: can read catalogue and selling prices', (select count(*) from public.variants) = 5);
select test.throws('sales: cannot create designs',
  $$select public.design_create('Z9', 'Nope', 'shirt', null, null, array['White'], array['M'], 1000, 900)$$);
select test.throws('sales: cannot change prices',
  $$select public.variant_set_prices('$$ || :'v_b48' || $$', 1, 1, 'x')$$);

-- ---------------------------------------------------------------- purchase order + physical receipt
select test.as_user(:MANAGER, 'aal2') \gset x_
select (public.po_create('11111111-0000-0000-0000-000000000001', :'sup', 'USD', 2650,
  current_date + 30, jsonb_build_array(jsonb_build_object('variant_id', :'v_b48', 'qty', 50, 'unit_price_fx', 38.5)), null)) ->> 'po_id' as po \gset

select test.as_user(:STORE, 'aal1') \gset x_
select test.ok('store: cannot read purchase orders (prices) directly', (select count(*) from public.purchase_orders) = 0);
select test.ok('store: sees expected quantities without prices',
  (select qty_ordered from public.po_expected_lines(:'po')) = 50);
select test.throws('store: cannot receive more than ordered',
  $$select public.goods_receive('11111111-0000-0000-0000-0000000000ff', '$$ || :'loc_wh' || $$', null, '$$ || :'po' || $$', 'INV-1',
     jsonb_build_array(jsonb_build_object('variant_id', '$$ || :'v_b48' || $$', 'qty_expected', 50, 'qty_received', 51)), null)$$);
select test.ok('atomicity: failed receipt left no stock and no receipt',
  test.qty(:'v_b48', 'WH') = 0 and (select count(*) from public.goods_receipts) = 0);

\set RECV_PAYLOAD 'jsonb_build_array(jsonb_build_object(''variant_id'', ' :'v_b48' ', ''qty_expected'', 50, ''qty_received'', 50))'
select (public.goods_receive('11111111-0000-0000-0000-000000000002', :'loc_wh', null, :'po', 'INV-1', :RECV_PAYLOAD, null)) ->> 'receipt_id' as gr1 \gset
select test.ok('ACCEPT 1a: receive 50 into warehouse', test.qty(:'v_b48', 'WH') = 50);
select test.ok('idempotency: replay returns same receipt',
  (public.goods_receive('11111111-0000-0000-0000-000000000002', :'loc_wh', null, :'po', 'INV-1', :RECV_PAYLOAD, null)) ->> 'receipt_id' = :'gr1');
select test.ok('idempotency: replay did not add stock', test.qty(:'v_b48', 'WH') = 50);
select test.throws('idempotency: same key, different payload rejected',
  $$select public.goods_receive('11111111-0000-0000-0000-000000000002', '$$ || :'loc_wh' || $$', null, null, 'INV-9',
     jsonb_build_array(jsonb_build_object('variant_id', '$$ || :'v_b48' || $$', 'qty_received', 5)), null)$$);
select test.throws('store: cannot receive into a location not assigned',
  $$select public.goods_receive('11111111-0000-0000-0000-000000000003', '$$ || :'loc_shop' || $$', null, null, null,
     jsonb_build_array(jsonb_build_object('variant_id', '$$ || :'v_n48' || $$', 'qty_received', 5)), null)$$);
select (public.goods_receive('11111111-0000-0000-0000-000000000004', :'loc_wh', :'sup', null, 'INV-2',
  jsonb_build_array(jsonb_build_object('variant_id', :'v_b50', 'qty_received', 1),
                    jsonb_build_object('variant_id', :'v_n50', 'qty_received', 2)), null)) ->> 'receipt_id' as gr2 \gset
reset role;
select test.ok('purchase order marked received', (select status from public.purchase_orders where id = :'po') = 'received');
set role authenticated;

-- ---------------------------------------------------------------- cost approval & secrecy
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('manager: cannot approve costs by default',
  $$select public.receipt_approve_costs('$$ || :'gr1' || $$', '[]', '[]', 'qty', 'x')$$);
select test.as_user(:OWNER, 'aal2') \gset x_
select public.receipt_approve_costs(:'gr2',
  (select jsonb_agg(jsonb_build_object('line_id', id, 'unit_cost', 10000)) from public.goods_receipt_lines where receipt_id = :'gr2'),
  jsonb_build_array(jsonb_build_object('label', 'Freight', 'amount', 100)), 'qty', 'supplier invoice INV-2') \gset x_
select test.ok('landed cost: extra 100 allocated exactly (33 + 67, largest remainder)',
  (select array_agg(c.landed_alloc order by c.landed_alloc) from public.goods_receipt_costs c
     join public.goods_receipt_lines l on l.id = c.receipt_line_id where l.receipt_id = :'gr2') = array[33,67]::bigint[]);
select test.ok('landed cost: variant average includes freight',
  (select avg_cost from public.variant_costs where variant_id = :'v_n50') = 10034
  and (select avg_cost from public.variant_costs where variant_id = :'v_b50') = 10033);
select test.throws('cost approval cannot be repeated',
  $$select public.receipt_approve_costs('$$ || :'gr2' || $$', '[]', '[]', 'qty', 'again')$$);
select test.throws('cost approval requires every received line',
  $$select public.receipt_approve_costs('$$ || :'gr1' || $$', '[]', '[]', 'value', 'missing')$$);
select test.as_user(:SALES, 'aal1') \gset x_
select test.ok('sales: no buying costs visible', (select count(*) from public.variant_costs) = 0
  and (select count(*) from public.goods_receipt_costs) = 0);
select test.as_user(:STORE, 'aal1') \gset x_
select test.ok('store: no buying costs visible', (select count(*) from public.variant_costs) = 0
  and (select count(*) from public.goods_receipt_extra_costs) = 0);
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.ok('manager: no buying costs unless granted', (select count(*) from public.variant_costs) = 0);

-- ---------------------------------------------------------------- requisition → approve → dispatch → receive (ACCEPT 1)
select test.as_user(:SALES, 'aal1') \gset x_
select (public.requisition_create('22222222-0000-0000-0000-000000000001', :'loc_wh', :'loc_shop',
  jsonb_build_array(jsonb_build_object('variant_id', :'v_b48', 'qty', 10)), 'weekend stock')) ->> 'requisition_id' as req1 \gset
select test.throws('sales: cannot approve requisitions',
  $$select public.requisition_decide('$$ || :'req1' || $$', true, null, null)$$);

select test.as_user(:MANAGER, 'aal2') \gset x_
select public.requisition_decide(:'req1', true, null, 'ok') \gset x_
select test.ok('approval reserves stock (reserved is not extra stock)',
  test.qty(:'v_b48', 'WH') = 50 and test.reserved(:'v_b48', 'WH') = 10);

select test.as_user(:STORE, 'aal1') \gset x_
select test.throws('store: ad-hoc dispatch without an approved requisition rejected',
  $$select public.transfer_dispatch('33333333-0000-0000-0000-0000000000ff', null, '$$ || :'loc_wh' || $$', '$$ || :'loc_shop' || $$',
     jsonb_build_array(jsonb_build_object('variant_id', '$$ || :'v_b48' || $$', 'qty', 1)), null)$$);
select id as rl1 from public.requisition_lines where requisition_id = :'req1' \gset
\set DISP1 'jsonb_build_array(jsonb_build_object(''variant_id'', ' :'v_b48' ', ''qty'', 10, ''requisition_line_id'', ' :'rl1' '))'
select (public.transfer_dispatch('33333333-0000-0000-0000-000000000001', :'req1', null, null, :DISP1, null)) ->> 'transfer_id' as tr1 \gset
reset role;
select test.ok('ACCEPT 1b: after dispatch 10 → warehouse 40, transit 10, shop 0',
  test.qty(:'v_b48', 'WH') = 40 and test.qty(:'v_b48', 'TRANSIT') = 10 and test.qty(:'v_b48', 'SHOP') = 0);
select test.ok('dispatch released the reservation', test.reserved(:'v_b48', 'WH') = 0);
set role authenticated;
select test.as_user(:STORE, 'aal1') \gset x_
select public.transfer_dispatch('33333333-0000-0000-0000-000000000001', :'req1', null, null, :DISP1, null) \gset x_
select test.ok('ACCEPT 4a: replayed dispatch changes nothing',
  test.qty(:'v_b48', 'WH') = 40 and test.qty(:'v_b48', 'TRANSIT') = 10 and (select count(*) from public.transfers) = 1);
select test.throws('dispatch cannot exceed approved quantity',
  $$select public.transfer_dispatch('33333333-0000-0000-0000-000000000002', '$$ || :'req1' || $$', null, null,
     jsonb_build_array(jsonb_build_object('variant_id', '$$ || :'v_b48' || $$', 'qty', 1, 'requisition_line_id', '$$ || :'rl1' || $$')), null)$$);

select test.as_user(:SALES, 'aal1') \gset x_
select test.ok('shop sees incoming transfer before confirming', (select count(*) from public.transfers where status = 'in_transit') = 1);
select id as tl1 from public.transfer_lines where transfer_id = :'tr1' \gset
\set RECV1 'jsonb_build_array(jsonb_build_object(''line_id'', ' :'tl1' ', ''qty_received'', 10))'
select public.transfer_receive('44444444-0000-0000-0000-000000000001', :'tr1', :RECV1, null) \gset x_
reset role;
select test.ok('ACCEPT 1c: confirm 10 → warehouse 40, transit 0, shop 10',
  test.qty(:'v_b48', 'WH') = 40 and test.qty(:'v_b48', 'TRANSIT') = 0 and test.qty(:'v_b48', 'SHOP') = 10);
select test.ok('ACCEPT 1d: company-owned stock still 50 (transfer not double-counted)',
  test.qty(:'v_b48', 'WH') + test.qty(:'v_b48', 'SHOP') + test.qty(:'v_b48', 'TRANSIT') = 50);
set role authenticated;
select test.as_user(:SALES, 'aal1') \gset x_
select public.transfer_receive('44444444-0000-0000-0000-000000000001', :'tr1', :RECV1, null) \gset x_
select test.ok('ACCEPT 4b: replayed confirmation changes nothing', test.qty(:'v_b48', 'SHOP') = 10);
select test.throws('second confirmation with a new key rejected',
  $$select public.transfer_receive('44444444-0000-0000-0000-000000000002', '$$ || :'tr1' || $$',
     jsonb_build_array(jsonb_build_object('line_id', '$$ || :'tl1' || $$', 'qty_received', 10)), null)$$);

-- ---------------------------------------------------------------- partial receipt (ACCEPT 2)
select (public.requisition_create('22222222-0000-0000-0000-000000000002', :'loc_wh', :'loc_shop',
  jsonb_build_array(jsonb_build_object('variant_id', :'v_b48', 'qty', 10)), null)) ->> 'requisition_id' as req2 \gset
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.requisition_decide(:'req2', true, null, null) \gset x_
select test.as_user(:STORE, 'aal1') \gset x_
select id as rl2 from public.requisition_lines where requisition_id = :'req2' \gset
select (public.transfer_dispatch('33333333-0000-0000-0000-000000000003', :'req2', null, null,
  jsonb_build_array(jsonb_build_object('variant_id', :'v_b48', 'qty', 10, 'requisition_line_id', :'rl2')), null)) ->> 'transfer_id' as tr2 \gset
select test.as_user(:SALES, 'aal1') \gset x_
select id as tl2 from public.transfer_lines where transfer_id = :'tr2' \gset
select public.transfer_receive('44444444-0000-0000-0000-000000000003', :'tr2',
  jsonb_build_array(jsonb_build_object('line_id', :'tl2', 'qty_received', 8)), null) \gset x_
reset role;
select test.ok('ACCEPT 2: receive 8 of 10 → warehouse 30, shop 18, 2 still in transit',
  test.qty(:'v_b48', 'WH') = 30 and test.qty(:'v_b48', 'SHOP') = 18 and test.qty(:'v_b48', 'TRANSIT') = 2);
select test.ok('ACCEPT 2: shortage is an open discrepancy, not sold or erased',
  (select qty from public.transfer_discrepancies where status = 'open') = 2
  and (select status from public.transfers where id = :'tr2') = 'received_with_discrepancy');
select id as disc1 from public.transfer_discrepancies where status = 'open' \gset
set role authenticated;
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('discrepancy resolution needs a reason',
  $$select public.discrepancy_resolve('$$ || :'disc1' || $$', 'returned_to_source', '')$$);
select public.discrepancy_resolve(:'disc1', 'returned_to_source', 'found in store, never loaded') \gset x_
reset role;
select test.ok('discrepancy resolved back to warehouse: WH 32, transit 0',
  test.qty(:'v_b48', 'WH') = 32 and test.qty(:'v_b48', 'TRANSIT') = 0);

-- ---------------------------------------------------------------- custody rule: receiver ≠ dispatcher
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select (public.transfer_dispatch('33333333-0000-0000-0000-000000000004', null, :'loc_wh', :'loc_shop',
  jsonb_build_array(jsonb_build_object('variant_id', :'v_b48', 'qty', 1)), 'urgent')) ->> 'transfer_id' as tr3 \gset
select id as tl3 from public.transfer_lines where transfer_id = :'tr3' \gset
select test.throws('custody: dispatcher cannot confirm own receipt without reason',
  $$select public.transfer_receive('44444444-0000-0000-0000-000000000004', '$$ || :'tr3' || $$',
     jsonb_build_array(jsonb_build_object('line_id', '$$ || :'tl3' || $$', 'qty_received', 1)), null)$$);
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.transfer_receive('44444444-0000-0000-0000-000000000005', :'tr3',
  jsonb_build_array(jsonb_build_object('line_id', :'tl3', 'qty_received', 0)), null) \gset x_
select id as disc2 from public.transfer_discrepancies where status = 'open' \gset
select test.throws('discrepancy: receiver cannot resolve their own discrepancy',
  $$select public.discrepancy_resolve('$$ || :'disc2' || $$', 'written_off', 'lost')$$);
select test.as_user(:OWNER, 'aal2') \gset x_
select test.throws('discrepancy: dispatcher cannot resolve either',
  $$select public.discrepancy_resolve('$$ || :'disc2' || $$', 'written_off', 'lost')$$);
reset role;

-- ---------------------------------------------------------------- blind count with intervening movements
set role authenticated;
select test.as_user(:STORE, 'aal1') \gset x_
select public.count_start(:'loc_wh', array[:'v_b48']::uuid[]) as cnt \gset
select test.ok('count: counter cannot read system quantities (blind)', (select count(*) from public.stock_count_lines) = 0);
select test.ok('count: count sheet lists the line without system qty', (select count(*) from public.count_sheet(:'cnt')) = 1);
-- an intervening movement during the count: owner dispatches 2 more from the warehouse
select test.as_user(:OWNER, 'aal2') \gset x_
select public.transfer_dispatch('33333333-0000-0000-0000-000000000005', null, :'loc_wh', :'loc_shop',
  jsonb_build_array(jsonb_build_object('variant_id', :'v_b48', 'qty', 2)), null) \gset x_
-- warehouse was 31 at count start (1 unit still in transit from the custody test).
-- physical truth now: 29 (31 − 2). The counter finds 28 → one unit genuinely missing.
select test.as_user(:STORE, 'aal1') \gset x_
select line_id as cl from public.count_sheet(:'cnt') \gset
select public.count_submit(:'cnt', jsonb_build_array(jsonb_build_object('line_id', :'cl', 'counted_qty', 28))) \gset x_
select test.throws('count: storekeeper cannot approve own count',
  $$select public.count_decide('$$ || :'cnt' || $$', true, 'ok')$$);
-- a movement after submission must survive approval: owner dispatches 1 more
select test.as_user(:OWNER, 'aal2') \gset x_
select public.transfer_dispatch('33333333-0000-0000-0000-000000000006', null, :'loc_wh', :'loc_shop',
  jsonb_build_array(jsonb_build_object('variant_id', :'v_b48', 'qty', 1)), null) \gset x_
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.count_decide(:'cnt', true, 'variance reviewed') \gset x_
reset role;
select test.ok('count: variance is −1 (intervening dispatch not mistaken for loss)',
  (select variance from public.stock_count_lines where count_id = :'cnt') = -1);
select test.ok('count: snapshot was 31 at start', (select snapshot_qty from public.stock_count_lines where count_id = :'cnt') = 31);
select test.ok('count: adjustment applied to current balance (31 − 2 − 1 − 1 = 27)', test.qty(:'v_b48', 'WH') = 27);

-- ---------------------------------------------------------------- opening stock, negative stock, ledger
set role authenticated;
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('opening stock: manager not allowed',
  $$select public.opening_stock_post('55555555-0000-0000-0000-000000000001', '$$ || :'loc_shop' || $$',
     jsonb_build_array(jsonb_build_object('variant_id', '$$ || :'v_n48' || $$', 'qty', 5)), 'migration')$$);
select test.as_user(:OWNER, 'aal2') \gset x_
select test.throws('opening stock: reason required',
  $$select public.opening_stock_post('55555555-0000-0000-0000-000000000002', '$$ || :'loc_shop' || $$',
     jsonb_build_array(jsonb_build_object('variant_id', '$$ || :'v_n48' || $$', 'qty', 5)), '')$$);
select public.opening_stock_post('55555555-0000-0000-0000-000000000003', :'loc_shop',
  jsonb_build_array(jsonb_build_object('variant_id', :'v_n48', 'qty', 5)), 'opening count 2026-11-05') \gset x_
select test.throws('negative stock impossible: cannot dispatch more than on hand',
  $$select public.transfer_dispatch('33333333-0000-0000-0000-000000000007', null, '$$ || :'loc_shop' || $$', '$$ || :'loc_wh' || $$',
     jsonb_build_array(jsonb_build_object('variant_id', '$$ || :'v_n48' || $$', 'qty', 6)), null)$$);
reset role;
select test.ok('failed dispatch left no orphan transfer', (select count(*) from public.transfers where from_location = :'loc_shop') = 0);
select test.ok('opening stock posted at shop', test.qty(:'v_n48', 'SHOP') = 5);

set role authenticated;
select test.as_user(:SALES, 'aal1') \gset x_
select test.ok('sales: v_stock shows only own shop rows',
  (select count(*) from public.v_stock where location_kind <> 'shop') = 0 and (select count(*) from public.v_stock) > 0);
select test.throws('sales: cannot write balances directly', $$update public.stock_balances set on_hand = 999$$);
select test.throws('sales: cannot insert movements directly',
  $$insert into public.stock_movements (business_id, document_id, variant_id, location_id, qty_delta) select business_id, id, null, null, 1 from public.stock_documents limit 1$$);
reset role;

-- ---------------------------------------------------------------- CSV catalogue import
set role authenticated;
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('import: bad row rolls back the whole file',
  $$select public.catalogue_import('66666666-0000-0000-0000-000000000001', '[
     {"design_code":"IMP-1","design_name":"Import ok","category":"shirt","color":"White","size":"M","retail_price":45000},
     {"design_code":"IMP-1","design_name":"Import ok","category":"shirt","color":"White","size":"XXXL","retail_price":45000}]', 'create_only')$$);
select test.ok('import: nothing created after failed file', not exists (select 1 from public.designs where code = 'IMP-1'));
select (public.catalogue_import('66666666-0000-0000-0000-000000000002', '[
   {"design_code":"IMP-1","design_name":"Import ok","category":"shirt","color":"White","size":"M","retail_price":45000,"supplier":"Kariakoo Wholesale Test"},
   {"design_code":"IMP-1","design_name":"Import ok","category":"shirt","color":"White","size":"L","retail_price":45000,"barcode":"0004500001"},
   {"design_code":"DR#2516-43","color":"Grey","size":"52","retail_price":470000}]', 'create_only')) ->> 'variants_created' as imp_created \gset
select test.ok('import: creates designs/variants, adds to existing design', :'imp_created' = '3');
select test.ok('import: leading-zero barcode preserved', exists (select 1 from public.variants where barcode = '0004500001'));
select test.throws('import create_only: existing variant is an error',
  $$select public.catalogue_import('66666666-0000-0000-0000-000000000003', '[{"design_code":"IMP-1","color":"White","size":"M","retail_price":50000}]', 'create_only')$$);
select (public.catalogue_import('66666666-0000-0000-0000-000000000004', '[{"design_code":"IMP-1","color":"White","size":"M","retail_price":50000}]', 'update_prices')) ->> 'variants_updated' as imp_upd \gset
select test.ok('import update_prices: price updated', :'imp_upd' = '1'
  and (select retail_price from public.variants where sku = 'IMP-1-WHITE-M') = 50000);
select test.ok('import: replay with same import id is a no-op',
  (public.catalogue_import('66666666-0000-0000-0000-000000000004', '[{"design_code":"IMP-1","color":"White","size":"M","retail_price":50000}]', 'update_prices')) ->> 'variants_updated' = '1'
  and (select count(*) from public.catalogue_imports) = 2);
select test.as_user(:SALES, 'aal1') \gset x_
select test.throws('import: sales staff not allowed',
  $$select public.catalogue_import('66666666-0000-0000-0000-000000000005', '[{"design_code":"Z","design_name":"Z z","category":"shirt","color":"W","size":"M"}]', 'create_only')$$);
reset role;

-- ---------------------------------------------------------------- reports & directory
set role authenticated;
select test.as_user(:STORE, 'aal1') \gset x_
select test.ok('directory: storekeeper can see shop name for transfers', (select count(*) from public.location_directory()) >= 3);
select test.ok('report: closing equals live balance for the warehouse',
  (select closing from public.stock_period_report(:'loc_wh', now() - interval '1 day', now() + interval '1 minute') r where r.variant_id = :'v_b48') = test.qty(:'v_b48', 'WH'));
select test.ok('report: opening + in − out = closing for every row',
  not exists (select 1 from public.stock_period_report(:'loc_wh', now() - interval '1 day', now() + interval '1 minute') r
              where r.opening + r.inbound - r.outbound <> r.closing));
select test.throws('report: storekeeper cannot report on the shop',
  $$select * from public.stock_period_report('$$ || :'loc_shop' || $$', now() - interval '1 day', now())$$);
reset role;

select test.ok('LEDGER: every balance equals the sum of its movements', test.ledger_consistent());
select test.ok('LEDGER: no negative stock and reserved ≤ on_hand',
  not exists (select 1 from public.stock_balances where on_hand < 0 or reserved < 0 or reserved > on_hand));

\ir _report.sql
