-- DIROMA Business OS — Milestone E: full-period reports, scheduled report runs, backup log.
-- All totals are computed in the database over the complete requested period (never a paginated subset).
-- Date bases are explicit: sales by sale date, collections by payment date, balances "as of" a date, all in the
-- business timezone (Africa/Dar_es_Salaam). Buying costs / profit are included only for callers with costs.view.

begin;

-- ---------------------------------------------------------------------------
-- Internal report builders (never granted to clients)
-- ---------------------------------------------------------------------------
create or replace function public._rpt_sales(b uuid, p_from date, p_to date, p_loc uuid, p_costs boolean) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v jsonb; v_ret bigint; v_cogs bigint; v_unknown_units bigint; v_unknown_rev bigint;
begin
  select coalesce(sum(r.amount), 0) into v_ret from public.sale_returns r join public.sales s on s.id = r.sale_id
   where r.business_id = b and r.status = 'approved' and public._business_date(b, r.decided_at) between p_from and p_to
     and (p_loc is null or s.location_id = p_loc);

  with rs as (
    select s.id, public._business_date(b, s.sold_at) sold_date, s.location_id, s.channel, coalesce(s.source, '—') source, s.gross_amount gross,
           s.discount_amount discount, s.total - s.delivery_fee goods, s.delivery_fee delivery, s.total,
           (select coalesce(sum(qty), 0) from public.sale_lines where sale_id = s.id) units, s.payment_status::text payment_status
    from public.sales s
    where s.business_id = b and public._business_date(b, s.sold_at) between p_from and p_to and (p_loc is null or s.location_id = p_loc)
  )
  select jsonb_build_object(
    'totals', (select jsonb_build_object('sales', count(*), 'units', coalesce(sum(units),0), 'gross', coalesce(sum(gross),0),
                 'discounts', coalesce(sum(discount),0), 'goods_net', coalesce(sum(goods),0), 'delivery', coalesce(sum(delivery),0),
                 'invoiced_total', coalesce(sum(total),0), 'returns', v_ret, 'net_sales', coalesce(sum(goods),0) - v_ret) from rs),
    'by_day', (select coalesce(jsonb_agg(x order by x->>'date'), '[]') from (
                 select jsonb_build_object('date', d::date, 'sales', count(rs.id), 'units', coalesce(sum(rs.units),0),
                   'gross', coalesce(sum(rs.gross),0), 'discounts', coalesce(sum(rs.discount),0), 'goods_net', coalesce(sum(rs.goods),0),
                   'delivery', coalesce(sum(rs.delivery),0)) x
                 from generate_series(p_from, p_to, interval '1 day') d left join rs on rs.sold_date = d::date
                 group by d) t),
    'by_channel', (select coalesce(jsonb_agg(jsonb_build_object('key', channel, 'sales', n, 'goods_net', g) order by g desc), '[]')
                   from (select channel, count(*) n, sum(goods) g from rs group by channel) t),
    'by_source', (select coalesce(jsonb_agg(jsonb_build_object('key', source, 'sales', n, 'goods_net', g) order by g desc), '[]')
                  from (select source, count(*) n, sum(goods) g from rs group by source) t),
    'by_location', (select coalesce(jsonb_agg(jsonb_build_object('key', l.name, 'sales', n, 'goods_net', g) order by g desc), '[]')
                    from (select location_id, count(*) n, sum(goods) g from rs group by location_id) t join public.locations l on l.id = t.location_id),
    'by_payment_status', (select coalesce(jsonb_agg(jsonb_build_object('key', payment_status, 'sales', n, 'total', g)), '[]')
                    from (select payment_status, count(*) n, sum(total) g from rs group by payment_status) t),
    '_unknown', (select jsonb_build_object('units', coalesce(sum(sl.qty), 0), 'revenue', coalesce(sum(sl.line_total), 0))
                 from rs join public.sale_lines sl on sl.sale_id = rs.id join public.sale_line_costs c on c.sale_line_id = sl.id where not c.cost_known)
  ) into v;
  v_unknown_units := (v->'_unknown'->>'units')::bigint; v_unknown_rev := (v->'_unknown'->>'revenue')::bigint;
  v := v - '_unknown';
  if p_costs then
    select coalesce(sum(jl.debit - jl.credit), 0) into v_cogs from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
     where je.business_id = b and je.entry_date between p_from and p_to and jl.account_code = '5000';
    v := v || jsonb_build_object('costs', jsonb_build_object('cogs', v_cogs, 'gross_profit', (v->'totals'->>'net_sales')::bigint - v_cogs,
           'margin_pct', case when (v->'totals'->>'net_sales')::bigint > 0 then round(((v->'totals'->>'net_sales')::numeric - v_cogs) * 100 / (v->'totals'->>'net_sales')::numeric, 1) end,
           'units_cost_unknown', v_unknown_units, 'revenue_cost_unknown', v_unknown_rev,
           'note', case when v_unknown_units > 0 then 'profit incomplete: some units have no known cost' end));
  end if;
  return v;
end $$;

