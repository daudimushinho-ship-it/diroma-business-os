-- Opening-balance invoices (sales.is_opening) are not sales: exclude them from sales, staff, target and commission figures.
-- Regenerated from the latest definitions with only the is_opening filter added.
begin;

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
    where s.business_id = b and not s.is_opening and public._business_date(b, s.sold_at) between p_from and p_to and (p_loc is null or s.location_id = p_loc)
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

create or replace function public._rpt_staff(b uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  return (select coalesce(jsonb_agg(x order by (x->>'goods_net')::bigint desc), '[]') from (
    select jsonb_build_object('membership_id', m.id, 'name', m.display_name, 'role', m.role,
      'sales', (select count(*) from public.sales s where s.sold_by = m.id and not s.is_opening and public._business_date(b, s.sold_at) between p_from and p_to),
      'goods_net', (select coalesce(sum(s.total - s.delivery_fee), 0) from public.sales s where s.sold_by = m.id and not s.is_opening and public._business_date(b, s.sold_at) between p_from and p_to),
      'discounts', (select coalesce(sum(s.discount_amount), 0) from public.sales s where s.sold_by = m.id and not s.is_opening and public._business_date(b, s.sold_at) between p_from and p_to),
      'returns_on_their_sales', (select coalesce(sum(r.amount), 0) from public.sale_returns r join public.sales s on s.id = r.sale_id
          where s.sold_by = m.id and r.status = 'approved' and public._business_date(b, r.decided_at) between p_from and p_to),
      'collections', (select coalesce(sum(p.amount), 0) from public.payments p where p.received_by = m.id and public._business_date(b, p.received_at) between p_from and p_to),
      'shifts_closed', (select count(*) from public.shifts sh where sh.opened_by = m.id and sh.closed_at is not null and public._business_date(b, sh.closed_at) between p_from and p_to),
      'cash_variance', (select coalesce(sum(sh.variance), 0) from public.shifts sh where sh.opened_by = m.id and sh.closed_at is not null and public._business_date(b, sh.closed_at) between p_from and p_to)) x
    from public.memberships m where m.business_id = b and m.status in ('active','suspended')) t);
end $$;

create or replace function public._metric_actual(b uuid, p_metric text, p_from date, p_to date, p_loc uuid, p_member uuid) returns bigint
language plpgsql stable security definer set search_path = '' as $$
declare v bigint;
begin
  case p_metric
    when 'net_sales' then
      select coalesce(sum(s.total - s.delivery_fee), 0) into v from public.sales s
       where s.business_id = b and not s.is_opening and public._business_date(b, s.sold_at) between p_from and p_to
         and (p_loc is null or s.location_id = p_loc) and (p_member is null or s.sold_by = p_member);
      v := v - (select coalesce(sum(r.amount), 0) from public.sale_returns r join public.sales s on s.id = r.sale_id
                where r.business_id = b and r.status = 'approved' and public._business_date(b, r.decided_at) between p_from and p_to
                  and (p_loc is null or s.location_id = p_loc) and (p_member is null or s.sold_by = p_member));
    when 'units' then
      select coalesce(sum(sl.qty), 0) into v from public.sale_lines sl join public.sales s on s.id = sl.sale_id
       where s.business_id = b and not s.is_opening and public._business_date(b, s.sold_at) between p_from and p_to
         and (p_loc is null or s.location_id = p_loc) and (p_member is null or s.sold_by = p_member);
    when 'collections' then
      select coalesce(sum(p.amount), 0) into v from public.payments p
       where p.business_id = b and public._business_date(b, p.received_at) between p_from and p_to
         and (p_loc is null or p.location_id = p_loc) and (p_member is null or p.received_by = p_member);
    when 'reels', 'product_posts' then
      select count(*) into v from public.content_posts c
       where c.business_id = b and c.kind = case p_metric when 'reels' then 'reel' else 'product_post' end
         and c.status <> 'rejected' and c.posted_on between p_from and p_to and (p_member is null or c.posted_by = p_member);
    when 'follow_ups' then
      select count(*) into v from public.inquiry_events e join public.inquiries q on q.id = e.inquiry_id
       where q.business_id = b and e.kind in ('follow_up','visit') and public._business_date(b, e.created_at) between p_from and p_to
         and (p_member is null or e.created_by = p_member);
    when 'new_customers' then
      select count(*) into v from public.customers c
       where c.business_id = b and public._business_date(b, c.created_at) between p_from and p_to and (p_member is null or c.created_by = p_member);
    else v := null;
  end case;
  return v;
end $$;

create or replace function public.commission_calculate(p_from date, p_to date)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_run uuid; m record; pl public.commission_plans; v_basis bigint; v_ret bigint; v_net bigint;
        v_open int; v_ok boolean; v_amt bigint; v_total bigint := 0;
begin
  v_me := public.require_permission('commissions.calculate');
  if p_from is null or p_to is null or p_to < p_from then raise exception 'invalid period' using errcode = '22023'; end if;
  if p_to > public._business_date(v_me.business_id, now()) then raise exception 'period must have ended' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_me.business_id::text || 'commission', 0));
  if exists (select 1 from public.commission_runs where business_id = v_me.business_id and status <> 'cancelled'
             and daterange(period_from, period_to, '[]') && daterange(p_from, p_to, '[]')) then
    raise exception 'an active commission run already covers part of this period' using errcode = '22023';
  end if;
  insert into public.commission_runs (business_id, ref_no, period_from, period_to, calculated_by)
  values (v_me.business_id, public._next_ref(v_me.business_id, 'COM'), p_from, p_to, v_me.id) returning id into v_run;

  for m in select * from public.memberships where business_id = v_me.business_id and status in ('active','suspended') loop
    select * into pl from public.commission_plans where business_id = v_me.business_id and is_active and membership_id = m.id order by created_at desc limit 1;
    if pl.id is null then
      select * into pl from public.commission_plans where business_id = v_me.business_id and is_active and applies_role = m.role order by created_at desc limit 1;
    end if;
    continue when pl.id is null;
    if pl.basis = 'net_sales' then
      select coalesce(sum(s.total - s.delivery_fee), 0) into v_basis from public.sales s
       where s.sold_by = m.id and not s.is_opening and public._business_date(s.business_id, s.sold_at) between p_from and p_to;
      select coalesce(sum(r.amount), 0) into v_ret from public.sale_returns r join public.sales s on s.id = r.sale_id
       where s.sold_by = m.id and r.status = 'approved' and public._business_date(r.business_id, r.decided_at) between p_from and p_to;
    else
      select coalesce(sum(p.amount), 0) into v_basis from public.payments p
       where p.received_by = m.id and public._business_date(p.business_id, p.received_at) between p_from and p_to;
      v_ret := 0;
    end if;
    v_net := greatest(v_basis - v_ret, 0);
    select count(*) into v_open from public.team_tasks t
     where t.assignee = m.id and t.status in ('open','done') and public._business_date(t.business_id, t.due_at) <= p_to;
    v_ok := v_net >= pl.min_basis and (not pl.require_tasks_done or v_open = 0);
    v_amt := case when v_ok then round(v_net * pl.rate_pct / 100)::bigint else 0 end;
    insert into public.commission_lines (run_id, membership_id, plan_id, basis, basis_amount, returns_deducted, net_basis, rate_pct, open_tasks, eligible, amount, note)
    values (v_run, m.id, pl.id, pl.basis, v_basis, v_ret, v_net, pl.rate_pct, v_open, v_ok, v_amt,
            case when not v_ok and v_net < pl.min_basis then 'below minimum' when not v_ok then 'tasks not completed/verified' end);
    v_total := v_total + v_amt;
    pl := null;
  end loop;
  update public.commission_runs set total = v_total where id = v_run;
  perform public.write_audit(v_me.business_id, 'commission.calculate', 'commission_run', v_run::text, null,
    jsonb_build_object('from', p_from, 'to', p_to, 'total', v_total), null);
  return v_run;
end $$;

commit;
