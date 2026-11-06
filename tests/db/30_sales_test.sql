-- Milestone C database acceptance tests: POS, payments, approvals, credit, returns, expenses, money, shifts, journal.
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
create function test.acct(p_code text) returns bigint language sql security definer as $$
  select coalesce(sum(debit - credit), 0)::bigint from public.journal_lines where account_code = p_code
$$;
create function test.money(p_code text) returns bigint language sql security definer as $$
  select coalesce(sum(jl.debit - jl.credit), 0)::bigint from public.journal_lines jl join public.money_accounts a on a.id = jl.money_account_id
  where jl.account_code = '1000' and a.code = p_code
$$;
create function test.all_balanced() returns boolean language sql security definer as $$
  select not exists (select 1 from public.journal_lines group by entry_id having sum(debit) <> sum(credit))
     and (select sum(debit) = sum(credit) from public.journal_lines)
$$;
create function test.today() returns date language sql as $$ select (now() at time zone 'Africa/Dar_es_Salaam')::date $$;
grant execute on all functions in schema test to authenticated, service_role;

-- ---------------------------------------------------------------- fixture
insert into auth.users (id, phone) values
  ('00000000-0000-0000-0000-0000000000c1', '+255720000001'), ('00000000-0000-0000-0000-0000000000c2', '+255720000002'),
  ('00000000-0000-0000-0000-0000000000c3', '+255720000003'), ('00000000-0000-0000-0000-0000000000c4', '+255720000004');
\set OWNER   '''00000000-0000-0000-0000-0000000000c1'''
\set MANAGER '''00000000-0000-0000-0000-0000000000c2'''
\set SALES   '''00000000-0000-0000-0000-0000000000c3'''
\set STORE   '''00000000-0000-0000-0000-0000000000c4'''

set role service_role;
select public.setup_create_business('DIROMA', 'Spirit of Fashion', 'FIX-C') \gset x_
select public.setup_finalize_owner('FIX-C', :OWNER, '+255720000001', 'Owner C') \gset x_
reset role;
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.location_create('WH', 'Store', 'warehouse') as loc_wh \gset
select public.location_create('SHOP', 'Shop', 'shop') as loc_shop \gset
select public.team_invite('+255720000002', 'Manager C', 'manager', '{}', null) as m_mgr \gset
select public.team_invite('+255720000003', 'Sales C', 'sales_staff', array[:'loc_shop']::uuid[], null) as m_sales \gset
select public.team_invite('+255720000004', 'Store C', 'storekeeper', array[:'loc_wh']::uuid[], null) as m_store \gset
select public.team_set_locations(:'m_mgr', true, '{}', 'all') \gset x_
reset role;
set role service_role;
select public.team_attach_auth_user(:'m_mgr', :MANAGER, 'K1') \gset x_
select public.team_attach_auth_user(:'m_sales', :SALES, 'K2') \gset x_
select public.team_attach_auth_user(:'m_store', :STORE, 'K3') \gset x_
select public.activation_finalize('+255720000002', 'K1') \gset x_
select public.activation_finalize('+255720000003', 'K2') \gset x_
select public.activation_finalize('+255720000004', 'K3') \gset x_
reset role;

set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.design_create('SUIT-C', 'Suit C', 'suit_2pc', null, null, array['Black'], array['48','50'], 450000, 380000) as d_suit \gset
select public.design_create('TIE-C', 'Tie C', 'accessory', null, null, array['Red'], array['ONE'], 30000, null) as d_tie \gset
select public.design_create('NOPRICE', 'Unpriced', 'shirt', null, null, array['White'], array['M'], null, null) as d_np \gset
select id as v48 from public.variants where sku = 'SUIT-C-BLACK-48' \gset
select id as v50 from public.variants where sku = 'SUIT-C-BLACK-50' \gset
select id as vtie from public.variants where sku = 'TIE-C-RED-ONE' \gset
select id as vnp from public.variants where sku = 'NOPRICE-WHITE-M' \gset
select test.as_user(:STORE, 'aal1') \gset x_
select (public.goods_receive('a0000000-0000-0000-0000-000000000001', :'loc_wh', null, null, 'INV-C',
  jsonb_build_array(jsonb_build_object('variant_id', :'v48', 'qty_received', 10)), null)) ->> 'receipt_id' as gr \gset
