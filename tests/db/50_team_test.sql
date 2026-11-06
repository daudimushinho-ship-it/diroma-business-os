-- Milestone F database acceptance tests: targets, content, tasks, inquiries, commissions, public catalogue.
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
grant execute on all functions in schema test to anon, authenticated, service_role;

-- ---------------------------------------------------------------- fixture
insert into auth.users (id, phone) values
  ('00000000-0000-0000-0000-0000000000f1', '+255760000001'), ('00000000-0000-0000-0000-0000000000f2', '+255760000002'),
  ('00000000-0000-0000-0000-0000000000f3', '+255760000003'), ('00000000-0000-0000-0000-0000000000f4', '+255760000004');
\set OWNER   '''00000000-0000-0000-0000-0000000000f1'''
\set MANAGER '''00000000-0000-0000-0000-0000000000f2'''
\set SALES   '''00000000-0000-0000-0000-0000000000f3'''
\set SALES2  '''00000000-0000-0000-0000-0000000000f4'''
set role service_role;
select public.setup_create_business('DIROMA', 'Spirit of Fashion', 'FIX-F') \gset x_
select public.setup_finalize_owner('FIX-F', :OWNER, '+255760000001', 'Owner F') \gset x_
reset role;
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.location_create('SHOP', 'Shop', 'shop') as loc_shop \gset
select public.team_invite('+255760000002', 'Manager F', 'manager', '{}', null) as m_mgr \gset
select public.team_invite('+255760000003', 'Sales F', 'sales_staff', array[:'loc_shop']::uuid[], null) as m_sales \gset
select public.team_invite('+255760000004', 'Sales Two F', 'sales_staff', array[:'loc_shop']::uuid[], null) as m_sales2 \gset
select public.team_set_locations(:'m_mgr', true, '{}', 'all') \gset x_
reset role;
set role service_role;
select public.team_attach_auth_user(:'m_mgr', :MANAGER, 'Z1') \gset x_
select public.team_attach_auth_user(:'m_sales', :SALES, 'Z2') \gset x_
select public.team_attach_auth_user(:'m_sales2', :SALES2, 'Z3') \gset x_
select public.activation_finalize('+255760000002', 'Z1') \gset x_
select public.activation_finalize('+255760000003', 'Z2') \gset x_
select public.activation_finalize('+255760000004', 'Z3') \gset x_
reset role;
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.design_create('SUIT-F', 'Suit F', 'suit_2pc', null, null, array['Black'], array['48','50'], 400000, 330000) as d_suit \gset
select public.design_create('HIDDEN-F', 'Not published', 'shirt', null, null, array['White'], array['M'], 50000, 40000) as d_hidden \gset
select id as v48 from public.variants where sku = 'SUIT-F-BLACK-48' \gset
select public.opening_stock_post('f0000000-0000-0000-0000-000000000001', :'loc_shop', jsonb_build_array(jsonb_build_object('variant_id', :'v48', 'qty', 10)), 'opening') \gset x_
select public.money_account_create('CASH-SHOP', 'Drawer', 'cash', :'loc_shop') as acc_cash \gset
select public.money_account_create('BANK', 'Bank', 'bank', null) as acc_bank \gset
select test.as_user(:SALES, 'aal1') \gset x_
select public.customer_save(null, 'Customer A Test', '+255770000001', 'retail', 0, 0, null, null, 'instagram') as cust_a \gset
select public.customer_save(null, 'Customer B Test', '+255770000002', 'retail', 0, 0, null, null, null) as cust_b \gset
select public.shift_open(:'loc_shop', :'acc_cash', 0) as sh1 \gset
\set L1 '''[{"variant_id":"' :v48 '","qty":1}]'''
select (public.sale_post(gen_random_uuid(), :'loc_shop', :'sh1', :'cust_a', 'retail', :L1::jsonb, 0, 'collected',
  jsonb_build_array(jsonb_build_object('account_id', :'acc_cash', 'amount', 400000)), null, 'instagram', null, null)) ->> 'sale_id' as sale_a \gset
