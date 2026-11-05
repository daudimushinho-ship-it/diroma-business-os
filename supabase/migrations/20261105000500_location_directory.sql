-- Location names are needed to show "from Store → to Shop" on requisitions and transfers,
-- even for staff who are not assigned to the other location. Names/kinds only; balances stay protected by RLS.
begin;
create or replace function public.location_directory()
returns table (id uuid, code text, name text, kind public.location_kind)
language sql stable security definer set search_path = '' as $$
  select l.id, l.code, l.name, l.kind from public.locations l
  where l.is_active and l.business_id = (public.current_membership()).business_id
  order by l.kind, l.name
$$;
revoke all on function public.location_directory() from public, anon, authenticated;
grant execute on function public.location_directory() to authenticated;

-- Server-side period report for one location: opening / in / out / closing per variant.
-- Read-only: exporting never posts or deducts anything.
create or replace function public.stock_period_report(p_location uuid, p_from timestamptz, p_to timestamptz)
returns table (variant_id uuid, design_code text, design_name text, color text, size text,
               opening bigint, inbound bigint, outbound bigint, closing bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.can_access_location(p_location) or public.has_permission('stock.approve')) then
    raise exception 'location not accessible' using errcode = '42501';
  end if;
  if p_to <= p_from then raise exception 'invalid period' using errcode = '22023'; end if;
  return query
    with m as (
      select sm.variant_id,
             sum(sm.qty_delta) filter (where sm.created_at < p_from) as opening,
             sum(sm.qty_delta) filter (where sm.created_at >= p_from and sm.created_at < p_to and sm.qty_delta > 0) as inbound,
             -sum(sm.qty_delta) filter (where sm.created_at >= p_from and sm.created_at < p_to and sm.qty_delta < 0) as outbound
      from public.stock_movements sm
      where sm.location_id = p_location and sm.created_at < p_to
      group by sm.variant_id
    )
    select m.variant_id, d.code, d.name, v.color, v.size,
           coalesce(m.opening, 0), coalesce(m.inbound, 0), coalesce(m.outbound, 0),
           coalesce(m.opening, 0) + coalesce(m.inbound, 0) - coalesce(m.outbound, 0)
    from m join public.variants v on v.id = m.variant_id join public.designs d on d.id = v.design_id
    where coalesce(m.opening, 0) <> 0 or coalesce(m.inbound, 0) <> 0 or coalesce(m.outbound, 0) <> 0
    order by d.code, v.color, v.size;
end $$;
revoke all on function public.stock_period_report(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.stock_period_report(uuid, timestamptz, timestamptz) to authenticated;
commit;
