-- Milestone G migration rehearsal: catalogue CSV → customers with opening balances → opening stock → reconcile.
\set ON_ERROR_STOP 1
\set QUIET 1
\pset tuples_only on
\pset format unaligned

\ir _framework.sql

create function test.as_user(p_uid uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims', test.claims(p_uid, p_aal), false); select null::void;
$$;
create function test.acct(p_code text) returns bigint language sql security definer as $$
  select coalesce(sum(debit - credit), 0)::bigint from public.journal_lines where account_code = p_code
$$;
create function test.today() returns date language sql as $$ select (now() at time zone 'Africa/Dar_es_Salaam')::date $$;
grant execute on all functions in schema test to authenticated, service_role;

insert into auth.users (id, phone) values ('00000000-0000-0000-0000-0000000000e1', '+255780000001'), ('00000000-0000-0000-0000-0000000000e2', '+255780000002');
\set OWNER '''00000000-0000-0000-0000-0000000000e1'''
\set SALES '''00000000-0000-0000-0000-0000000000e2'''
set role service_role;
select public.setup_create_business('DIROMA', 'Spirit of Fashion', 'FIX-G') \gset x_
select public.setup_finalize_owner('FIX-G', :OWNER, '+255780000001', 'Owner G') \gset x_
reset role;
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.location_create('WH', 'Store', 'warehouse') as loc_wh \gset
select public.location_create('SHOP', 'Shop', 'shop') as loc_shop \gset
select public.team_invite('+255780000002', 'Sales G', 'sales_staff', array[:'loc_shop']::uuid[], null) as m_sales \gset
reset role;
set role service_role;
select public.team_attach_auth_user(:'m_sales', :SALES, 'G1') \gset x_
select public.activation_finalize('+255780000002', 'G1') \gset x_
reset role;
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_

-- step 1: catalogue (synthetic rows shaped like an exported product list)
select (public.catalogue_import('a7000000-0000-0000-0000-000000000001', '[
  {"design_code":"DR#2516-43","design_name":"Slim suit","category":"suit_2pc","color":"Black","size":"48","retail_price":450000,"wholesale_price":380000},
  {"design_code":"DR#2516-43","design_name":"Slim suit","category":"suit_2pc","color":"Black","size":"50","retail_price":450000,"wholesale_price":380000},
  {"design_code":"TIE-RED","design_name":"Silk tie","category":"accessory","color":"Red","size":"ONE","retail_price":30000}]', 'create_only')) ->> 'variants_created' as cat_n \gset
select test.ok('catalogue imported (3 variants)', :'cat_n' = '3');

-- step 2: customers with opening balances (as of the day before go-live)
\set CUST '''[{"name":"Mteja Mmoja Test","phone":"+255790000001","kind":"retail","opening_balance":120000},{"name":"Partner Test","phone":"+255790000002","kind":"wholesale","credit_limit":3000000,"terms_days":14,"region":"Mwanza","opening_balance":900000},{"name":"No Debt Test","phone":null,"kind":"retail"}]'''
select test.throws('import is all-or-nothing: one bad phone rejects the file',
  $$select public.customer_import(gen_random_uuid(), '[{"name":"A Ok","phone":"+255790000009"},{"name":"B Bad","phone":"0712"}]', 'create_only', current_date - 1, null)$$);
select test.ok('nothing created by the rejected file', not exists (select 1 from public.customers where phone_e164 = '+255790000009'));
select test.throws('opening balances need a shop to own them',
  $$select public.customer_import(gen_random_uuid(), '[{"name":"X Test","phone":"+255790000008","opening_balance":5}]', 'create_only', current_date - 1, null)$$);
select (public.customer_import('a7000000-0000-0000-0000-000000000002', :CUST::jsonb, 'create_only', test.today() - 1, :'loc_shop')) as cimp \gset
select test.ok('customers: 3 created, 2 opening balances totalling 1,020,000',
  (:'cimp'::jsonb ->> 'created')::int = 3 and (:'cimp'::jsonb ->> 'opening_balances')::int = 2 and (:'cimp'::jsonb ->> 'opening_total')::bigint = 1020000);
select test.ok('replay of the same import is a no-op', (public.customer_import('a7000000-0000-0000-0000-000000000002', :CUST::jsonb, 'create_only', test.today() - 1, :'loc_shop')) ->> 'created' = '3'
  and (select count(*) from public.customers) = 3);
select test.throws('create_only: an existing phone is an error',
  $$select public.customer_import(gen_random_uuid(), '[{"name":"Again","phone":"+255790000001"}]', 'create_only', current_date - 1, null)$$);
select test.throws('opening balance can be posted only once per customer',
  $$select public.customer_import(gen_random_uuid(), '[{"name":"Mteja Mmoja Test","phone":"+255790000001","opening_balance":1}]', 'update', current_date - 1, '$$ || :'loc_shop' || $$')$$);
reset role;
select test.ok('LEDGER: opening receivables = 1,020,000 against opening equity, no revenue',
  test.acct('1100') = 1020000 and test.acct('3000') = -1020000 and test.acct('4000') = 0);
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_

-- step 3: opening stock from CSV
select test.throws('opening stock: unknown variant rejects the whole file',
  $$select public.opening_stock_import(gen_random_uuid(), '[{"design_code":"DR#2516-43","color":"Black","size":"48","location_code":"WH","qty":5},{"design_code":"NOPE","color":"x","size":"48","location_code":"WH","qty":1}]', 'opening count')$$);
select test.ok('nothing posted by the rejected stock file', (select count(*) from public.stock_movements) = 0);
select (public.opening_stock_import('a7000000-0000-0000-0000-000000000003', '[
  {"design_code":"DR#2516-43","color":"black","size":"48","location_code":"wh","qty":12},
  {"design_code":"DR#2516-43","color":"Black","size":"50","location_code":"WH","qty":8},
  {"design_code":"DR#2516-43","color":"Black","size":"48","location_code":"SHOP","qty":3},
  {"design_code":"TIE-RED","color":"Red","size":"ONE","location_code":"SHOP","qty":20}]', 'physical count 2026-11-09')) as simp \gset
select public.opening_stock_import('a7000000-0000-0000-0000-000000000003', '[
  {"design_code":"DR#2516-43","color":"black","size":"48","location_code":"wh","qty":12},
  {"design_code":"DR#2516-43","color":"Black","size":"50","location_code":"WH","qty":8},
  {"design_code":"DR#2516-43","color":"Black","size":"48","location_code":"SHOP","qty":3},
  {"design_code":"TIE-RED","color":"Red","size":"ONE","location_code":"SHOP","qty":20}]', 'physical count 2026-11-09') \gset x_
reset role;
select test.ok('opening stock: 43 units in 2 documents (one per location); replay posted nothing more',
  (:'simp'::jsonb ->> 'units')::int = 43 and (:'simp'::jsonb ->> 'documents')::int = 2 and (select sum(on_hand) from public.stock_balances) = 43);
select test.ok('opening stock is a document, not a silent overwrite',
  (select count(*) from public.stock_documents where doc_type = 'opening') = 2 and (select count(*) from public.stock_movements) = 4);
set role authenticated;

-- step 4: go-live — the opening balance behaves like debt, never like a sale
select test.as_user(:OWNER, 'aal2') \gset x_
select public.report('sales', test.today() - 30, test.today()) as rs \gset
select public.report('ageing', test.today(), test.today()) as rage \gset
select id as cust_p from public.customers where phone_e164 = '+255790000002' \gset
select public.money_account_create('BANK', 'Bank', 'bank', null) as bank \gset
select (public.payment_collect(gen_random_uuid(), :'cust_p', :'bank', 400000, 'TRX1', null, null)) as col \gset
select public.report('collections', test.today(), test.today()) as rcol \gset
reset role;
select test.ok('opening balances are NOT in the sales report', (:'rs'::jsonb -> 'totals' ->> 'sales')::int = 0 and (:'rs'::jsonb -> 'totals' ->> 'goods_net')::bigint = 0);
select test.ok('opening balances ARE in receivables ageing (1,020,000)', (:'rage'::jsonb -> 'totals' ->> 'total')::bigint = 1020000);
select test.ok('first collection is applied to the opening balance (FIFO) and counted as old debt',
  (:'col'::jsonb ->> 'allocated')::bigint = 400000 and (:'rcol'::jsonb -> 'totals' ->> 'old_debt')::bigint = 400000);
select test.ok('migrated partner owes 500,000 after the payment', public._customer_receivable(:'cust_p') = 500000);
set role authenticated;
select test.as_user(:SALES, 'aal1') \gset x_
select test.throws('sales staff cannot import customers', $$select public.customer_import(gen_random_uuid(), '[{"name":"Z Z"}]', 'create_only', current_date, null)$$);
select test.throws('sales staff cannot import opening stock', $$select public.opening_stock_import(gen_random_uuid(), '[]', 'x')$$);
reset role;
select test.ok('import log kept', (select count(*) from public.data_imports) = 2);
select test.ok('JOURNAL: every entry balances', not exists (select 1 from public.journal_lines group by entry_id having sum(debit) <> sum(credit)));

\ir _report.sql
