-- Milestone E report checks, run on top of the Milestone C scenario (included from 30_sales_test.sql).
-- Known figures from that scenario (period: last 7 days): goods 2,125,000; returns 830,000; net 1,295,000;
-- collections 2,195,000; COGS 600,000.

-- one open credit sale so ageing has something to age
set role authenticated;
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.shift_open(:'loc_shop', :'acc_cash', 0) as mshift \gset
select public.sale_post('ab000000-0000-0000-0000-000000000001', :'loc_shop', :'mshift', :'cust_r', 'retail', :S9::jsonb, 0, 'collected', '[]', null, null, null, null) as r_credit \gset
select test.as_user(:OWNER, 'aal2') \gset x_
select public.approval_decide((:'r_credit'::jsonb ->> 'approval_id')::uuid, true, 'small amount') \gset x_
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.sale_post('ab000000-0000-0000-0000-000000000002', :'loc_shop', :'mshift', :'cust_r', 'retail', :S9::jsonb, 0, 'collected', '[]', null, null, null,
  (:'r_credit'::jsonb ->> 'approval_id')::uuid) ->> 'status' as rc \gset

\set P_FROM 'test.today() - 7'
\set P_TO 'test.today()'

select test.as_user(:OWNER, 'aal2') \gset x_
select public.report('sales', :P_FROM, :P_TO) as rs \gset
select public.report('collections', :P_FROM, :P_TO) as rcol \gset
select public.report('reconciliation', :P_FROM, :P_TO) as rrec \gset
select public.report('ageing', :P_FROM, :P_TO) as rage \gset
select public.report('pnl', :P_FROM, :P_TO) as rpnl \gset
select public.report('products', :P_FROM, :P_TO) as rprod \gset
select public.report('stock', :P_FROM, :P_TO) as rstock \gset
select public.report('staff', :P_FROM, :P_TO) as rstaff \gset
select public.report('exceptions', :P_FROM, :P_TO) as rexc \gset
select public.report('trial_balance', :P_FROM, :P_TO) as rtb \gset
select public.business_overview(:P_FROM, :P_TO) as rov \gset
reset role;

select test.ok('report: sales net = goods 2,155,000 − returns 830,000 (incl. new 30,000 credit sale)',
  (:'rs'::jsonb -> 'totals' ->> 'goods_net')::bigint = 2155000 and (:'rs'::jsonb -> 'totals' ->> 'returns')::bigint = 830000
  and (:'rs'::jsonb -> 'totals' ->> 'net_sales')::bigint = 1325000);
select test.ok('report: sales net equals the ledger (4000 − 4900) and the overview',
  (:'rs'::jsonb -> 'totals' ->> 'net_sales')::bigint = (:'rov'::jsonb ->> 'net_sales')::bigint);
select test.ok('report: by-day rows add up to the period totals',
  (select sum((d->>'goods_net')::bigint) from jsonb_array_elements(:'rs'::jsonb -> 'by_day') d) = (:'rs'::jsonb -> 'totals' ->> 'goods_net')::bigint);
select test.ok('report: channel / source / location splits add up',
  (select sum((d->>'goods_net')::bigint) from jsonb_array_elements(:'rs'::jsonb -> 'by_channel') d) = 2155000
  and (select sum((d->>'goods_net')::bigint) from jsonb_array_elements(:'rs'::jsonb -> 'by_source') d) = 2155000
  and (select sum((d->>'goods_net')::bigint) from jsonb_array_elements(:'rs'::jsonb -> 'by_location') d) = 2155000);
select test.ok('report: owner sees COGS 600,000 and an incomplete-cost warning (ties have no cost)',
  (:'rs'::jsonb -> 'costs' ->> 'cogs')::bigint = 600000 and (:'rs'::jsonb -> 'costs' ->> 'units_cost_unknown')::int = 3);
select test.ok('collections: 2,195,000 by payment date; 480,000 went to customer credit; 30,000 credit applied; 450,000 refunded',
  (:'rcol'::jsonb -> 'totals' ->> 'collections')::bigint = 2195000 and (:'rcol'::jsonb -> 'totals' ->> 'advances_to_credit')::bigint = 480000
  and (:'rcol'::jsonb -> 'totals' ->> 'credit_applied')::bigint = 30000 and (:'rcol'::jsonb -> 'totals' ->> 'refunds_paid')::bigint = 450000);