select test.as_user(:OWNER, 'aal2') \gset x_
select public.receipt_approve_costs(:'gr', (select jsonb_agg(jsonb_build_object('line_id', id, 'unit_cost', 200000)) from public.goods_receipt_lines where receipt_id = :'gr'),
  '[]', 'qty', 'invoice') \gset x_
select public.opening_stock_post('a0000000-0000-0000-0000-000000000002', :'loc_shop', jsonb_build_array(
  jsonb_build_object('variant_id', :'v48', 'qty', 5), jsonb_build_object('variant_id', :'vtie', 'qty', 3),
  jsonb_build_object('variant_id', :'vnp', 'qty', 1)), 'opening count') \gset x_
select public.money_account_create('CASH-SHOP', 'Shop drawer', 'cash', :'loc_shop') as acc_cash \gset
select public.money_account_create('MPESA', 'M-Pesa Lipa Namba', 'mobile', null) as acc_mpesa \gset
select public.money_account_create('BANK', 'CRDB', 'bank', null) as acc_bank \gset
select public.money_account_create('CASH-WH', 'Store petty cash', 'cash', :'loc_wh') as acc_cash_wh \gset
select public.money_account_opening(:'acc_bank', 1000000, test.today(), 'bank statement 2026-11-05') \gset x_
select test.throws('money: opening balance only once', $$select public.money_account_opening('$$ || :'acc_bank' || $$', 5, current_date, 'again')$$);
reset role;
select test.ok('GL: approved receipt costs posted to inventory and supplier payables', test.acct('1200') = 2000000 and test.acct('2100') = -2000000);
set role authenticated;

-- customers
select test.as_user(:SALES, 'aal1') \gset x_
select public.customer_save(null, 'Retail Customer Test', '+255730000001', 'retail', 0, 0, 'Dar', null, 'walk-in') as cust_r \gset
select test.throws('customers: sales staff cannot grant credit', $$select public.customer_save(null, 'Credit Seeker', null, 'retail', 500000, 30, null, null, null)$$);
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.customer_save(null, 'Partner Wholesale Test', '+255730000002', 'wholesale', 2000000, 14, 'Mwanza', null, 'referral') as cust_w \gset

-- ---------------------------------------------------------------- shift & simple sale
select test.as_user(:SALES, 'aal1') \gset x_
select test.throws('pos: cannot sell without an open shift',
  $$select public.sale_post(gen_random_uuid(), '$$ || :'loc_shop' || $$', gen_random_uuid(), null, 'retail',
     '[{"variant_id":"$$ || :'v48' || $$","qty":1}]', 0, 'collected', '[]', null, null, null, null)$$);
select test.throws('shift: must use the shop''s cash drawer', $$select public.shift_open('$$ || :'loc_shop' || $$', '$$ || :'acc_mpesa' || $$', 0)$$);
select public.shift_open(:'loc_shop', :'acc_cash', 50000) as shift \gset
select test.throws('shift: only one open shift per person', $$select public.shift_open('$$ || :'loc_shop' || $$', '$$ || :'acc_cash' || $$', 0)$$);

\set S3 '''[{"variant_id":"' :v48 '","qty":1}]'''
select (public.sale_post('b0000000-0000-0000-0000-000000000003', :'loc_shop', :'shift', null, 'retail', :S3::jsonb, 0, 'collected',
  jsonb_build_array(jsonb_build_object('account_id', :'acc_cash', 'amount', 450000)), null, 'walk-in', null, null)) ->> 'sale_id' as sale3 \gset
select test.ok('sale: posted, paid, stock reduced', (select payment_status from public.sales where id = :'sale3') = 'paid' and test.qty(:'v48', 'SHOP') = 4);
select test.ok('sale: server priced the line from the catalogue', (select list_price from public.sale_lines where sale_id = :'sale3') = 450000);
select test.ok('idempotency: retried sale returns the same receipt',
  (public.sale_post('b0000000-0000-0000-0000-000000000003', :'loc_shop', :'shift', null, 'retail', :S3::jsonb, 0, 'collected',
    jsonb_build_array(jsonb_build_object('account_id', :'acc_cash', 'amount', 450000)), null, 'walk-in', null, null)) ->> 'sale_id' = :'sale3');
