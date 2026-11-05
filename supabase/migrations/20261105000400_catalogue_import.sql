-- CSV catalogue import: all-or-nothing, explicit duplicate policy, idempotent by import id.
-- Modes:
--   create_only   : existing designs gain new variants; an existing variant (same design/colour/size) is an error
--   update_prices : existing variants get the row's prices; new variants are created
begin;

create table public.catalogue_imports (
  id            uuid primary key,
  business_id   uuid not null references public.businesses(id),
  mode          text not null,
  row_count     int not null,
  result        jsonb not null,
  imported_by   uuid not null references public.memberships(id),
  created_at    timestamptz not null default now()
);
alter table public.catalogue_imports enable row level security;
create policy catalogue_imports_read on public.catalogue_imports for select to authenticated
  using (public.is_business_member(business_id) and public.has_permission('products.manage'));

create or replace function public.catalogue_import(p_import uuid, p_rows jsonb, p_mode text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_prev jsonb; r record; v_design uuid; v_set text; v_variant public.variants;
        v_supplier uuid; n_designs int := 0; n_created int := 0; n_updated int := 0; v_result jsonb; v_n int := 0;
begin
  v_me := public.require_permission('products.manage');
  if p_mode not in ('create_only','update_prices') then raise exception 'unknown mode' using errcode = '22023'; end if;
  v_prev := public._idem_get(p_import, 'catalogue_import', jsonb_build_object('rows', p_rows, 'mode', p_mode));
  if v_prev is not null then return v_prev; end if;

  for r in select e.rn::int as rn, x.*
           from jsonb_array_elements(p_rows) with ordinality as e(row_json, rn)
           cross join lateral jsonb_to_record(e.row_json) as x(design_code text, design_name text, category text, color text,
                size text, retail_price bigint, wholesale_price bigint, barcode text, supplier text)
           order by e.rn
  loop
    v_n := v_n + 1;
    if coalesce(btrim(r.design_code), '') = '' or coalesce(btrim(r.color), '') = '' or coalesce(btrim(r.size), '') = '' then
      raise exception 'row %: design_code, color and size are required', r.rn using errcode = '22023';
    end if;
    if r.retail_price is not null and r.retail_price <= 0 or r.wholesale_price is not null and r.wholesale_price <= 0 then
      raise exception 'row %: prices must be positive or empty', r.rn using errcode = '22023';
    end if;

    select id into v_design from public.designs where business_id = v_me.business_id and code = btrim(r.design_code);
    if v_design is null then
      if coalesce(btrim(r.design_name), '') = '' then raise exception 'row %: design_name required for a new design', r.rn using errcode = '22023'; end if;
      if not exists (select 1 from public.categories where code = r.category) then
        raise exception 'row %: unknown category "%"', r.rn, r.category using errcode = '22023';
      end if;
      v_supplier := null;
      if coalesce(btrim(r.supplier), '') <> '' then
        select id into v_supplier from public.suppliers where business_id = v_me.business_id and lower(name) = lower(btrim(r.supplier));
        if v_supplier is null then
          insert into public.suppliers (business_id, name) values (v_me.business_id, btrim(r.supplier)) returning id into v_supplier;
        end if;
      end if;
      insert into public.designs (business_id, code, name, category, supplier_id)
      values (v_me.business_id, btrim(r.design_code), btrim(r.design_name), r.category, v_supplier) returning id into v_design;
      n_designs := n_designs + 1;
    end if;

    select c.size_set into v_set from public.designs d join public.categories c on c.code = d.category where d.id = v_design;
    if not exists (select 1 from public.size_set_sizes where size_set = v_set and size = upper(btrim(r.size))) then
      raise exception 'row %: size "%" is not configured for this category', r.rn, r.size using errcode = '22023';
    end if;

    select * into v_variant from public.variants
     where design_id = v_design and color = btrim(r.color) and size = upper(btrim(r.size)) for update;
    if v_variant.id is not null then
      if p_mode = 'create_only' then
        raise exception 'row %: variant already exists (choose "update prices" to change it)', r.rn using errcode = '22023';
      end if;
      update public.variants set retail_price = r.retail_price, wholesale_price = r.wholesale_price where id = v_variant.id;
      n_updated := n_updated + 1;
    else
      if coalesce(btrim(r.barcode), '') <> '' and exists (select 1 from public.variants where business_id = v_me.business_id and barcode = upper(btrim(r.barcode))) then
        raise exception 'row %: barcode % already used', r.rn, r.barcode using errcode = '22023';
      end if;
      perform public._add_variant(v_me.business_id, v_design, btrim(r.design_code), r.color, r.size, r.retail_price, r.wholesale_price, r.barcode);
      n_created := n_created + 1;
    end if;
  end loop;
  if v_n = 0 then raise exception 'no rows' using errcode = '22023'; end if;

  v_result := jsonb_build_object('import_id', p_import, 'rows', v_n, 'designs_created', n_designs,
                                 'variants_created', n_created, 'variants_updated', n_updated);
  insert into public.catalogue_imports (id, business_id, mode, row_count, result, imported_by)
  values (p_import, v_me.business_id, p_mode, v_n, v_result, v_me.id);
  perform public.write_audit(v_me.business_id, 'catalogue.import', 'catalogue_import', p_import::text, null, v_result, null);
  return public._idem_put(p_import, v_me.business_id, 'catalogue_import', jsonb_build_object('rows', p_rows, 'mode', p_mode), v_result);
end $$;

revoke all on public.catalogue_imports from anon, authenticated;
grant select on public.catalogue_imports to authenticated;
revoke all on function public.catalogue_import(uuid, jsonb, text) from public, anon, authenticated;
grant execute on function public.catalogue_import(uuid, jsonb, text) to authenticated;

commit;
