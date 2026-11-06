#!/usr/bin/env bash
# Two-session test: two people report the same last partner-held unit as sold at the same moment.
set -uo pipefail
DB="$1"
Q() { psql -X -q -tA -d "$DB" -c "$1"; }
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1 (got '$2', want '$3')"; fail=$((fail+1)); fi; }
TMP="$(mktemp -d)"
OWNER=00000000-0000-0000-0000-0000000000d1
MANAGER=00000000-0000-0000-0000-0000000000d2
P=$(Q "select id from public.customers where name='Mwanza Partner Test'")
V=$(Q "select id from public.variants where sku='SUIT-D-BLACK-48'")
held=$(Q "select on_hand from public.stock_balances b join public.customers c on c.partner_location_id = b.location_id where c.id='$P' and b.variant_id='$V'")
check "setup: partner holds 1 unit" "$held" "1"
before=$(Q "select count(*) from public.sales")
report() { # $1 user, $2 sleep
  psql -X -q -tA -d "$DB" <<SQL 2>&1
begin;
set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','$1','role','authenticated','aal','aal2')::text, true) is not null;
select public.consignment_report(gen_random_uuid(), '$P', (now() at time zone 'Africa/Dar_es_Salaam')::date, '[{"variant_id":"$V","sold":1}]', 'race')->>'ref_no';
select pg_sleep($2);
commit;
SQL
}
report $MANAGER 1.5 > "$TMP/a" &
sleep 0.4
report $OWNER 0 > "$TMP/b" &
wait
check "race: only one report of the last unit succeeds" "$(cat "$TMP/a" "$TMP/b" | grep -c '^CRP-')" "1"
check "race: the other is refused" "$(cat "$TMP/a" "$TMP/b" | grep -c 'exceeds what the partner holds')" "1"
check "race: exactly one invoice created" "$(Q "select count(*) - $before from public.sales")" "1"
check "custody still consistent" "$(Q "select test.custody_consistent()")" "t"
check "journal still balanced" "$(Q "select test.all_balanced()")" "t"
rm -rf "$TMP"
echo "concurrency: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