select test.ok('idempotency: no second stock deduction or sale', test.qty(:'v48', 'SHOP') = 4 and (select count(*) from public.sales) = 1);
select test.throws('pos: variant without a price cannot be sold',
  $$select public.sale_post(gen_random_uuid(), '$$ || :'loc_shop' || $$', '$$ || :'shift' || $$', null, 'retail',
     '[{"variant_id":"$$ || :'vnp' || $$","qty":1}]', 0, 'collected', '[]', null, null, null, null)$$);
select test.throws('pos: cash must go to own shift drawer (not another cash box)',
  $$select public.sale_post(gen_random_uuid(), '$$ || :'loc_shop' || $$', '$$ || :'shift' || $$', null, 'retail',
     '[{"variant_id":"$$ || :'v48' || $$","qty":1}]', 0, 'collected', '[{"account_id":"$$ || :'acc_cash_wh' || $$","amount":450000}]', null, null, null, null)$$);
select test.throws('pos: payments may not exceed total',
  $$select public.sale_post(gen_random_uuid(), '$$ || :'loc_shop' || $$', '$$ || :'shift' || $$', null, 'retail',
     '[{"variant_id":"$$ || :'v48' || $$","qty":1}]', 0, 'collected', '[{"account_id":"$$ || :'acc_cash' || $$","amount":500000}]', null, null, null, null)$$);

-- ---------------------------------------------------------------- discount approval bound to the request
\set S5 '''[{"variant_id":"' :v48 '","qty":1,"discount":45000}]'''
select (public.sale_post('b0000000-0000-0000-0000-000000000005', :'loc_shop', :'shift', null, 'retail', :S5::jsonb, 0, 'collected',
  jsonb_build_array(jsonb_build_object('account_id', :'acc_cash', 'amount', 405000)), null, null, null, null)) as r5 \gset
select test.ok('discount 10% > 5% limit: approval required, nothing posted',
  (:'r5'::jsonb ->> 'status') = 'approval_required' and test.qty(:'v48', 'SHOP') = 4);
select :'r5'::jsonb ->> 'approval_id' as appr5 \gset
select test.throws('approval: requester cannot approve own request', $$select public.approval_decide('$$ || :'appr5' || $$', true, 'ok')$$);
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.approval_decide(:'appr5', true, 'loyal customer') \gset x_
select test.as_user(:SALES, 'aal1') \gset x_
select test.throws('approval: does not cover a changed request (qty 2)',
  $$select public.sale_post(gen_random_uuid(), '$$ || :'loc_shop' || $$', '$$ || :'shift' || $$', null, 'retail',
     '[{"variant_id":"$$ || :'v48' || $$","qty":2,"discount":45000}]', 0, 'collected', '[{"account_id":"$$ || :'acc_cash' || $$","amount":405000}]', null, null, null, '$$ || :'appr5' || $$')$$);
select (public.sale_post('b0000000-0000-0000-0000-000000000006', :'loc_shop', :'shift', null, 'retail', :S5::jsonb, 0, 'collected',
  jsonb_build_array(jsonb_build_object('account_id', :'acc_cash', 'amount', 405000)), null, null, null, :'appr5')) ->> 'status' as st5 \gset
select test.ok('discount: posts after independent approval', :'st5' = 'posted' and test.qty(:'v48', 'SHOP') = 3);
select test.throws('approval: cannot be reused for another sale',
  $$select public.sale_post(gen_random_uuid(), '$$ || :'loc_shop' || $$', '$$ || :'shift' || $$', null, 'retail',
     '$$ || :S5 || $$', 0, 'collected', '[{"account_id":"$$ || :'acc_cash' || $$","amount":405000}]', null, null, null, '$$ || :'appr5' || $$')$$);
select (public.sale_post(gen_random_uuid(), :'loc_shop', :'shift', null, 'retail',
  ('[{"variant_id":"' || :'v48' || '","qty":1,"discount":90000}]')::jsonb, 0, 'collected',
  jsonb_build_array(jsonb_build_object('account_id', :'acc_cash', 'amount', 360000)), null, null, null, null)) ->> 'approval_id' as appr20 \gset
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('approval: 20% discount is above the manager''s 15% limit', $$select public.approval_decide('$$ || :'appr20' || $$', true, 'ok')$$);