select (public.sale_post(gen_random_uuid(), :'loc_shop', :'sh1', :'cust_b', 'retail', :L1::jsonb, 0, 'collected',
  jsonb_build_array(jsonb_build_object('account_id', :'acc_cash', 'amount', 400000)), null, null, null, null)) ->> 'sale_id' as sale_b \gset
select test.as_user(:SALES2, 'aal1') \gset x_
select public.shift_open(:'loc_shop', :'acc_cash', 0) as sh2 \gset
select (public.sale_post(gen_random_uuid(), :'loc_shop', :'sh2', null, 'retail', :L1::jsonb, 0, 'collected',
  jsonb_build_array(jsonb_build_object('account_id', :'acc_cash', 'amount', 400000)), null, null, null, null)) ->> 'sale_id' as sale_c \gset
-- a return on one of SALES' sales (claws back commission)
select test.as_user(:SALES, 'aal1') \gset x_
select id as slb from public.sale_lines where sale_id = :'sale_b' \gset
select (public.return_request(gen_random_uuid(), :'sale_b', jsonb_build_array(jsonb_build_object('sale_line_id', :'slb', 'qty', 1)), 'wrong size', 'credit')) ->> 'return_id' as ret_b \gset
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.return_decide(:'ret_b', true, 'ok') \gset x_
reset role;
set role authenticated;

-- ---------------------------------------------------------------- targets: content defaults, no invented sales targets
select test.as_user(:OWNER, 'aal2') \gset x_
select public.target_progress('reels', 'month', test.today(), 'business', null, null) as t_month \gset
select public.target_progress('reels', 'week', test.today(), 'business', null, null) as t_week \gset
select public.target_progress('reels', 'day', test.today(), 'business', null, null) as t_day \gset
select public.target_progress('product_posts', 'month', test.today(), 'business', null, null) as t_posts \gset
select public.target_progress('net_sales', 'month', test.today(), 'business', null, null) as t_sales \gset
select test.ok('default: 3 reels × days in this calendar month',
  (:'t_month'::jsonb ->> 'target')::int = 3 * extract(day from (date_trunc('month', test.today()) + interval '1 month' - interval '1 day'))::int
  and :'t_month'::jsonb ->> 'source' = 'default');
select test.ok('default: 21 reels per week, 3 per day', (:'t_week'::jsonb ->> 'target')::int = 21 and (:'t_day'::jsonb ->> 'target')::int = 3);
select test.ok('default: 100 product posts per month', (:'t_posts'::jsonb ->> 'target')::int = 100);
select test.ok('no sales target is invented', :'t_sales'::jsonb -> 'target' = 'null'::jsonb and :'t_sales'::jsonb ->> 'source' = 'none');
select public.target_set('reels', 'business', null, null, 'month', test.today(), 60, 'Ramadan slowdown') \gset x_
select test.ok('owner override replaces the default', (public.target_progress('reels', 'month', test.today(), 'business', null, null) ->> 'target')::int = 60
  and public.target_progress('reels', 'month', test.today(), 'business', null, null) ->> 'source' = 'owner');
select public.target_set('net_sales', 'member', null, :'m_sales', 'month', test.today(), 1000000, null) \gset x_
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('manager cannot set targets', $$select public.target_set('reels', 'business', null, null, 'month', current_date, 1, null)$$);
select test.as_user(:SALES, 'aal1') \gset x_
select public.target_progress('net_sales', 'month', test.today(), 'member', null, :'m_sales') as t_mine \gset
select test.ok('sales: own target progress = own net sales after returns (800,000 − 400,000)',
  (:'t_mine'::jsonb ->> 'target')::bigint = 1000000 and (:'t_mine'::jsonb ->> 'actual')::bigint = 400000 and (:'t_mine'::jsonb ->> 'pct')::numeric = 40);
