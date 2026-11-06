-- Every expense account except COGS (5000) counts as an operating expense — including staff commissions (6500)
-- added in Milestone F. Regenerated from the previous definitions with only the account filter changed.
begin;

create or replace function public.business_overview(p_from date, p_to date)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_me public.memberships; b uuid;
begin
  if not public.has_permission('money.view') then raise exception 'not authorized' using errcode = '42501'; end if;
  v_me := public.current_membership(); b := v_me.business_id;
  return jsonb_build_object(
    'period', jsonb_build_object('from', p_from, 'to', p_to, 'timezone', (select timezone from public.businesses where id = b)),
    'net_sales', (select coalesce(sum(jl.credit - jl.debit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
                   where je.business_id = b and je.entry_date between p_from and p_to and jl.account_code in ('4000','4900')),
    'delivery_income', (select coalesce(sum(jl.credit - jl.debit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
                   where je.business_id = b and je.entry_date between p_from and p_to and jl.account_code = '4100'),
    'collections', (select coalesce(sum(p.amount),0) from public.payments p
                    where p.business_id = b and public._business_date(b, p.received_at) between p_from and p_to),
    'collections_old_debt', (select coalesce(sum(ss.amount),0) from public.sale_settlements ss join public.payments p on p.id = ss.payment_id
                    join public.sales s on s.id = ss.sale_id
                    where p.business_id = b and public._business_date(b, p.received_at) between p_from and p_to
                      and public._business_date(b, s.sold_at) < p_from),
    'cogs', (select coalesce(sum(jl.debit - jl.credit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
              where je.business_id = b and je.entry_date between p_from and p_to and jl.account_code = '5000'),
    'expenses', (select coalesce(sum(jl.debit - jl.credit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
              where je.business_id = b and je.entry_date between p_from and p_to and jl.account_code in (select la.code from public.ledger_accounts la where la.type = 'expense' and la.code <> '5000')),
    'units_sold', (select coalesce(sum(sl.qty),0) from public.sale_lines sl join public.sales s on s.id = sl.sale_id
                    where s.business_id = b and public._business_date(b, s.sold_at) between p_from and p_to),
    'units_cost_unknown', (select coalesce(sum(sl.qty),0) from public.sale_lines sl join public.sales s on s.id = sl.sale_id
                    join public.sale_line_costs c on c.sale_line_id = sl.id
                    where s.business_id = b and not c.cost_known and public._business_date(b, s.sold_at) between p_from and p_to),
    'cash_by_kind', (select coalesce(jsonb_object_agg(kind, bal), '{}') from (select a.kind, sum(jl.debit - jl.credit) bal from public.money_accounts a
                    join public.journal_lines jl on jl.money_account_id = a.id and jl.account_code = '1000' where a.business_id = b group by a.kind) k),
    'funds_in_transit', (select coalesce(sum(jl.debit - jl.credit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
                    where je.business_id = b and jl.account_code = '1050'),
    'receivables', (select coalesce(sum(jl.debit - jl.credit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
                    where je.business_id = b and jl.account_code = '1100'),
    'customer_credits', (select coalesce(sum(jl.credit - jl.debit),0) from public.journal_lines jl join public.journal_entries je on je.id = jl.entry_id
                    where je.business_id = b and jl.account_code = '2000'),
    'saleable_units', (select coalesce(sum(sb.on_hand - sb.reserved),0) from public.stock_balances sb join public.locations l on l.id = sb.location_id
                    where l.business_id = b and l.kind in ('warehouse','shop')),
    'units_not_saleable', (select coalesce(sum(sb.on_hand),0) from public.stock_balances sb join public.locations l on l.id = sb.location_id
                    where l.business_id = b and l.kind in ('transit','inspection','quarantine')),
    'inventory_value_known', (select coalesce(sum(sb.on_hand::bigint * vc.avg_cost),0) from public.stock_balances sb
                    join public.locations l on l.id = sb.location_id join public.variant_costs vc on vc.variant_id = sb.variant_id
                    where l.business_id = b),
    'units_without_cost', (select coalesce(sum(sb.on_hand),0) from public.stock_balances sb join public.locations l on l.id = sb.location_id
                    left join public.variant_costs vc on vc.variant_id = sb.variant_id where l.business_id = b and vc.avg_cost is null),
    'pending_approvals', (select count(*) from public.approval_requests where business_id = b and status = 'pending'),
    'shifts_open', (select count(*) from public.shifts where business_id = b and status = 'open'),
    'shifts_pending_review', (select count(*) from public.shifts where business_id = b and status = 'pending_review')
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
        where je.business_id = b and je.entry_date between p_from and p_to and jl.account_code in (select la.code from public.ledger_accounts la where la.type = 'expense' and la.code <> '5000')
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

commit;