-- ---------------------------------------------------------------- split payment, walk-in credit, customer credit limit
select test.as_user(:SALES, 'aal1') \gset x_
select (public.sale_post('b0000000-0000-0000-0000-000000000007', :'loc_shop', :'shift', null, 'retail', :S3::jsonb, 0, 'collected',
  jsonb_build_array(jsonb_build_object('account_id', :'acc_cash', 'amount', 100000),
                    jsonb_build_object('account_id', :'acc_mpesa', 'amount', 350000, 'provider_ref', 'QK12AB34')), null, null, null, null)) ->> 'sale_id' as sale6 \gset
select test.ok('split payment: two payments, sale paid', (select count(*) from public.payments p join public.sale_settlements s on s.payment_id = p.id where s.sale_id = :'sale6') = 2
  and (select payment_status from public.sales where id = :'sale6') = 'paid');
select test.ok('mobile money marked as manually entered, not provider-verified',
  (select verification from public.payments where provider_ref = 'QK12AB34') = 'manual');
select test.throws('walk-in sale cannot be left unpaid',
  $$select public.sale_post(gen_random_uuid(), '$$ || :'loc_shop' || $$', '$$ || :'shift' || $$', null, 'retail', '$$ || :S3 || $$', 0, 'collected',
     '[{"account_id":"$$ || :'acc_cash' || $$","amount":100000}]', null, null, null, null)$$);
select test.ok('credit beyond customer limit needs approval',
  (public.sale_post(gen_random_uuid(), :'loc_shop', :'shift', :'cust_r', 'retail', :S3::jsonb, 0, 'collected', '[]', null, null, null, null)) ->> 'status' = 'approval_required');
select test.throws('wholesale price needs a wholesale customer',
  $$select public.sale_post(gen_random_uuid(), '$$ || :'loc_shop' || $$', '$$ || :'shift' || $$', '$$ || :'cust_r' || $$', 'wholesale', '$$ || :S3 || $$', 0, 'collected', '[]', null, null, null, null)$$);
select (public.sale_post('b0000000-0000-0000-0000-000000000008', :'loc_shop', :'shift', :'cust_w', 'wholesale',
  ('[{"variant_id":"' || :'v48' || '","qty":2}]')::jsonb, 0, 'awaiting_delivery',
  jsonb_build_array(jsonb_build_object('account_id', :'acc_mpesa', 'amount', 160000)), null, 'referral', null, null)) ->> 'sale_id' as sale8 \gset
select test.ok('wholesale credit sale within limit: wholesale price, partial, receivable 600,000',
  (select total from public.sales where id = :'sale8') = 760000 and (select payment_status from public.sales where id = :'sale8') = 'partial'
  and test.qty(:'v48', 'SHOP') = 0);
select test.throws('no negative stock: cannot sell what the shop does not have',
  $$select public.sale_post(gen_random_uuid(), '$$ || :'loc_shop' || $$', '$$ || :'shift' || $$', null, 'retail', '$$ || :S3 || $$', 0, 'collected',
     '[{"account_id":"$$ || :'acc_cash' || $$","amount":450000}]', null, null, null, null)$$);
select public.sale_set_fulfillment(:'sale8', 'failed_delivery', 'customer absent') \gset x_
select test.ok('failed delivery does not put goods back into saleable stock', test.qty(:'v48', 'SHOP') = 0);

-- ---------------------------------------------------------------- backdated manual entry
\set S9 '''[{"variant_id":"' :vtie '","qty":1}]'''
select (public.sale_post('b0000000-0000-0000-0000-000000000009', :'loc_shop', :'shift', null, 'retail', :S9::jsonb, 0, 'collected',
  jsonb_build_array(jsonb_build_object('account_id', :'acc_mpesa', 'amount', 30000)), now() - interval '2 days', null, 'missed sale', null)) as r9 \gset