create or replace function public._rpt_collections(b uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  return (
    with p as (
      select p.*, public._business_date(b, p.received_at) d from public.payments p
      where p.business_id = b and public._business_date(b, p.received_at) between p_from and p_to
    ), alloc as (
      select ss.payment_id,
             sum(ss.amount) filter (where public._business_date(b, s.sold_at) >= p_from) as current_sales,
             sum(ss.amount) filter (where public._business_date(b, s.sold_at) < p_from) as old_debt,
             sum(ss.amount) as allocated
      from public.sale_settlements ss join public.sales s on s.id = ss.sale_id
      where ss.payment_id in (select id from p) group by ss.payment_id
    )
    select jsonb_build_object(
      'totals', jsonb_build_object(
         'collections', coalesce((select sum(amount) from p), 0),
         'for_period_sales', coalesce((select sum(current_sales) from alloc), 0),
         'old_debt', coalesce((select sum(old_debt) from alloc), 0),
         'advances_to_credit', coalesce((select sum(p.amount - coalesce(a.allocated, 0)) from p left join alloc a on a.payment_id = p.id), 0),
         'credit_applied', coalesce((select sum(ss.amount) from public.sale_settlements ss join public.sales s on s.id = ss.sale_id
             where s.business_id = b and ss.kind = 'customer_credit' and public._business_date(b, ss.created_at) between p_from and p_to), 0),
         'refunds_paid', coalesce((select sum(jl.credit) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
             where je.business_id = b and je.source_type = 'refund' and jl.account_code = '1000' and je.entry_date between p_from and p_to), 0),
         'manual_unverified', coalesce((select sum(amount) from p where verification = 'manual' and method <> 'cash'), 0)),
      'by_method', (select coalesce(jsonb_agg(jsonb_build_object('key', method, 'amount', amt, 'count', n) order by amt desc), '[]')
                    from (select method::text, sum(amount) amt, count(*) n from p group by method) t),
      'by_account', (select coalesce(jsonb_agg(jsonb_build_object('key', a.name, 'amount', amt, 'count', n) order by amt desc), '[]')
                     from (select money_account_id, sum(amount) amt, count(*) n from p group by money_account_id) t
                     join public.money_accounts a on a.id = t.money_account_id),
      'by_day', (select coalesce(jsonb_agg(jsonb_build_object('date', d, 'amount', amt) order by d), '[]')
                 from (select d, sum(amount) amt from p group by d) t)
    )
  );
end $$;

create or replace function public._acct_balance(b uuid, p_code text, p_as_of date) returns bigint
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(jl.debit - jl.credit), 0)::bigint from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
  where je.business_id = b and jl.account_code = p_code and je.entry_date <= p_as_of
$$;
create or replace function public._acct_movement(b uuid, p_code text, p_from date, p_to date) returns bigint
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(jl.credit - jl.debit), 0)::bigint from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
  where je.business_id = b and jl.account_code = p_code and je.entry_date between p_from and p_to
$$;