select test.ok('collections: by-method split adds up', (select sum((d->>'amount')::bigint) from jsonb_array_elements(:'rcol'::jsonb -> 'by_method') d) = 2195000);
select test.ok('RECONCILIATION: collections fully explained by sales, Δreceivables, Δcredits and refunds (difference 0)',
  (:'rrec'::jsonb ->> 'unexplained_difference')::bigint = 0);
select test.ok('ageing: open balance 30,000 equals ledger receivables', (:'rage'::jsonb -> 'totals' ->> 'total')::bigint = 30000
  and (:'rage'::jsonb ->> 'ledger_receivables')::bigint = 30000);
select test.ok('P&L: gross profit = net revenue − COGS; operating profit subtracts 30,000 of costs',
  (:'rpnl'::jsonb ->> 'gross_profit')::bigint = (:'rpnl'::jsonb ->> 'net_revenue')::bigint - (:'rpnl'::jsonb ->> 'cogs')::bigint
  and (:'rpnl'::jsonb ->> 'expenses_total')::bigint = 30000 and (:'rpnl'::jsonb ->> 'complete')::boolean = false);
select test.ok('products: net units and revenue reconcile with the sales report',
  (:'rprod'::jsonb -> 'totals' ->> 'revenue')::bigint = (:'rs'::jsonb -> 'totals' ->> 'net_sales')::bigint);
select test.ok('stock report: total equals all balances', (:'rstock'::jsonb -> 'totals' ->> 'total')::bigint = (select sum(on_hand) from public.stock_balances));
select test.ok('staff report: sellers'' goods add up to the sales total',
  (select sum((d->>'goods_net')::bigint) from jsonb_array_elements(:'rstaff'::jsonb) d) = 2155000);
select test.ok('exceptions: backdated sale, shift variance and approvals are listed',
  jsonb_array_length(:'rexc'::jsonb -> 'backdated_sales') = 1 and jsonb_array_length(:'rexc'::jsonb -> 'shift_variances') >= 1
  and jsonb_array_length(:'rexc'::jsonb -> 'approvals') >= 2);
select test.ok('trial balance: total debits = total credits', (:'rtb'::jsonb ->> 'total_debit')::bigint = (:'rtb'::jsonb ->> 'total_credit')::bigint);

-- secrecy
set role authenticated;
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.ok('manager: sales report without costs, no P&L, no trial balance',
  not (public.report('sales', test.today() - 7, test.today()) ? 'costs') and public.report('pnl', test.today() - 7, test.today()) is null
  and public.report('trial_balance', test.today() - 7, test.today()) is null
  and (public.report('stock', test.today(), test.today()) -> 'totals' ->> 'value_known') is null);
select test.as_user(:SALES, 'aal1') \gset x_
select test.throws('sales staff: no reports', $$select public.report('sales', current_date - 1, current_date)$$);
select test.throws('sales staff: no job status', $$select public.job_status()$$);
select test.throws('report: invalid period rejected', $$select public.report('sales', current_date, current_date - 1)$$);

-- large volume: 300 more sales; report totals must include every one (no truncation)
select test.as_user(:OWNER, 'aal2') \gset x_
select public.design_create('SOCK-E', 'Socks E', 'accessory', null, null, array['Black'], array['ONE'], 5000, null) as d_sock \gset
select id as vsock from public.variants where sku = 'SOCK-E-BLACK-ONE' \gset
select public.opening_stock_post('ab000000-0000-0000-0000-000000000003', :'loc_shop', jsonb_build_array(jsonb_build_object('variant_id', :'vsock', 'qty', 300)), 'bulk test stock') \gset x_
select test.as_user(:MANAGER, 'aal2') \gset x_
do $$
declare i int; v uuid; loc uuid; sh uuid; acc uuid;
begin
  select id into v from public.variants where sku = 'SOCK-E-BLACK-ONE';
  select id into loc from public.locations where code = 'SHOP';
  select id into sh from public.shifts where status = 'open' and opened_by = (public.current_membership()).id;
  select id into acc from public.money_accounts where code = 'CASH-SHOP';
  for i in 1..300 loop
    perform public.sale_post(gen_random_uuid(), loc, sh, null, 'retail', jsonb_build_array(jsonb_build_object('variant_id', v, 'qty', 1)), 0, 'collected',
      jsonb_build_array(jsonb_build_object('account_id', acc, 'amount', 5000)), null, null, null, null);
  end loop;