select test.ok('backdated entry requires approval', :'r9'::jsonb ->> 'status' = 'approval_required'
  and 'backdate' = any (array(select jsonb_array_elements_text(:'r9'::jsonb -> 'reasons'))));
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.approval_decide((:'r9'::jsonb ->> 'approval_id')::uuid, true, 'paper receipt seen') \gset x_
select test.as_user(:SALES, 'aal1') \gset x_
select (public.sale_post('b0000000-0000-0000-0000-000000000010', :'loc_shop', :'shift', null, 'retail', :S9::jsonb, 0, 'collected',
  jsonb_build_array(jsonb_build_object('account_id', :'acc_mpesa', 'amount', 30000)), (select (summary->>'sold_at')::timestamptz from public.approval_requests where id = (:'r9'::jsonb ->> 'approval_id')::uuid),
  null, 'missed sale', (:'r9'::jsonb ->> 'approval_id')::uuid)) ->> 'sale_id' as sale9 \gset
reset role;
select test.ok('backdated sale keeps occurrence time and entry time separately',
  (select sold_at < entered_at - interval '1 day' from public.sales where id = :'sale9'));
select test.ok('backdated sale journal dated on the sale date',
  (select entry_date from public.journal_entries where source_type = 'sale' and source_id = :'sale9') = test.today() - 2);
select test.ok('unknown cost flagged (tie has no approved cost)',
  (select bool_and(not c.cost_known) from public.sale_line_costs c join public.sale_lines l on l.id = c.sale_line_id where l.sale_id = :'sale9'));
set role authenticated;

-- ---------------------------------------------------------------- return applied to an open credit sale
select test.as_user(:SALES, 'aal1') \gset x_
select id as sl8 from public.sale_lines where sale_id = :'sale8' \gset
select (public.return_request('c0000000-0000-0000-0000-000000000001', :'sale8',
  jsonb_build_array(jsonb_build_object('sale_line_id', :'sl8', 'qty', 1)), 'wrong size', 'credit')) ->> 'return_id' as ret8 \gset
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.return_decide(:'ret8', true, 'checked') \gset x_
reset role;
select test.ok('return on credit sale reduces that sale''s balance first (600,000 → 220,000)',
  public._sale_balance(:'sale8') = 220000 and (select credit_amount from public.sale_returns where id = :'ret8') = 0);
set role authenticated;

-- ---------------------------------------------------------------- collections: old debt is not revenue; overpayment → credit
select test.as_user(:SALES, 'aal1') \gset x_
reset role;
select test.acct('4000') as rev_before \gset
set role authenticated;
select test.as_user(:SALES, 'aal1') \gset x_
select (public.payment_collect('d0000000-0000-0000-0000-000000000001', :'cust_w', :'acc_cash', 700000, null, :'shift', null)) as col \gset
select test.ok('collection: 220,000 allocated, 480,000 becomes customer credit',
  (:'col'::jsonb ->> 'allocated')::bigint = 220000 and (:'col'::jsonb ->> 'credit')::bigint = 480000);
reset role;
select test.ok('collection did not create revenue', test.acct('4000') = :rev_before);
select test.ok('customer receivable 0, credit 480,000', public._customer_receivable(:'cust_w') = 0 and public._customer_credit(:'cust_w') = 480000);
set role authenticated;
select test.as_user(:SALES, 'aal1') \gset x_
select (public.sale_post('b0000000-0000-0000-0000-000000000011', :'loc_shop', :'shift', :'cust_w', 'retail', :S9::jsonb, 0, 'collected',
  '[{"method":"customer_credit","amount":30000}]', null, null, null, null)) ->> 'sale_id' as sale10 \gset
reset role;
select test.ok('customer credit used as payment (credit 450,000 left)', public._customer_credit(:'cust_w') = 450000
  and (select payment_status from public.sales where id = :'sale10') = 'paid');
set role authenticated;

-- ---------------------------------------------------------------- walk-in return → inspection → refund
select test.as_user(:SALES, 'aal1') \gset x_
select id as sl6 from public.sale_lines where sale_id = :'sale6' \gset
select test.throws('return: walk-in cannot be credited', $$select public.return_request(gen_random_uuid(), '$$ || :'sale6' || $$',
  '[{"sale_line_id":"$$ || :'sl6' || $$","qty":1}]', 'x', 'credit')$$);
select (public.return_request('c0000000-0000-0000-0000-000000000002', :'sale6',
  jsonb_build_array(jsonb_build_object('sale_line_id', :'sl6', 'qty', 1)), 'stitching fault', 'refund')) ->> 'return_id' as ret6 \gset