-- Why collections differ from sales: collections = net sales + delivery − Δreceivables + Δcustomer credits + refunds paid.
create or replace function public._rpt_reconciliation(b uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_net bigint; v_del bigint; ar0 bigint; ar1 bigint; cr0 bigint; cr1 bigint; v_ref bigint; v_col bigint; v_expected bigint;
begin
  v_net := public._acct_movement(b, '4000', p_from, p_to) + public._acct_movement(b, '4900', p_from, p_to);
  v_del := public._acct_movement(b, '4100', p_from, p_to);
  ar0 := public._acct_balance(b, '1100', p_from - 1); ar1 := public._acct_balance(b, '1100', p_to);
  cr0 := -public._acct_balance(b, '2000', p_from - 1); cr1 := -public._acct_balance(b, '2000', p_to);
  select coalesce(sum(jl.credit), 0) into v_ref from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
   where je.business_id = b and je.source_type = 'refund' and jl.account_code = '1000' and je.entry_date between p_from and p_to;
  select coalesce(sum(amount), 0) into v_col from public.payments where business_id = b and public._business_date(b, received_at) between p_from and p_to;
  v_expected := v_net + v_del - (ar1 - ar0) + (cr1 - cr0) + v_ref;
  return jsonb_build_object(
    'net_sales', v_net, 'delivery_income', v_del,
    'receivables_opening', ar0, 'receivables_closing', ar1, 'receivables_change', ar1 - ar0,
    'credits_opening', cr0, 'credits_closing', cr1, 'credits_change', cr1 - cr0,
    'refunds_paid', v_ref, 'expected_collections', v_expected, 'actual_collections', v_col,
    'unexplained_difference', v_col - v_expected);
end $$;

create or replace function public._rpt_ageing(b uuid, p_as_of date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_end timestamptz := (p_as_of + 1)::timestamp at time zone (select timezone from public.businesses where id = b);
begin
  return (
    with open_sales as (
      select s.id, s.customer_id, s.ref_no, public._business_date(b, s.sold_at) sold_date, c.terms_days,
             s.total - coalesce((select sum(ss.amount) from public.sale_settlements ss where ss.sale_id = s.id and ss.created_at < v_end), 0) bal
      from public.sales s join public.customers c on c.id = s.customer_id
      where s.business_id = b and s.sold_at < v_end
    ), aged as (
      select *, p_as_of - (sold_date + terms_days) as days_over from open_sales where bal > 0
    ), per as (
      select customer_id,
        sum(bal) filter (where days_over <= 0) b_current, sum(bal) filter (where days_over between 1 and 7) b_1_7,
        sum(bal) filter (where days_over between 8 and 30) b_8_30, sum(bal) filter (where days_over between 31 and 60) b_31_60,
        sum(bal) filter (where days_over between 61 and 90) b_61_90, sum(bal) filter (where days_over > 90) b_90p,
        sum(bal) total, max(days_over) worst_days, count(*) invoices
      from aged group by customer_id
    )
    select jsonb_build_object('as_of', p_as_of,
      'rows', coalesce((select jsonb_agg(jsonb_build_object('customer_id', per.customer_id, 'customer', c.name, 'phone', c.phone_e164, 'kind', c.kind,
               'current', coalesce(b_current,0), 'd1_7', coalesce(b_1_7,0), 'd8_30', coalesce(b_8_30,0), 'd31_60', coalesce(b_31_60,0),
               'd61_90', coalesce(b_61_90,0), 'd90p', coalesce(b_90p,0), 'total', total, 'worst_days', worst_days, 'invoices', invoices) order by total desc)
             from per join public.customers c on c.id = per.customer_id), '[]'),
      'totals', (select jsonb_build_object('current', coalesce(sum(b_current),0), 'd1_7', coalesce(sum(b_1_7),0), 'd8_30', coalesce(sum(b_8_30),0),
               'd31_60', coalesce(sum(b_31_60),0), 'd61_90', coalesce(sum(b_61_90),0), 'd90p', coalesce(sum(b_90p),0), 'total', coalesce(sum(total),0)) from per),
      'ledger_receivables', public._acct_balance(b, '1100', p_as_of))
  );
end $$;

create or replace function public._rpt_pnl(b uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_rev bigint; v_ret bigint; v_del bigint; v_cogs bigint; v_exp jsonb; v_exp_total bigint; v_unknown bigint;
begin
  v_rev := public._acct_movement(b, '4000', p_from, p_to);
  v_ret := -public._acct_movement(b, '4900', p_from, p_to);
  v_del := public._acct_movement(b, '4100', p_from, p_to);
  v_cogs := -public._acct_movement(b, '5000', p_from, p_to);
  select coalesce(jsonb_agg(jsonb_build_object('account', account_code, 'name', name, 'category', category, 'amount', amt) order by account_code, amt desc), '[]'),
         coalesce(sum(amt), 0) into v_exp, v_exp_total
  from (select jl.account_code, la.name, coalesce(jl.category, '') category, sum(jl.debit - jl.credit) amt
        from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id join public.ledger_accounts la on la.code = jl.account_code
        where je.business_id = b and je.entry_date between p_from and p_to and jl.account_code in ('6000','6100','6200','6300','6400')
        group by jl.account_code, la.name, coalesce(jl.category, '')) t;
  select coalesce(sum(sl.qty), 0) into v_unknown from public.sale_lines sl join public.sales s on s.id = sl.sale_id
    join public.sale_line_costs c on c.sale_line_id = sl.id
   where s.business_id = b and not c.cost_known and public._business_date(b, s.sold_at) between p_from and p_to;
  return jsonb_build_object('revenue', v_rev, 'returns', v_ret, 'net_revenue', v_rev - v_ret, 'delivery_income', v_del,
    'cogs', v_cogs, 'gross_profit', v_rev - v_ret - v_cogs, 'expenses', v_exp, 'expenses_total', v_exp_total,
    'operating_profit', v_rev - v_ret + v_del - v_cogs - v_exp_total, 'units_cost_unknown', v_unknown,
    'complete', v_unknown = 0,
    'basis', 'Accrual: revenue by sale date, COGS at average cost at sale time, expenses by expense date. Not a tax computation.');
end $$;

create or replace function public._rpt_stock(b uuid, p_costs boolean) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  return (
    with bal as (
      select sb.variant_id, l.kind, sum(sb.on_hand) qty from public.stock_balances sb join public.locations l on l.id = sb.location_id
      where l.business_id = b group by sb.variant_id, l.kind
    ), v as (
      select vr.id variant_id, d.code, d.name, vr.color, vr.size,
        coalesce(sum(bal.qty) filter (where bal.kind = 'warehouse'), 0) store,
        coalesce(sum(bal.qty) filter (where bal.kind = 'shop'), 0) shop,
        coalesce(sum(bal.qty) filter (where bal.kind = 'transit'), 0) transit,
        coalesce(sum(bal.qty) filter (where bal.kind in ('inspection','quarantine')), 0) inspection,
        coalesce(sum(bal.qty) filter (where bal.kind = 'partner'), 0) partners,
        coalesce(sum(bal.qty), 0) total
      from public.variants vr join public.designs d on d.id = vr.design_id left join bal on bal.variant_id = vr.id
      where vr.business_id = b group by vr.id, d.code, d.name, vr.color, vr.size
    ), sold as (
      select sl.variant_id, sum(sl.qty) filter (where s.sold_at >= now() - interval '30 days') s30,
             sum(sl.qty) filter (where s.sold_at >= now() - interval '90 days') s90
      from public.sale_lines sl join public.sales s on s.id = sl.sale_id where s.business_id = b group by sl.variant_id
    ), inb as (
      select m.variant_id, max(m.created_at) last_in from public.stock_movements m join public.stock_documents dd on dd.id = m.document_id
      where m.business_id = b and m.qty_delta > 0 and dd.doc_type in ('goods_receipt','opening') group by m.variant_id
    )
    select jsonb_build_object(
      'rows', coalesce(jsonb_agg(jsonb_build_object('variant_id', v.variant_id, 'code', v.code, 'name', v.name, 'color', v.color, 'size', v.size,
          'store', v.store, 'shop', v.shop, 'transit', v.transit, 'inspection', v.inspection, 'partners', v.partners, 'total', v.total,
          'sold_30', coalesce(sold.s30, 0), 'sold_90', coalesce(sold.s90, 0),
          'cover_days', case when coalesce(sold.s30, 0) > 0 then round((v.store + v.shop)::numeric * 30 / sold.s30) end,
          'age_days', case when inb.last_in is not null then (now()::date - inb.last_in::date) end,
          'unit_cost', case when p_costs then vc.avg_cost end,
          'value', case when p_costs and vc.avg_cost is not null then v.total * vc.avg_cost end)
        order by v.code, v.color, v.size) filter (where v.total > 0), '[]'),
      'totals', jsonb_build_object('store', sum(v.store), 'shop', sum(v.shop), 'transit', sum(v.transit), 'inspection', sum(v.inspection),
          'partners', sum(v.partners), 'total', sum(v.total),
          'value_known', case when p_costs then coalesce(sum(v.total * vc.avg_cost), 0) end,
          'units_without_cost', case when p_costs then coalesce(sum(v.total) filter (where vc.avg_cost is null), 0) end,
          'slow_units_90d_no_sales', coalesce(sum(v.store + v.shop) filter (where coalesce(sold.s90, 0) = 0), 0)))
    from v left join sold on sold.variant_id = v.variant_id left join inb on inb.variant_id = v.variant_id
    left join public.variant_costs vc on vc.variant_id = v.variant_id
  );
end $$;

create or replace function public._rpt_products(b uuid, p_from date, p_to date, p_costs boolean) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  return (
    with sold as (
      select sl.variant_id, sum(sl.qty) units, sum(sl.line_total) revenue, sum(sl.discount) discounts,
             sum(case when c.cost_known then c.unit_cost * sl.qty end) cogs, bool_and(c.cost_known) all_known
      from public.sale_lines sl join public.sales s on s.id = sl.sale_id join public.sale_line_costs c on c.sale_line_id = sl.id
      where s.business_id = b and public._business_date(b, s.sold_at) between p_from and p_to group by sl.variant_id
    ), ret as (
      select rl.variant_id, sum(rl.qty) units, sum(rl.amount) amount,
             sum(case when c.cost_known then c.unit_cost * rl.qty end) cogs
      from public.sale_return_lines rl join public.sale_returns r on r.id = rl.return_id
      join public.sale_line_costs c on c.sale_line_id = rl.sale_line_id
      where r.business_id = b and r.status = 'approved' and public._business_date(b, r.decided_at) between p_from and p_to group by rl.variant_id
    ), onh as (
      select sb.variant_id, sum(sb.on_hand) qty from public.stock_balances sb join public.locations l on l.id = sb.location_id
      where l.business_id = b and l.kind in ('warehouse','shop','partner') group by sb.variant_id
    ), r as (
      select vr.id variant_id, d.code, d.name, d.category, vr.color, vr.size,
             coalesce(sold.units,0) - coalesce(ret.units,0) net_units, coalesce(sold.revenue,0) - coalesce(ret.amount,0) net_revenue,
             coalesce(sold.discounts,0) discounts, coalesce(sold.cogs,0) - coalesce(ret.cogs,0) cogs, coalesce(sold.all_known, true) cost_complete,
             coalesce(onh.qty,0) on_hand
      from public.variants vr join public.designs d on d.id = vr.design_id
      left join sold on sold.variant_id = vr.id left join ret on ret.variant_id = vr.id left join onh on onh.variant_id = vr.id
      where vr.business_id = b and (sold.variant_id is not null or ret.variant_id is not null)
    )
    select jsonb_build_object(
      'rows', coalesce(jsonb_agg(jsonb_build_object('variant_id', variant_id, 'code', code, 'name', name, 'category', category, 'color', color, 'size', size,
          'units', net_units, 'revenue', net_revenue, 'discounts', discounts, 'on_hand', on_hand,
          'sell_through_pct', case when net_units + on_hand > 0 then round(net_units::numeric * 100 / (net_units + on_hand), 1) end,
          'cogs', case when p_costs then cogs end,
          'gross_profit', case when p_costs then net_revenue - cogs end,
          'margin_pct', case when p_costs and net_revenue > 0 then round((net_revenue - cogs)::numeric * 100 / net_revenue, 1) end,
          'cost_complete', cost_complete) order by net_revenue desc), '[]'),
      'totals', jsonb_build_object('units', coalesce(sum(net_units),0), 'revenue', coalesce(sum(net_revenue),0),
          'cogs', case when p_costs then coalesce(sum(cogs),0) end, 'cost_complete', coalesce(bool_and(cost_complete), true)))
    from r
  );
end $$;

create or replace function public._rpt_expenses(b uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  return jsonb_build_object(
    'by_category', (select coalesce(jsonb_agg(jsonb_build_object('key', category, 'paid', paid, 'count', n) order by paid desc), '[]')
                    from (select category, sum(amount) filter (where status = 'paid') paid, count(*) n from public.expenses
                          where business_id = b and expense_date between p_from and p_to and status = 'paid' group by category) t),
    'by_location', (select coalesce(jsonb_agg(jsonb_build_object('key', coalesce(l.name, '—'), 'paid', paid) order by paid desc), '[]')
                    from (select location_id, sum(amount) paid from public.expenses
                          where business_id = b and expense_date between p_from and p_to and status = 'paid' group by location_id) t
                    left join public.locations l on l.id = t.location_id),
    'totals', (select jsonb_build_object('paid', coalesce(sum(amount) filter (where status = 'paid'), 0),
                 'approved_unpaid', coalesce(sum(amount) filter (where status = 'approved'), 0),
                 'awaiting_approval', coalesce(sum(amount) filter (where status = 'requested'), 0))
               from public.expenses where business_id = b and expense_date between p_from and p_to),
    'other_costs', jsonb_build_object(
      'courier', -public._acct_movement(b, '6100', p_from, p_to), 'stock_losses', -public._acct_movement(b, '6200', p_from, p_to),
      'cash_over_short', -public._acct_movement(b, '6300', p_from, p_to), 'fees', -public._acct_movement(b, '6400', p_from, p_to)));
end $$;

create or replace function public._rpt_staff(b uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  return (select coalesce(jsonb_agg(x order by (x->>'goods_net')::bigint desc), '[]') from (
    select jsonb_build_object('membership_id', m.id, 'name', m.display_name, 'role', m.role,
      'sales', (select count(*) from public.sales s where s.sold_by = m.id and public._business_date(b, s.sold_at) between p_from and p_to),
      'goods_net', (select coalesce(sum(s.total - s.delivery_fee), 0) from public.sales s where s.sold_by = m.id and public._business_date(b, s.sold_at) between p_from and p_to),
      'discounts', (select coalesce(sum(s.discount_amount), 0) from public.sales s where s.sold_by = m.id and public._business_date(b, s.sold_at) between p_from and p_to),
      'returns_on_their_sales', (select coalesce(sum(r.amount), 0) from public.sale_returns r join public.sales s on s.id = r.sale_id
          where s.sold_by = m.id and r.status = 'approved' and public._business_date(b, r.decided_at) between p_from and p_to),
      'collections', (select coalesce(sum(p.amount), 0) from public.payments p where p.received_by = m.id and public._business_date(b, p.received_at) between p_from and p_to),
      'shifts_closed', (select count(*) from public.shifts sh where sh.opened_by = m.id and sh.closed_at is not null and public._business_date(b, sh.closed_at) between p_from and p_to),
      'cash_variance', (select coalesce(sum(sh.variance), 0) from public.shifts sh where sh.opened_by = m.id and sh.closed_at is not null and public._business_date(b, sh.closed_at) between p_from and p_to)) x
    from public.memberships m where m.business_id = b and m.status in ('active','suspended')) t);
end $$;

create or replace function public._rpt_exceptions(b uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_start timestamptz := p_from::timestamp at time zone (select timezone from public.businesses where id = b);
        v_end timestamptz := (p_to + 1)::timestamp at time zone (select timezone from public.businesses where id = b);
begin
  return jsonb_build_object(
    'approvals', (select coalesce(jsonb_agg(jsonb_build_object('reason', reason, 'status', status, 'count', n)), '[]')
                  from (select unnest(reasons) reason, status::text status, count(*) n from public.approval_requests
                        where business_id = b and created_at >= v_start and created_at < v_end group by 1, 2) t),
    'discounted_sales', (select jsonb_build_object('count', count(*), 'amount', coalesce(sum(discount_amount), 0)) from public.sales
                         where business_id = b and discount_amount > 0 and sold_at >= v_start and sold_at < v_end),
    'backdated_sales', (select coalesce(jsonb_agg(jsonb_build_object('ref', ref_no, 'sold_at', sold_at, 'entered_at', entered_at, 'total', total)), '[]')
                        from public.sales where business_id = b and entered_at - sold_at > interval '30 minutes' and entered_at >= v_start and entered_at < v_end),
    'shift_variances', (select coalesce(jsonb_agg(jsonb_build_object('ref', s.ref_no, 'cashier', m.display_name, 'variance', s.variance, 'reason', s.variance_reason, 'status', s.status)), '[]')
                        from public.shifts s join public.memberships m on m.id = s.opened_by
                        where s.business_id = b and s.variance <> 0 and s.closed_at >= v_start and s.closed_at < v_end),
    'count_variances', (select coalesce(jsonb_agg(jsonb_build_object('ref', c.ref_no, 'variant_id', l.variant_id, 'variance', l.variance)), '[]')
                        from public.stock_counts c join public.stock_count_lines l on l.count_id = c.id
                        where c.business_id = b and c.status = 'approved' and l.variance <> 0 and c.decided_at >= v_start and c.decided_at < v_end),
    'transit_shortages', (select jsonb_build_object('count', count(*), 'units', coalesce(sum(qty), 0), 'open', count(*) filter (where status = 'open'))
                          from public.transfer_discrepancies where business_id = b and created_at >= v_start and created_at < v_end),
    'stock_losses_value', -public._acct_movement(b, '6200', p_from, p_to),
    'refunds', (select jsonb_build_object('count', count(*), 'amount', coalesce(sum(jl.credit), 0)) from public.journal_lines jl
                join public.journal_entries je on je.id = jl.entry_id where je.business_id = b and je.source_type = 'refund'
                and jl.account_code = '1000' and je.entry_date between p_from and p_to),
    'failed_deliveries', (select count(*) from public.sales where business_id = b and fulfillment_status = 'failed_delivery' and sold_at >= v_start and sold_at < v_end),
    'consignment_losses', (select jsonb_build_object('count', count(*), 'units', coalesce(sum(qty), 0), 'pending', count(*) filter (where status = 'pending'))
                           from public.consignment_losses where business_id = b and created_at >= v_start and created_at < v_end));
end $$;

create or replace function public._rpt_wholesale(b uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_start timestamptz := p_from::timestamp at time zone (select timezone from public.businesses where id = b);
        v_end timestamptz := (p_to + 1)::timestamp at time zone (select timezone from public.businesses where id = b);
begin
  return (select coalesce(jsonb_agg(x order by x->>'partner'), '[]') from (
    select jsonb_build_object('partner_id', c.id, 'partner', c.name,
      'dispatched', (select coalesce(sum(dl.qty), 0) from public.consignment_dispatch_lines dl where dl.partner_id = c.id and dl.created_at >= v_start and dl.created_at < v_end),
      'reported_sold', (select coalesce(sum(rl.sold), 0) from public.consignment_report_lines rl join public.consignment_reports r on r.id = rl.report_id where r.partner_id = c.id and r.report_date between p_from and p_to),
      'reported_returned', (select coalesce(sum(rl.returned), 0) from public.consignment_report_lines rl join public.consignment_reports r on r.id = rl.report_id where r.partner_id = c.id and r.report_date between p_from and p_to),
      'reported_lost', (select coalesce(sum(rl.lost), 0) from public.consignment_report_lines rl join public.consignment_reports r on r.id = rl.report_id where r.partner_id = c.id and r.report_date between p_from and p_to),
      'invoiced', (select coalesce(sum(s.total), 0) from public.sales s where s.customer_id = c.id and s.channel = 'wholesale' and public._business_date(b, s.sold_at) between p_from and p_to),
      'collected', (select coalesce(sum(p.amount), 0) from public.payments p where p.customer_id = c.id and public._business_date(b, p.received_at) between p_from and p_to),
      'held_now', (select coalesce(sum(dl.qty - dl.qty_sold - dl.qty_returned - dl.qty_lost), 0) from public.consignment_dispatch_lines dl where dl.partner_id = c.id),
      'outstanding_now', public._customer_receivable(c.id)) x
    from public.customers c where c.business_id = b and c.kind = 'wholesale') t);
end $$;

create or replace function public._trial_balance(b uuid, p_as_of date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  return (select jsonb_build_object('as_of', p_as_of,
      'rows', coalesce(jsonb_agg(jsonb_build_object('code', la.code, 'name', la.name, 'type', la.type, 'debit', d, 'credit', c, 'balance', d - c) order by la.code), '[]'),
      'total_debit', coalesce(sum(d), 0), 'total_credit', coalesce(sum(c), 0))
    from (select jl.account_code, sum(jl.debit) d, sum(jl.credit) c from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
          where je.business_id = b and je.entry_date <= p_as_of group by jl.account_code) t
    join public.ledger_accounts la on la.code = t.account_code);
end $$;

-- ---------------------------------------------------------------------------
-- Public entry point (permission-checked)
-- ---------------------------------------------------------------------------
create or replace function public.report(p_kind text, p_from date, p_to date, p_location uuid default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare b uuid; v_costs boolean;
begin
  if not public.has_permission('reports.view') then raise exception 'not authorized: reports.view' using errcode = '42501'; end if;
  if p_from is null or p_to is null or p_to < p_from then raise exception 'invalid period' using errcode = '22023'; end if;
  if p_to - p_from > 3700 then raise exception 'period too long (max 10 years)' using errcode = '22023'; end if;
  b := (public.current_membership()).business_id;
  v_costs := public.has_permission('costs.view');
  return case p_kind
    when 'sales' then public._rpt_sales(b, p_from, p_to, p_location, v_costs)
    when 'collections' then public._rpt_collections(b, p_from, p_to)
    when 'reconciliation' then public._rpt_reconciliation(b, p_from, p_to)
    when 'ageing' then public._rpt_ageing(b, p_to)
    when 'pnl' then case when v_costs then public._rpt_pnl(b, p_from, p_to) else null end
    when 'stock' then public._rpt_stock(b, v_costs)
    when 'products' then public._rpt_products(b, p_from, p_to, v_costs)
    when 'expenses' then public._rpt_expenses(b, p_from, p_to)
    when 'staff' then public._rpt_staff(b, p_from, p_to)
    when 'exceptions' then public._rpt_exceptions(b, p_from, p_to)
    when 'wholesale' then public._rpt_wholesale(b, p_from, p_to)
    when 'trial_balance' then case when public.has_permission('journal.view') then public._trial_balance(b, p_to) else null end
    else null end;
end $$;

-- Earliest business date with any data (to mark comparisons "unavailable" before it).
create or replace function public.data_start_date() returns date
language sql stable security definer set search_path = '' as $$
  select least((select min(entry_date) from public.journal_entries where business_id = (public.current_membership()).business_id),
               (select min(public._business_date(business_id, created_at))::date from public.stock_movements where business_id = (public.current_membership()).business_id))
$$;

-- ---------------------------------------------------------------------------
-- Scheduled report runs (service role)
-- ---------------------------------------------------------------------------
create type public.run_status as enum ('running', 'succeeded', 'failed', 'skipped');

create table public.report_runs (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references public.businesses(id),
  kind          text not null check (kind in ('daily_interim','daily_final')),
  business_date date not null,
  version       int not null,
  fingerprint   text not null,
  status        public.run_status not null default 'running',
  triggered_by  text not null default 'schedule',
  attempt       int not null default 1,
  started_at    timestamptz not null default now(),
  finished_at   timestamptz,
  file_path     text,
  sha256        text,
  size_bytes    bigint,
  error         text,
  unique (business_id, kind, business_date, version)
);

create table public.backup_runs (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid references public.businesses(id),
  kind         text not null check (kind in ('backup','restore_test')),
  status       public.run_status not null,
  started_at   timestamptz not null default now(),
  finished_at  timestamptz,
  location     text,
  manifest     jsonb,
  error        text
);

-- Fingerprint of everything recorded for a business date: a new version is produced only when data changed.
create or replace function public._day_fingerprint(b uuid, p_date date) returns text
language sql stable security definer set search_path = '' as $$
  select md5(concat_ws('|',
    (select count(*) || ':' || coalesce(sum(jl.debit), 0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
      where je.business_id = b and je.entry_date = p_date),
    (select count(*) || ':' || coalesce(sum(qty_delta), 0) from public.stock_movements where business_id = b and public._business_date(b, created_at) = p_date),
    (select count(*) from public.shifts where business_id = b and closed_at is not null and public._business_date(b, closed_at) = p_date)))
$$;

create or replace function public.job_begin(p_business uuid, p_kind text, p_date date, p_trigger text default 'schedule')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_fp text; r public.report_runs; v_ver int; v_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_business::text || p_kind || p_date::text, 0));
  v_fp := public._day_fingerprint(p_business, p_date);
  select * into r from public.report_runs where business_id = p_business and kind = p_kind and business_date = p_date
   order by version desc limit 1;
  if r.id is not null and r.status = 'running' and r.started_at > now() - interval '15 minutes' then
    return jsonb_build_object('skip', true, 'reason', 'another run is in progress', 'run_id', r.id);
  end if;
  if r.id is not null and r.status = 'succeeded' and r.fingerprint = v_fp then
    return jsonb_build_object('skip', true, 'reason', 'no new data since version ' || r.version, 'run_id', r.id);
  end if;
  if r.id is not null and r.status in ('failed','running') and r.fingerprint = v_fp then
    -- retry the same version (bounded by attempt counter)
    if r.attempt >= 3 then return jsonb_build_object('skip', true, 'reason', 'max attempts reached; needs attention', 'run_id', r.id); end if;
    update public.report_runs set status = 'running', attempt = attempt + 1, started_at = now(), error = null, triggered_by = p_trigger where id = r.id;
    return jsonb_build_object('skip', false, 'run_id', r.id, 'version', r.version, 'fingerprint', v_fp);
  end if;
  v_ver := coalesce((select max(version) from public.report_runs where business_id = p_business and kind = p_kind and business_date = p_date), 0) + 1;
  insert into public.report_runs (business_id, kind, business_date, version, fingerprint, triggered_by)
  values (p_business, p_kind, p_date, v_ver, v_fp, p_trigger) returning id into v_id;
  return jsonb_build_object('skip', false, 'run_id', v_id, 'version', v_ver, 'fingerprint', v_fp);
end $$;

create or replace function public.job_finish(p_run uuid, p_ok boolean, p_path text, p_sha256 text, p_size bigint, p_error text)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.report_runs set status = case when p_ok then 'succeeded'::public.run_status else 'failed'::public.run_status end,
         finished_at = now(), file_path = p_path, sha256 = p_sha256, size_bytes = p_size, error = left(p_error, 2000)
   where id = p_run and status = 'running';
  if not found then raise exception 'run is not running' using errcode = '22023'; end if;
end $$;

-- Everything the daily PDF contains, computed in one consistent snapshot.
create or replace function public.daily_snapshot(p_business uuid, p_date date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  return jsonb_build_object(
    'business', (select jsonb_build_object('name', name, 'timezone', timezone, 'currency', currency) from public.businesses where id = p_business),
    'date', p_date, 'generated_at', now(), 'fingerprint', public._day_fingerprint(p_business, p_date),
    'sales', public._rpt_sales(p_business, p_date, p_date, null, true),
    'collections', public._rpt_collections(p_business, p_date, p_date),
    'reconciliation', public._rpt_reconciliation(p_business, p_date, p_date),
    'pnl', public._rpt_pnl(p_business, p_date, p_date),
    'expenses', public._rpt_expenses(p_business, p_date, p_date),
    'exceptions', public._rpt_exceptions(p_business, p_date, p_date),
    'money', (select coalesce(jsonb_agg(jsonb_build_object('account', a.name, 'kind', a.kind,
               'balance', (select coalesce(sum(jl.debit - jl.credit), 0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
                           where jl.money_account_id = a.id and jl.account_code = '1000' and je.entry_date <= p_date)) order by a.kind, a.code), '[]')
              from public.money_accounts a where a.business_id = p_business),
    'shifts', (select coalesce(jsonb_agg(jsonb_build_object('ref', s.ref_no, 'cashier', m.display_name, 'status', s.status, 'expected', s.expected_cash,
               'counted', s.counted_cash, 'variance', s.variance)), '[]')
               from public.shifts s join public.memberships m on m.id = s.opened_by
               where s.business_id = p_business and (public._business_date(p_business, s.opened_at) = p_date or s.status = 'open'
                     or (s.closed_at is not null and public._business_date(p_business, s.closed_at) = p_date))),
    'stock', (public._rpt_stock(p_business, true)) -> 'totals',
    'ageing', (public._rpt_ageing(p_business, p_date)) -> 'totals');
end $$;

-- Owner / Control Center view of scheduled runs and backups.
create or replace function public.job_status() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare b uuid;
begin
  if not (public.has_permission('audit.view') or public.has_permission('money.view')) then raise exception 'not authorized' using errcode = '42501'; end if;
  b := (public.current_membership()).business_id;
  return jsonb_build_object(
    'reports', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'date', business_date, 'version', version, 'status', status,
                 'attempt', attempt, 'started_at', started_at, 'finished_at', finished_at, 'file_path', file_path, 'sha256', sha256,
                 'size', size_bytes, 'error', error, 'triggered_by', triggered_by) order by started_at desc), '[]')
                from (select * from public.report_runs where business_id = b order by started_at desc limit 30) t),
    'last_report_success', (select max(finished_at) from public.report_runs where business_id = b and status = 'succeeded'),
    'report_failures_7d', (select count(*) from public.report_runs where business_id = b and status = 'failed' and started_at > now() - interval '7 days'),
    'backups', (select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'status', status, 'started_at', started_at, 'finished_at', finished_at,
                 'location', location, 'manifest', manifest, 'error', error) order by started_at desc), '[]')
                from (select * from public.backup_runs where business_id = b or business_id is null order by started_at desc limit 20) t),
    'last_backup_success', (select max(finished_at) from public.backup_runs where kind = 'backup' and status = 'succeeded' and (business_id = b or business_id is null)),
    'last_restore_test_success', (select max(finished_at) from public.backup_runs where kind = 'restore_test' and status = 'succeeded' and (business_id = b or business_id is null)));
end $$;

-- Recovery-verification manifest: the numbers a restored copy must reproduce exactly.
create or replace function public.recovery_manifest() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'rows', jsonb_build_object(
      'memberships', (select count(*) from public.memberships), 'variants', (select count(*) from public.variants),
      'stock_movements', (select count(*) from public.stock_movements), 'journal_entries', (select count(*) from public.journal_entries),
      'journal_lines', (select count(*) from public.journal_lines), 'sales', (select count(*) from public.sales),
      'payments', (select count(*) from public.payments), 'audit_log', (select count(*) from public.audit_log),
      'consignment_dispatch_lines', (select count(*) from public.consignment_dispatch_lines)),
    'totals', jsonb_build_object(
      'journal_debit', (select coalesce(sum(debit), 0) from public.journal_lines),
      'journal_credit', (select coalesce(sum(credit), 0) from public.journal_lines),
      'stock_on_hand', (select coalesce(sum(on_hand), 0) from public.stock_balances),
      'stock_movements_sum', (select coalesce(sum(qty_delta), 0) from public.stock_movements),
      'receivables', (select coalesce(sum(debit - credit), 0) from public.journal_lines where account_code = '1100'),
      'money', (select coalesce(sum(debit - credit), 0) from public.journal_lines where account_code = '1000'),
      'sales_total', (select coalesce(sum(total), 0) from public.sales)),
    'checksums', jsonb_build_object(
      'journal', (select md5(string_agg(entry_id::text || account_code || debit || ':' || credit, ',' order by id)) from public.journal_lines),
      'stock', (select md5(string_agg(variant_id::text || location_id::text || on_hand || ':' || reserved, ',' order by variant_id, location_id)) from public.stock_balances),
      'audit', (select md5(string_agg(id::text || action, ',' order by id)) from public.audit_log)))
$$;

alter table public.report_runs enable row level security;
alter table public.backup_runs enable row level security;
-- No client policies: read through job_status() only.
revoke all on public.report_runs, public.backup_runs from anon, authenticated;

grant execute on function public.report(text, date, date, uuid), public.data_start_date(), public.job_status() to authenticated;
grant execute on function public.job_begin(uuid, text, date, text), public.job_finish(uuid, boolean, text, text, bigint, text),
  public.daily_snapshot(uuid, date), public.recovery_manifest() to service_role;

commit;
