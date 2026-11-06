#!/usr/bin/env bash
# Local load test (optional: LOAD_TEST=1). Worst case: 8 concurrent POS sessions selling the SAME item (one hot stock row).
# Numbers are from this container's local PostgreSQL — they are NOT a production/Supabase capacity claim.
set -uo pipefail
DB="$1"
[ -n "${LOAD_TEST:-}" ] || { echo "load test skipped (set LOAD_TEST=1)"; exit 0; }
PGBIN="$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)"
Q() { psql -X -q -tA -d "$DB" -c "$1"; }
OWNER=00000000-0000-0000-0000-0000000000e1
SALES=00000000-0000-0000-0000-0000000000e2
SHOP=$(Q "select id from public.locations where code='SHOP'")
V=$(Q "select id from public.variants where sku='TIE-RED-RED-ONE'")
as() { { echo "set role authenticated; select set_config('request.jwt.claims', json_build_object('sub','$1','role','authenticated','aal','$2')::text, false) is not null;"; cat; } | psql -X -q -tA -d "$DB" | tail -1; }
ACC=$(echo "select public.money_account_create('CASH-LOAD', 'Load drawer', 'cash', '$SHOP');" | as $OWNER aal2)
echo "select public.opening_stock_post(gen_random_uuid(), '$SHOP', jsonb_build_array(jsonb_build_object('variant_id','$V','qty',100000)), 'load test stock');" | as $OWNER aal2 >/dev/null
SHIFT=$(echo "select public.shift_open('$SHOP', '$ACC', 0);" | as $SALES aal1)
BEFORE=$(Q "select on_hand from public.stock_balances where variant_id='$V' and location_id='$SHOP'")
SALES0=$(Q "select count(*) from public.sales")
W="$(mktemp -d)"
cat > "$W/sale.sql" <<SQL
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"$SALES","role":"authenticated","aal":"aal1"}', true);
select public.sale_post(gen_random_uuid(), '$SHOP', '$SHIFT', null, 'retail', '[{"variant_id":"$V","qty":1}]', 0, 'collected', '[{"account_id":"$ACC","amount":30000}]', null, null, null, null);
commit;
SQL
"$PGBIN/pgbench" -n -c 8 -j 4 -T 20 -f "$W/sale.sql" -d "$DB" 2>&1 | grep -E "number of (transactions|failed)|latency average|tps|clients" | sed 's/^/  /'
AFTER=$(Q "select on_hand from public.stock_balances where variant_id='$V' and location_id='$SHOP'")
SOLD=$(Q "select count(*) - $SALES0 from public.sales")
echo "  sales posted: $SOLD; stock change: $((BEFORE - AFTER))"
ok=0
[ "$SOLD" = "$((BEFORE - AFTER))" ] && echo "PASS  every committed sale reduced stock exactly once" || { echo "FAIL  stock/sales mismatch"; ok=1; }
[ "$(Q "select bool_and(b) from (select sum(debit) = sum(credit) b from public.journal_lines group by entry_id) t")" = "t" ] && echo "PASS  every journal entry balanced after load" || { echo "FAIL  unbalanced journal"; ok=1; }
[ "$(Q "select count(*) from public.stock_balances b where b.on_hand <> (select coalesce(sum(qty_delta),0) from public.stock_movements m where m.variant_id=b.variant_id and m.location_id=b.location_id)")" = "0" ] \
  && echo "PASS  stock balances equal movements after load" || { echo "FAIL  ledger drift"; ok=1; }
rm -f "$W/sale.sql"; rmdir "$W"
exit $ok