select test.throws('return: cannot return more than sold', $$select public.return_request(gen_random_uuid(), '$$ || :'sale6' || $$',
  '[{"sale_line_id":"$$ || :'sl6' || $$","qty":1}]', 'again', 'refund')$$);
select test.throws('return: requester cannot approve', $$select public.return_decide('$$ || :'ret6' || $$', true, 'ok')$$);
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.return_decide(:'ret6', true, 'fault confirmed') \gset x_
reset role;
select test.ok('returned goods sit in inspection, not saleable (2 returns so far)', test.qty(:'v48', 'INSPECT') = 2 and test.qty(:'v48', 'SHOP') = 0);
set role authenticated;
select test.as_user(:SALES, 'aal1') \gset x_
select test.throws('refund: cannot exceed what is owed', $$select public.refund_pay(gen_random_uuid(), '$$ || :'ret6' || $$', '$$ || :'acc_cash' || $$', '$$ || :'shift' || $$', 450001, null)$$);
select public.refund_pay('e0000000-0000-0000-0000-000000000001', :'ret6', :'acc_cash', :'shift', 450000, null) \gset x_
select public.refund_pay('e0000000-0000-0000-0000-000000000001', :'ret6', :'acc_cash', :'shift', 450000, null) \gset x_
select test.throws('refund: no second refund', $$select public.refund_pay(gen_random_uuid(), '$$ || :'ret6' || $$', '$$ || :'acc_cash' || $$', '$$ || :'shift' || $$', 1, null)$$);
reset role;
select test.ok('refund replay paid once', (select refunded from public.sale_returns where id = :'ret6') = 450000
  and (select count(*) from public.journal_entries where source_type = 'refund') = 1);
set role authenticated;
select test.as_user(:STORE, 'aal1') \gset x_
select id as rl6 from public.sale_return_lines where return_id = :'ret6' \gset
select public.inspection_release('f0000000-0000-0000-0000-000000000001', :'rl6', 1, 'restock', 'inspected OK') \gset x_
select test.throws('inspection: cannot release more than inspected', $$select public.inspection_release(gen_random_uuid(), '$$ || :'rl6' || $$', 1, 'restock', 'again')$$);
reset role;
select test.ok('inspection release restocks the shop; the other return stays in inspection', test.qty(:'v48', 'SHOP') = 1 and test.qty(:'v48', 'INSPECT') = 1);
set role authenticated;

-- ---------------------------------------------------------------- expense, deposit, runner advance
select test.as_user(:SALES, 'aal1') \gset x_
select (public.expense_request('a1000000-0000-0000-0000-000000000001', :'loc_shop', 'Transport', 20000, 'Bajaji', 'stock pickup', null, null)) ->> 'expense_id' as exp \gset
select test.throws('expense: requester cannot approve', $$select public.expense_decide('$$ || :'exp' || $$', true, 'ok')$$);
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.expense_decide(:'exp', true, 'ok') \gset x_
select test.as_user(:SALES, 'aal1') \gset x_
select public.expense_pay('a1000000-0000-0000-0000-000000000002', :'exp', :'acc_cash', :'shift', null) \gset x_
select test.throws('expense: cannot be paid twice', $$select public.expense_pay(gen_random_uuid(), '$$ || :'exp' || $$', '$$ || :'acc_cash' || $$', '$$ || :'shift' || $$', null)$$);

select (public.money_transfer_send('a2000000-0000-0000-0000-000000000001', :'acc_cash', :'acc_bank', 100000, 'deposit slip 001', 'slip photo', :'shift')) ->> 'transfer_id' as dep \gset
select test.throws('deposit: sender cannot confirm', $$select public.money_transfer_confirm('$$ || :'dep' || $$', 0, null)$$);
reset role;
select test.ok('deposit in transit: not in bank yet, not revenue', test.acct('1050') = 100000 and test.money('BANK') = 1000000);
set role authenticated;
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.money_transfer_confirm(:'dep', 1000, 'CRDB-REF-9') \gset x_
reset role;
select test.ok('deposit confirmed: bank +99,000, fee 1,000 expensed, transit 0',
  test.money('BANK') = 1099000 and test.acct('6400') = 1000 and test.acct('1050') = 0);
set role authenticated;