select test.throws('sales: cannot see another seller''s target', $$select public.target_progress('net_sales', 'month', current_date, 'member', null, '$$ || :'m_sales2' || $$')$$);
select test.ok('sales: can see business content targets', (public.target_progress('reels', 'month', test.today(), 'business', null, null) ->> 'target')::int = 60);

-- ---------------------------------------------------------------- content log with evidence & independent verification
select public.content_log('reel', 'instagram', 'https://www.instagram.com/reel/TESTAAA111/', :'d_suit', test.today(), 'slim suit') as post1 \gset
select public.content_log('reel', 'tiktok', 'https://www.tiktok.com/@diroma/video/123', null, test.today(), null) as post2 \gset
select test.throws('content: evidence link must be https', $$select public.content_log('reel', 'instagram', 'http://x.com/abcdefg', null, current_date, null)$$);
select test.throws('content: same link cannot be counted twice', $$select public.content_log('reel', 'instagram', 'https://www.instagram.com/reel/TESTAAA111/', null, current_date, null)$$);
select test.throws('content: no backfilling beyond 31 days', $$select public.content_log('reel', 'instagram', 'https://x.com/old-post-1', null, current_date - 40, null)$$);
select test.throws('content: poster cannot verify own post', $$select public.content_verify('$$ || :'post1' || $$', true, null)$$);
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.content_verify(:'post1', true, null) \gset x_
select test.throws('content: rejection needs a reason', $$select public.content_verify('$$ || :'post2' || $$', false, '')$$);
select public.content_verify(:'post2', false, 'video is not DIROMA') \gset x_
select test.as_user(:OWNER, 'aal2') \gset x_
select public.target_progress('reels', 'month', test.today(), 'business', null, null) as t_after \gset
select test.ok('content: rejected post excluded; 1 counted, 1 verified', (:'t_after'::jsonb ->> 'actual')::int = 1 and (:'t_after'::jsonb ->> 'verified')::int = 1);

-- ---------------------------------------------------------------- tasks with evidence
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.task_create('Photograph new stock', 'All new suits', :'m_sales', :'loc_shop', now() - interval '1 hour', 'high') as task1 \gset
select public.task_create('Call 5 old customers', null, :'m_sales2', null, now() - interval '1 hour', 'normal') as task2 \gset
select test.as_user(:SALES2, 'aal1') \gset x_
select test.throws('task: only the assignee completes it', $$select public.task_complete('$$ || :'task1' || $$', 'done')$$);
select test.ok('task: staff see only their own tasks', (select count(*) from public.team_tasks) = 1);
select test.as_user(:SALES, 'aal1') \gset x_
select test.throws('task: evidence required', $$select public.task_complete('$$ || :'task1' || $$', ' ')$$);
select public.task_complete(:'task1', '12 photos uploaded to shared album') \gset x_
select test.throws('task: staff cannot verify', $$select public.task_review('$$ || :'task1' || $$', 'verify', null)$$);
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('task: reopening needs a note', $$select public.task_review('$$ || :'task1' || $$', 'reopen', '')$$);
select public.task_review(:'task1', 'verify', 'good') \gset x_
reset role;
select test.ok('task verified by manager', (select status from public.team_tasks where id = :'task1') = 'verified');
set role authenticated;

