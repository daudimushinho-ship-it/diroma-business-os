#!/usr/bin/env bash
# Concurrency tests using two real database sessions against the state left by 20_stock_test.sql.
set -uo pipefail
DB="$1"
Q() { psql -X -q -tA -d "$DB" -c "$1"; }
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1 (got '$2', want '$3')"; fail=$((fail+1)); fi; }

OWNER=00000000-0000-0000-0000-0000000000b1
MANAGER=00000000-0000-0000-0000-0000000000b2
SHOP=$(Q "select id from public.locations where code='SHOP'")
WH=$(Q "select id from public.locations where code='WH'")
V=$(Q "select id from public.variants where sku='DR#2516-43-NAVY-48'")
B50=$(Q "select id from public.variants where sku='DR#2516-43-BLACK-50'")
before_shop=$(Q "select on_hand from public.stock_balances b join public.locations l on l.id=b.location_id where l.code='SHOP' and variant_id='$V'")
before_transfers=$(Q "select count(*) from public.transfers")

session() { # $1 user, $2 idem key, $3 variant, $4 from, $5 to, $6 qty, $7 sleep-after
  psql -X -q -tA -d "$DB" <<SQL 2>&1
begin;
set role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','$1','role','authenticated','aal','aal2')::text, true) is not null;
select public.transfer_dispatch('$2', null, '$4', '$5', jsonb_build_array(jsonb_build_object('variant_id','$3','qty',$6)), 'race')->>'ref_no';
select pg_sleep($7);
commit;
SQL
}

# 1) Two different people dispatch the SAME last units at the same time.
session $OWNER   aaaaaaaa-0000-0000-0000-000000000001 $V $SHOP $WH $before_shop 1.5 > /tmp/race_a.$$ &
sleep 0.4
session $MANAGER aaaaaaaa-0000-0000-0000-000000000002 $V $SHOP $WH $before_shop 0 > /tmp/race_b.$$ &
wait
ok_count=$(grep -c "^TRF-" /tmp/race_a.$$ /tmp/race_b.$$ | awk -F: '{s+=$2} END {print s}')
check "race: only one of two concurrent dispatches of the last $before_shop units commits" "$ok_count" "1"
check "race: loser got 'insufficient stock'" "$(grep -c 'insufficient stock' /tmp/race_a.$$ /tmp/race_b.$$ | awk -F: '{s+=$2} END {print s}')" "1"
check "race: shop balance is 0, never negative" "$(Q "select on_hand from public.stock_balances where location_id='$SHOP' and variant_id='$V'")" "0"
check "race: exactly one new transfer" "$(Q "select count(*) - $before_transfers from public.transfers")" "1"

# 2) The SAME request retried concurrently (double-click / network retry) posts once.
before_transfers=$(Q "select count(*) from public.transfers")
session $OWNER bbbbbbbb-0000-0000-0000-000000000001 $B50 $WH $SHOP 1 1.0 > /tmp/retry_a.$$ &
sleep 0.3
session $OWNER bbbbbbbb-0000-0000-0000-000000000001 $B50 $WH $SHOP 1 0 > /tmp/retry_b.$$ &
wait
check "retry: concurrent duplicate submissions create one transfer" "$(Q "select count(*) - $before_transfers from public.transfers")" "1"
check "retry: both callers receive the same reference" "$(cat /tmp/retry_a.$$ /tmp/retry_b.$$ | grep '^TRF-' | sort -u | wc -l)" "1"

check "ledger still consistent after races" "$(Q "select test.ledger_consistent()")" "t"
rm -f /tmp/race_?.$$ /tmp/retry_?.$$
echo "concurrency: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