select test.as_user(:SALES, 'aal1') \gset x_
select (public.advance_issue('a3000000-0000-0000-0000-000000000001', 'Juma (boda)', :'sale8', :'acc_cash', 10000, :'shift')) ->> 'advance_id' as adv \gset
select test.throws('advance: expense + returned must equal advance', $$select public.advance_settle('$$ || :'adv' || $$', 7000, 2000, '$$ || :'acc_cash' || $$', '$$ || :'shift' || $$', 'receipt')$$);
select public.advance_settle(:'adv', 7000, 3000, :'acc_cash', :'shift', 'fuel receipt + 3,000 returned') \gset x_
reset role;
select test.ok('advance: courier expense counted once (7,000), advance cleared', test.acct('6100') = 7000 and test.acct('1150') = 0);
set role authenticated;

-- ---------------------------------------------------------------- shift close & independent review
select test.as_user(:SALES, 'aal1') \gset x_
select test.throws('shift: variance must be explained', $$select public.shift_close('$$ || :'shift' || $$', 1126000, null)$$);
select (public.shift_close(:'shift', 1126000, 'counted twice, 2,000 short')) as closed \gset
select test.ok('shift: expected = float + cash in − cash out (1,128,000); variance −2,000',
  (:'closed'::jsonb ->> 'expected')::bigint = 1128000 and (:'closed'::jsonb ->> 'variance')::bigint = -2000);
select test.throws('shift: no posting after close', $$select public.sale_post(gen_random_uuid(), '$$ || :'loc_shop' || $$', '$$ || :'shift' || $$', null, 'retail', '$$ || :S9 || $$', 0, 'collected',
     '[{"account_id":"$$ || :'acc_cash' || $$","amount":30000}]', null, null, null, null)$$);
select test.throws('shift: cashier cannot review own shift', $$select public.shift_review('$$ || :'shift' || $$', 'fine')$$);
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.shift_review(:'shift', 'shortage noted, cashier informed') \gset x_
reset role;
select test.ok('shift review posts cash short 2,000; drawer book = cash movements − 2,000',
  test.acct('6300') = 2000 and test.money('CASH-SHOP') = 1076000 and (select status from public.shifts where id = :'shift') = 'closed');

-- ---------------------------------------------------------------- secrecy & journal integrity
set role authenticated;
select test.as_user(:SALES, 'aal1') \gset x_
select test.ok('sales: cannot read journal or cost snapshots',
  (select count(*) from public.journal_lines) = 0 and (select count(*) from public.sale_line_costs) = 0);
select test.throws('sales: cannot read business overview', $$select public.business_overview(current_date, current_date)$$);
select test.throws('sales: cannot insert a sale directly', $$insert into public.sales (business_id) select id from public.businesses$$);
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('manager: no owner money overview by default', $$select public.money_balances()$$);
select test.as_user(:OWNER, 'aal2') \gset x_
select public.business_overview(test.today() - 7, test.today()) as ov \gset
reset role;
select test.ok('overview: net sales 2,125,000 − returns 830,000 = 1,295,000', (:'ov'::jsonb ->> 'net_sales')::bigint = 1295000);
select test.ok('overview: collections by payment date 2,195,000 (customer credit is not a collection)', (:'ov'::jsonb ->> 'collections')::bigint = 2195000);
select test.ok('overview: COGS 5 suits × 200,000 − 2 returned = 600,000', (:'ov'::jsonb ->> 'cogs')::bigint = 600000);
select test.ok('overview: 2 units sold with unknown cost are flagged', (:'ov'::jsonb ->> 'units_cost_unknown')::int = 2);
select test.ok('overview: receivables 0, customer credits 450,000',
  (:'ov'::jsonb ->> 'receivables')::bigint = 0 and (:'ov'::jsonb ->> 'customer_credits')::bigint = 450000);
select test.ok('JOURNAL: every entry balances, trial balance is zero', test.all_balanced());
select test.throws('JOURNAL: posted lines cannot be edited', $$update public.journal_lines set debit = debit + 1$$);
select test.throws('JOURNAL: entries cannot be deleted', $$delete from public.journal_entries$$);
select test.throws('JOURNAL: unbalanced entry rejected', $$select public._post_journal((select id from public.businesses), current_date, 'x', null, 'x', null,
  '[{"account":"4000","credit":5},{"account":"1100","debit":4}]')$$);

\ir _reports_checks.sql
\ir _report.sql