-- ---------------------------------------------------------------- inquiries & explicit attribution
select test.as_user(:SALES, 'aal1') \gset x_
select public.inquiry_create('Customer A Test', '+255770000001', :'cust_a', 'instagram', 'black suit 48', :'d_suit', null, test.today() + 1) as inq1 \gset
select public.inquiry_create('Walk-in visitor', null, null, 'walk_in', 'shirts', null, null, null) as inq2 \gset
select public.inquiry_event(:'inq1', 'follow_up', 'sent photos on WhatsApp', test.today() + 2) \gset x_
select public.inquiry_event(:'inq1', 'visit', 'came to the shop', null) \gset x_
select test.throws('attribution: sale of a different customer cannot be linked', $$select public.inquiry_link_sale('$$ || :'inq1' || $$', '$$ || :'sale_b' || $$', null)$$);
select public.inquiry_link_sale(:'inq1', :'sale_a', null) \gset x_
select test.throws('attribution: inquiry without customer needs a justification', $$select public.inquiry_link_sale('$$ || :'inq2' || $$', '$$ || :'sale_c' || $$', '')$$);
select test.throws('attribution: one sale cannot be credited to two inquiries', $$select public.inquiry_link_sale('$$ || :'inq2' || $$', '$$ || :'sale_a' || $$', 'same person')$$);
select test.throws('lost needs a reason', $$select public.inquiry_event('$$ || :'inq2' || $$', 'lost', '')$$);
select public.inquiry_event(:'inq2', 'lost', 'price too high', null) \gset x_
select test.ok('follow-up metric counts follow-ups and visits by this seller (2)',
  (public.target_progress('follow_ups', 'month', test.today(), 'member', null, :'m_sales') ->> 'actual')::int = 2);
select test.as_user(:OWNER, 'aal2') \gset x_
select public.inquiry_funnel(test.today() - 1, test.today()) as funnel \gset
reset role;
select test.ok('funnel: instagram 1 inquiry, 1 won via linked sale worth 400,000; walk-in lost',
  (select (f->>'won_linked')::int = 1 and (f->>'linked_sales_value')::bigint = 400000 from jsonb_array_elements(:'funnel'::jsonb) f where f->>'channel' = 'instagram')
  and (select (f->>'lost')::int = 1 and (f->>'won_linked')::int = 0 from jsonb_array_elements(:'funnel'::jsonb) f where f->>'channel' = 'walk_in'));
set role authenticated;

-- ---------------------------------------------------------------- commissions
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('commission plans are Owner-only', $$select public.commission_plan_save(null, 'x', 'sales_staff', null, 'net_sales', 2, 0, false, true)$$);
select test.as_user(:OWNER, 'aal2') \gset x_
select test.throws('rate above 50% rejected', $$select public.commission_plan_save(null, 'x', 'sales_staff', null, 'net_sales', 60, 0, false, true)$$);
select public.commission_plan_save(null, 'Sales staff 2%', 'sales_staff', null, 'net_sales', 2, 0, false, true) as plan_role \gset
select public.commission_plan_save(null, 'Sales Two 5% with tasks', null, :'m_sales2', 'net_sales', 5, 0, true, true) as plan_s2 \gset
select test.as_user(:MANAGER, 'aal2') \gset x_
select public.commission_calculate(test.today(), test.today()) as run1 \gset
select test.throws('no second run over the same period', $$select public.commission_calculate(current_date, current_date)$$);
reset role;
select test.ok('commission: sales 2% of (800,000 − 400,000 returned) = 8,000',
  (select amount from public.commission_lines where run_id = :'run1' and membership_id = :'m_sales') = 8000
  and (select returns_deducted from public.commission_lines where run_id = :'run1' and membership_id = :'m_sales') = 400000);
select test.ok('commission: member plan overrides role plan; open task makes Sales Two ineligible (0)',
  (select rate_pct = 5 and not eligible and amount = 0 and open_tasks = 1 from public.commission_lines where run_id = :'run1' and membership_id = :'m_sales2'));
select test.ok('commission: roles without a plan get no line', not exists (select 1 from public.commission_lines where run_id = :'run1' and membership_id = :'m_mgr'));
set role authenticated;
select test.as_user(:SALES, 'aal1') \gset x_
select test.ok('staff cannot see a run before approval', (select count(*) from public.commission_lines) = 0);
select test.as_user(:MANAGER, 'aal2') \gset x_
select test.throws('manager cannot approve commissions', $$select public.commission_approve('$$ || :'run1' || $$', null)$$);
select test.as_user(:OWNER, 'aal2') \gset x_
select public.commission_approve(:'run1', null) \gset x_
reset role;
select test.ok('approval accrues: commissions expense 8,000 and payable 8,000', test.acct('6500') = 8000 and test.acct('2200') = -8000);
set role authenticated;
select test.as_user(:SALES, 'aal1') \gset x_
select test.ok('after approval each seller sees only their own line', (select count(*) from public.commission_lines) = 1
  and (select amount from public.commission_lines) = 8000);
