-- Milestone D database acceptance tests: wholesale customers & consignment.
\set ON_ERROR_STOP 1
\set QUIET 1
\pset tuples_only on
\pset format unaligned

\ir _framework.sql

create function test.as_user(p_uid uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims', test.claims(p_uid, p_aal), false); select null::void;
$$;
create function test.qty(p_variant uuid, p_loc_code text) returns int language sql security definer as $$
  select coalesce((select b.on_hand from public.stock_balances b join public.locations l on l.id = b.location_id
                   where b.variant_id = p_variant and l.code = p_loc_code), 0)
$$;
create function test.partner_qty(p_variant uuid, p_partner uuid) returns int language sql security definer as $$
  select coalesce((select b.on_hand from public.stock_balances b join public.customers c on c.partner_location_id = b.location_id
                   where b.variant_id = p_variant and c.id = p_partner), 0)
$$;
create function test.acct(p_code text) returns bigint language sql security definer as $$
  select coalesce(sum(debit - credit), 0)::bigint from public.journal_lines where account_code = p_code
$$;
create function test.all_balanced() returns boolean language sql security definer as $$
  select not exists (select 1 from public.journal_lines group by entry_id having sum(debit) <> sum(credit))
$$;
create function test.ledger_consistent() returns boolean language sql security definer as $$
  select not exists (select 1 from public.stock_balances b
    where b.on_hand <> coalesce((select sum(m.qty_delta) from public.stock_movements m where m.variant_id = b.variant_id and m.location_id = b.location_id), 0))
$$;
-- partner custody: held per dispatch lines == partner location on-hand, for every partner/variant
create function test.custody_consistent() returns boolean language sql security definer as $$
  select not exists (
    select 1 from public.customers c join public.consignment_dispatch_lines dl on dl.partner_id = c.id
    group by c.id, c.partner_location_id, dl.variant_id
    having sum(dl.qty - dl.qty_sold - dl.qty_returned - dl.qty_lost)
           <> coalesce((select on_hand from public.stock_balances b where b.location_id = c.partner_location_id and b.variant_id = dl.variant_id), 0))
$$;
create function test.today() returns date language sql as $$ select (now() at time zone 'Africa/Dar_es_Salaam')::date $$;
grant execute on all functions in schema test to authenticated, service_role;

-- ---------------------------------------------------------------- fixture
insert into auth.users (id, phone) values
  ('00000000-0000-0000-0000-0000000000d1', '+255740000001'), ('00000000-0000-0000-0000-0000000000d2', '+255740000002'),
  ('00000000-0000-0000-0000-0000000000d3', '+255740000003'), ('00000000-0000-0000-0000-0000000000d4', '+255740000004');
\set OWNER   '''00000000-0000-0000-0000-0000000000d1'''
\set MANAGER '''00000000-0000-0000-0000-0000000000d2'''
\set SALES   '''00000000-0000-0000-0000-0000000000d3'''
\set STORE   '''00000000-0000-0000-0000-0000000000d4'''
set role service_role;
select public.setup_create_business('DIROMA', 'Spirit of Fashion', 'FIX-D') \gset x_
select public.setup_finalize_owner('FIX-D', :OWNER, '+255740000001', 'Owner D') \gset x_
reset role;
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.location_create('WH', 'Store', 'warehouse') as loc_wh \gset
select public.location_create('SHOP', 'Shop', 'shop') as loc_shop \gset
select public.team_invite('+255740000002', 'Manager D', 'manager', '{}', null) as m_mgr \gset
select public.team_invite('+255740000003', 'Sales D', 'sales_staff', array[:'loc_shop']::uuid[], null) as m_sales \gset
select public.team_invite('+255740000004', 'Store D', 'storekeeper', array[:'loc_wh']::uuid[], null) as m_store \gset
select public.team_set_locations(:'m_mgr', true, '{}', 'all') \gset x_
reset role;
set role service_role;
select public.team_attach_auth_user(:'m_mgr', :MANAGER, 'Q1') \gset x_
select public.team_attach_auth_user(:'m_sales', :SALES, 'Q2') \gset x_
select public.team_attach_auth_user(:'m_store', :STORE, 'Q3') \gset x_
select public.activation_finalize('+255740000002', 'Q1') \gset x_
select public.activation_finalize('+255740000003', 'Q2') \gset x_
select public.activation_finalize('+255740000004', 'Q3') \gset x_
reset role;
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.design_create('SUIT-D', 'Suit D', 'suit_2pc', null, null, array['Black'], array['48'], 450000, 380000) as d_suit \gset
select id as v48 from public.variants where sku = 'SUIT-D-BLACK-48' \gset
select test.as_user(:STORE, 'aal1') \gset x_
select (public.goods_receive('a0000000-0000-0000-0000-0000000000d1', :'loc_wh', null, null, 'INV-D',
  jsonb_build_array(jsonb_build_object('variant_id', :'v48', 'qty_received', 20)), null)) ->> 'receipt_id' as gr \gset
select test.as_user(:OWNER, 'aal2') \gset x_
select public.receipt_approve_costs(:'gr', (select jsonb_agg(jsonb_build_object('line_id', id, 'unit_cost', 200000)) from public.goods_receipt_lines where receipt_id = :'gr'),
  '[]', 'qty', 'invoice') \gset x_
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.customer_save(null, 'Mwanza Partner Test', '+255750000001', 'wholesale', 5000000, 14, 'Mwanza', null, 'referral') as partner \gset
select public.customer_save(null, 'Retail Person Test', '+255750000002', 'retail', 0, 0, null, null, null) as retail \gset
reset role;
select test.acct('4000') as rev0 \gset
select test.acct('1100') as ar0 \gset
set role authenticated;

-- ---------------------------------------------------------------- partner setup & order
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('partner: retail customer cannot become a consignment partner', $$select public.partner_configure('$$ || :'retail' || $$', true, 7)$$);
select test.throws('order: consignment must be enabled first',
  $$select public.consignment_order_create(gen_random_uuid(), '$$ || :'partner' || $$', '$$ || :'loc_wh' || $$', '[{"variant_id":"$$ || :'v48' || $$","qty":1}]', null)$$);
select public.partner_configure(:'partner', true, 2) as partner_loc \gset
reset role;
select test.ok('partner: own custody location of kind partner', (select kind from public.locations where id = :'partner_loc') = 'partner');
set role authenticated;
select test.as_user(:SALES, 'aal1') \gset x_
select test.throws('sales staff cannot create consignment orders',
  $$select public.consignment_order_create(gen_random_uuid(), '$$ || :'partner' || $$', '$$ || :'loc_wh' || $$', '[{"variant_id":"$$ || :'v48' || $$","qty":1}]', null)$$);
select test.throws('sales staff cannot see partner overview', $$select * from public.partner_overview(null)$$);
select test.as_user(:MANAGER, 'aal2') \gset x_
select (public.consignment_order_create('b1000000-0000-0000-0000-000000000001', :'partner', :'loc_wh',
  jsonb_build_array(jsonb_build_object('variant_id', :'v48', 'qty', 10)), 'first consignment')) ->> 'order_id' as ord \gset
reset role;
select test.ok('order reserves stock at the Store (20 on hand, 10 reserved)',
  test.qty(:'v48', 'WH') = 20 and (select reserved from public.stock_balances b join public.locations l on l.id = b.location_id where l.code = 'WH') = 10);
select test.ok('order line uses the wholesale price as agreed price', (select unit_price from public.consignment_order_lines where order_id = :'ord') = 380000);
set role authenticated;

-- ---------------------------------------------------------------- dispatch: custody moves, no revenue, no debt
select id as ol from public.consignment_order_lines where order_id = :'ord' \gset
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('dispatch: order creator cannot also dispatch',
  $$select public.consignment_dispatch(gen_random_uuid(), '$$ || :'ord' || $$', '[{"order_line_id":"$$ || :'ol' || $$","qty":10}]', 'Partner', null, null)$$);
select test.as_user(:STORE, 'aal1') \gset x_
select test.throws('dispatch: recipient required',
  $$select public.consignment_dispatch(gen_random_uuid(), '$$ || :'ord' || $$', '[{"order_line_id":"$$ || :'ol' || $$","qty":10}]', ' ', null, null)$$);
\set DSP '''[{"order_line_id":"' :ol '","qty":10}]'''
select public.consignment_dispatch('b2000000-0000-0000-0000-000000000001', :'ord', :DSP::jsonb, 'Juma (partner)', 'signed delivery note', null) \gset x_
select public.consignment_dispatch('b2000000-0000-0000-0000-000000000001', :'ord', :DSP::jsonb, 'Juma (partner)', 'signed delivery note', null) \gset x_
reset role;
select test.ok('ACCEPT: dispatch 10 → Store 10, partner holds 10, reservation released',
  test.qty(:'v48', 'WH') = 10 and test.partner_qty(:'v48', :'partner') = 10
  and (select reserved from public.stock_balances b join public.locations l on l.id = b.location_id where l.code = 'WH') = 0);
select test.ok('ACCEPT: consignment dispatch creates no sale, revenue or debt',
  test.acct('4000') = :rev0 and test.acct('1100') = :ar0 and (select count(*) from public.sales) = 0);
select test.ok('replayed dispatch changed nothing', (select count(*) from public.consignment_dispatches) = 1);
select test.ok('partner stock is not saleable', (select available from public.v_stock where location_id = :'partner_loc') = 0);
set role authenticated;

-- ---------------------------------------------------------------- settlement report: 6 sold, 2 returned → 2 held
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('report: cannot report more than the partner holds',
  $$select public.consignment_report(gen_random_uuid(), '$$ || :'partner' || $$', current_date, '[{"variant_id":"$$ || :'v48' || $$","sold":9,"returned":2}]', null)$$);
\set REP '''[{"variant_id":"' :v48 '","sold":6,"returned":2}]'''
select (public.consignment_report('b3000000-0000-0000-0000-000000000001', :'partner', test.today(), :REP::jsonb, 'weekly call')) as rep \gset
select public.consignment_report('b3000000-0000-0000-0000-000000000001', :'partner', test.today(), :REP::jsonb, 'weekly call') \gset x_
reset role;
select :'rep'::jsonb ->> 'sale_id' as inv1 \gset
select test.ok('ACCEPT: 10 dispatched / 6 sold / 2 returned leaves 2 held', test.partner_qty(:'v48', :'partner') = 2);
select test.ok('settlement deducts partner custody only; Store stays 10', test.qty(:'v48', 'WH') = 10);
select test.ok('returned goods go to inspection, not saleable stock', test.qty(:'v48', 'INSPECT') = 2);
select test.ok('sold units invoiced at the agreed price: 6 × 380,000 = 2,280,000',
  (select total from public.sales where id = :'inv1') = 2280000 and test.acct('4000') - :rev0 = -2280000 and test.acct('1100') - :ar0 = 2280000);
select test.ok('COGS on settlement: 6 × 200,000', test.acct('5000') = 1200000);
select test.ok('replayed report did not invoice twice', (select count(*) from public.sales) = 1 and (select count(*) from public.consignment_reports) = 1);
set role authenticated;
select test.as_user(:MANAGER, 'aal2') \gset x_
select * from public.partner_overview(:'partner') \gset po_
reset role;
select test.ok('overview: dispatched 10, sold 6, returned 2, held 2, invoiced 2,280,000, outstanding 2,280,000',
  :po_dispatched = 10 and :po_sold = 6 and :po_returned = 2 and :po_held = 2 and :po_invoiced = 2280000 and :po_outstanding = 2280000);
select test.ok('overview: held goods valued at agreed price (2 × 380,000), not counted as money owed', :po_held_value = 760000);
select test.ok('overview: next update due = report date + 2 days', :'po_next_update_due'::date = test.today() + 2);
set role authenticated;

-- ---------------------------------------------------------------- losses need an independent decision
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.consignment_report('b3000000-0000-0000-0000-000000000002', :'partner', test.today(),
  ('[{"variant_id":"' || :'v48' || '","lost":1}]')::jsonb, 'partner says one stolen') \gset x_
select id as loss from public.consignment_losses where status = 'pending' \gset
select test.throws('loss: reporter cannot decide own report', $$select public.consignment_loss_decide('$$ || :'loss' || $$', 'write_off', 'ok')$$);
select test.throws('loss: pending loss blocks double reporting of the same unit',
  $$select public.consignment_report(gen_random_uuid(), '$$ || :'partner' || $$', current_date, '[{"variant_id":"$$ || :'v48' || $$","sold":2}]', null)$$);
reset role;
select test.ok('loss pending: goods still counted as held (2)', test.partner_qty(:'v48', :'partner') = 2);
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.consignment_loss_decide(:'loss', 'write_off', 'police report seen') \gset x_
reset role;
select test.ok('loss written off: partner holds 1, stock loss 200,000 at cost', test.partner_qty(:'v48', :'partner') = 1 and test.acct('6200') = 200000);
set role authenticated;

-- ---------------------------------------------------------------- payments, returns of sold goods, statement
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('manager cannot create money accounts', $$select public.money_account_create('BANK', 'CRDB', 'bank', null)$$);
select test.as_user(:OWNER, 'aal2') \gset x_
select public.money_account_create('BANK2', 'NMB', 'bank', null) as bank2 \gset
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.payment_collect('b4000000-0000-0000-0000-000000000001', :'partner', :'bank2', 1000000, 'NMB-778', null, null) \gset x_
select id as invline from public.sale_lines where sale_id = :'inv1' \gset
select (public.return_request('b5000000-0000-0000-0000-000000000001', :'inv1',
  jsonb_build_array(jsonb_build_object('sale_line_id', :'invline', 'qty', 1)), 'customer of partner returned faulty unit', 'credit')) ->> 'return_id' as ret \gset
select test.throws('return of sold consignment goods needs another approver', $$select public.return_decide('$$ || :'ret' || $$', true, 'ok')$$);
select test.as_user(:OWNER, 'aal2') \gset x_
select public.return_decide(:'ret', true, 'checked') \gset x_
select test.as_user(:MANAGER, 'aal2') \gset x_
select * from public.partner_overview(:'partner') \gset po2_
reset role;
select test.ok('payment 1,000,000 allocated; return 380,000 reduces open invoice → outstanding 900,000',
  :po2_outstanding = 900000 and :po2_paid = 1000000);
select test.ok('previously sold goods returned later enter inspection (2 + 1)', test.qty(:'v48', 'INSPECT') = 3);
set role authenticated;
select test.as_user(:MANAGER, 'aal2') \gset x_
select balance as stmt_close from public.customer_statement(:'partner', test.today() - 30, test.today()) order by is_opening desc, entry_date, balance desc limit 1 offset (select count(*) - 1 from public.customer_statement(:'partner', test.today() - 30, test.today())) \gset
reset role;
select test.ok('statement closing balance equals receivable − credit (900,000)',
  :stmt_close = public._customer_receivable(:'partner') - public._customer_credit(:'partner') and :stmt_close = 900000);
set role authenticated;

-- ---------------------------------------------------------------- outright wholesale sale (mode A)
select test.as_user(:MANAGER, 'aal2') \gset x_
\set WS '''[{"variant_id":"' :v48 '","qty":3}]'''
select (public.wholesale_sale_post('b6000000-0000-0000-0000-000000000001', :'partner', :'loc_wh', :WS::jsonb, 'direct order', null)) ->> 'status' as ws_status \gset
reset role;
select test.ok('mode A: wholesale sale from Store within credit limit posts at wholesale price',
  :'ws_status' = 'posted' and test.qty(:'v48', 'WH') = 7 and (select total from public.sales where note = 'direct order') = 1140000);
set role authenticated;
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.customer_save(:'partner', 'Mwanza Partner Test', '+255750000001', 'wholesale', 2000000, 14, 'Mwanza', null, 'referral') \gset x_
select (public.wholesale_sale_post(gen_random_uuid(), :'partner', :'loc_wh', :WS::jsonb, 'over limit', null)) as ws2 \gset
select test.ok('mode A: above credit limit needs approval (nothing posted)',
  :'ws2'::jsonb ->> 'status' = 'approval_required' and (select count(*) from public.sales where note = 'over limit') = 0);
select test.as_user(:OWNER, 'aal2') \gset x_
select public.approval_decide((:'ws2'::jsonb ->> 'approval_id')::uuid, true, 'good payer') \gset x_
select test.as_user(:MANAGER, 'aal2') \gset x_
select (public.wholesale_sale_post(gen_random_uuid(), :'partner', :'loc_wh', :WS::jsonb, 'over limit', (:'ws2'::jsonb ->> 'approval_id')::uuid)) ->> 'status' as ws2b \gset
select test.ok('mode A: posts after independent approval of the exact request', :'ws2b' = 'posted');

-- reminders
select public.consignment_reminder_log(:'partner', 'whatsapp', 'weekly update request') \gset x_
select test.ok('reminder logged against partner', (select last_reminder is not null from public.partner_overview(:'partner')));

-- ---------------------------------------------------------------- secrecy & integrity
select test.as_user(:STORE, 'aal1') \gset x_
select test.ok('storekeeper sees orders from own Store but not settlement reports or losses',
  (select count(*) from public.consignment_orders) = 1 and (select count(*) from public.consignment_reports) = 0
  and (select count(*) from public.consignment_losses) = 0);
select test.as_user(:SALES, 'aal1') \gset x_
select test.ok('sales staff see no consignment data', (select count(*) from public.consignment_orders) = 0
  and (select count(*) from public.consignment_dispatch_lines) = 0);
select test.ok('sales staff (who collect payments) can read a customer statement',
  (select count(*) from public.customer_statement(:'partner', current_date - 30, current_date)) > 1);
select test.throws('sales staff cannot see what a partner holds on consignment', $$select * from public.partner_holdings('$$ || :'partner' || $$')$$);
reset role;
select test.ok('CUSTODY: partner-held quantity equals partner location stock', test.custody_consistent());
select test.ok('CUSTODY: every dispatch line accounts for all its units',
  not exists (select 1 from public.consignment_dispatch_lines where qty_sold + qty_returned + qty_lost + qty_pending_loss > qty));
select test.ok('LEDGER: stock balances equal movements', test.ledger_consistent());
select test.ok('JOURNAL: every entry balances', test.all_balanced());

\ir _report.sql