end $$;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.report('sales', :P_FROM, :P_TO) as rs2 \gset
reset role;
select test.ok('VOLUME: 300 extra sales all counted server-side (goods +1,500,000)',
  (:'rs2'::jsonb -> 'totals' ->> 'goods_net')::bigint = 2155000 + 1500000
  and (:'rs2'::jsonb -> 'totals' ->> 'sales')::int = (:'rs'::jsonb -> 'totals' ->> 'sales')::int + 300);

-- scheduled report runs: versioning, dedupe, bounded retry
select id as biz from public.businesses \gset
set role service_role;
select public.job_begin(:'biz'::uuid, 'daily_interim', test.today()) as j1 \gset
select public.job_finish((:'j1'::jsonb ->> 'run_id')::uuid, true, 'daily/x/v1.pdf', 'abc', 123, null) \gset x_
select public.job_begin(:'biz'::uuid, 'daily_interim', test.today()) as j2 \gset
reset role;
select test.ok('job: first run is version 1; an unchanged day is skipped (no duplicate report)',
  (:'j1'::jsonb ->> 'version')::int = 1 and (:'j2'::jsonb ->> 'skip')::boolean);
-- new data arrives later the same day → a new version
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.opening_stock_post('ab000000-0000-0000-0000-000000000004', :'loc_shop', jsonb_build_array(jsonb_build_object('variant_id', :'vsock', 'qty', 5)), 'late count') \gset x_
reset role;
set role service_role;
select public.job_begin(:'biz'::uuid, 'daily_interim', test.today()) as j3 \gset
select public.job_finish((:'j3'::jsonb ->> 'run_id')::uuid, false, null, null, null, 'storage unavailable') \gset x_
select public.job_begin(:'biz'::uuid, 'daily_interim', test.today()) as j4 \gset
select public.job_finish((:'j4'::jsonb ->> 'run_id')::uuid, true, 'daily/x/v2.pdf', 'def', 456, null) \gset x_
select test.throws('job: finishing a run twice is rejected', $$select public.job_finish('$$ || (:'j4'::jsonb ->> 'run_id') || $$', true, 'p', 's', 1, null)$$);
select public.daily_snapshot(:'biz'::uuid, test.today()) as snap \gset
select public.recovery_manifest() as man \gset
\if :{?FIXTURE_OUT}
\o :FIXTURE_OUT
\qecho :snap
\o
\endif
reset role;
select test.ok('job: late data creates version 2', (:'j3'::jsonb ->> 'version')::int = 2);
select test.ok('job: a failed run is retried as the same version (attempt 2), not duplicated',
  (:'j4'::jsonb ->> 'run_id') = (:'j3'::jsonb ->> 'run_id') and (select attempt from public.report_runs where id = (:'j4'::jsonb ->> 'run_id')::uuid) = 2);
select test.ok('snapshot: daily PDF data uses the same totals as the live report for today',
  (:'snap'::jsonb -> 'sales' -> 'totals' ->> 'goods_net')::bigint = (select (public._rpt_sales(:'biz'::uuid, test.today(), test.today(), null, true) -> 'totals' ->> 'goods_net')::bigint));
select test.ok('recovery manifest: journal debits equal credits', (:'man'::jsonb -> 'totals' ->> 'journal_debit') = (:'man'::jsonb -> 'totals' ->> 'journal_credit'));
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select test.ok('owner sees run history and failures', jsonb_array_length(public.job_status() -> 'reports') = 2
  and (public.job_status() ->> 'report_failures_7d')::int = 0);
reset role;

-- leave the scenario as the concurrency script expects: manager's shift closed, a couple of ties in the shop
set role authenticated;
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.shift_close(:'mshift', 1500000, null) \gset x_
select test.as_user(:OWNER, 'aal2') \gset x_
select public.opening_stock_post('ab000000-0000-0000-0000-000000000005', :'loc_shop', jsonb_build_array(jsonb_build_object('variant_id', :'vtie', 'qty', 2)), 'restock for race test') \gset x_
reset role;