select test.as_user(:OWNER, 'aal2') \gset x_
select test.throws('commissions are not paid from a cash drawer', $$select public.commission_pay('$$ || :'run1' || $$', '$$ || :'acc_cash' || $$', null)$$);
select public.commission_pay(:'run1', :'acc_bank', 'bank transfer batch 1') \gset x_
select test.throws('commission run cannot be paid twice', $$select public.commission_pay('$$ || :'run1' || $$', '$$ || :'acc_bank' || $$', null)$$);
select test.throws('paid run cannot be cancelled', $$select public.commission_cancel('$$ || :'run1' || $$', 'oops')$$);
select test.ok('P&L counts commissions as an operating expense',
  exists (select 1 from jsonb_array_elements(public.report('pnl', test.today(), test.today()) -> 'expenses') e where e->>'account' = '6500' and (e->>'amount')::bigint = 8000)
  and (public.business_overview(test.today(), test.today()) ->> 'expenses')::bigint >= 8000);
reset role;
select test.ok('payment clears the payable', test.acct('2200') = 0);
set role authenticated;
select test.as_user(:OWNER, 'aal2') \gset x_
select public.commission_calculate(test.today() - 1, test.today() - 1) as run2 \gset
select test.throws('owner approving own calculation needs a reason', $$select public.commission_approve('$$ || :'run2' || $$', '')$$);
select public.commission_approve(:'run2', 'only owner available this week') \gset x_
select public.commission_cancel(:'run2', 'recalculate after correction') \gset x_
reset role;
select test.ok('cancelling an approved run reverses its accrual', test.acct('6500') = 8000);

-- ---------------------------------------------------------------- public catalogue
set role anon;
select set_config('request.jwt.claims', '', false) \gset x_
select test.ok('catalogue disabled: nothing public', public.public_catalogue('diroma') is null);
reset role;
set role authenticated;
select test.as_user(:SALES, 'aal1') \gset x_
select test.throws('sales staff cannot publish designs', $$select public.design_publish('$$ || :'d_suit' || $$', true, true, null)$$);
select test.as_user(:OWNER, 'aal2') \gset x_
select test.throws('slug must be simple', $$select public.catalogue_configure(true, 'Bad Slug!', null)$$);
select public.catalogue_configure(true, 'diroma', '+255760000001') \gset x_
select public.design_publish(:'d_suit', true, true, 'Slim fit, imported') \gset x_
reset role;
set role anon;
select public.public_catalogue('diroma') as cat \gset
select test.ok('public: only the published design is listed', jsonb_array_length(:'cat'::jsonb -> 'designs') = 1
  and :'cat'::jsonb -> 'designs' -> 0 ->> 'code' = 'SUIT-F');
select test.ok('public: retail "from" price shown, no wholesale price or costs anywhere',
  (:'cat'::jsonb -> 'designs' -> 0 ->> 'from_price')::bigint = 400000 and position('330000' in :'cat'::text) = 0
  and position('wholesale' in :'cat'::text) = 0 and position('cost' in :'cat'::text) = 0);
select test.ok('public: availability is yes/no per size, never exact quantities',
  (select bool_and(jsonb_typeof(s->'available') = 'boolean') from jsonb_array_elements(:'cat'::jsonb -> 'designs' -> 0 -> 'sizes') s)
  and position('"qty"' in :'cat'::text) = 0 and position('on_hand' in :'cat'::text) = 0);
select test.throws('anon cannot read tables directly', $$select * from public.designs$$);
select test.throws('anon cannot call staff functions', $$select public.target_progress('reels','month',current_date,'business',null,null)$$);
reset role;

select test.ok('JOURNAL: every entry balances', not exists (select 1 from public.journal_lines group by entry_id having sum(debit) <> sum(credit)));

\ir _report.sql
