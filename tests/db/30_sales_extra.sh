#!/usr/bin/env bash
# Two-session concurrency tests for Milestone C, reusing the state left by 30_sales_test.sql.
set -uo pipefail
DB="$1"
Q() { psql -X -q -tA -d "$DB" -c "$1"; }
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1 (got '$2', want '$3')"; fail=$((fail+1)); fi; }
TMP="$(mktemp -d)"
MANAGER=00000000-0000-0000-0000-0000000000c2
SALES=00000000-0000-0000-0000-0000000000c3
SHOP=$(Q "select id from public.locations where code='SHOP'")
CASH=$(Q "select id from public.money_accounts where code='CASH-SHOP'")
V48=$(Q "select id from public.variants where sku='SUIT-C-BLACK-48'")
VTIE=$(Q "select id from public.variants where sku='TIE-C-RED-ONE'")

as_user() { # $1 user, $2 aal, then SQL on stdin
  { echo "set role authenticated;"
    echo "select set_config('request.jwt.claims', json_build_object('sub','$1','role','authenticated','aal','$2')::text, false) is not null;"
    cat; } | psql -X -q -tA -d "$DB" 2>&1
}

SHIFT_S=$(echo "select public.shift_open('$SHOP', '$CASH', 10000);" | as_user $SALES aal1 | tail -1)
SHIFT_M=$(echo "select public.shift_open('$SHOP', '$CASH', 0);" | as_user $MANAGER aal2 | tail -1)
check "setup: shop has exactly 1 suit left" "$(Q "select on_hand from public.stock_balances where location_id='$SHOP' and variant_id='$V48'")" "1"

sale_sql() { # $1 shift, $2 variant, $3 amount, $4 sleep
  cat <<SQL
begin;
select public.sale_post(gen_random_uuid(), '$SHOP', '$1', null, 'retail', '[{"variant_id":"$2","qty":1}]', 0, 'collected',
  '[{"account_id":"$CASH","amount":$3}]', null, null, null, null)->>'ref_no';
select pg_sleep($4);
commit;
SQL
}

# 1) Two cashiers sell the last suit at the same moment.
sale_sql "$SHIFT_S" "$V48" 450000 1.5 | as_user $SALES aal1 > "$TMP/a" &
sleep 0.4
sale_sql "$SHIFT_M" "$V48" 450000 0 | as_user $MANAGER aal2 > "$TMP/b" &
wait
check "race: exactly one of two concurrent sales of the last unit succeeds" "$(cat "$TMP/a" "$TMP/b" | grep -c '^RCP-')" "1"
check "race: the other is refused for insufficient stock" "$(cat "$TMP/a" "$TMP/b" | grep -c 'insufficient stock')" "1"
check "race: stock is 0, never negative" "$(Q "select on_hand from public.stock_balances where location_id='$SHOP' and variant_id='$V48'")" "0"

# 2) The cashier closes the shift while one of their sales is still being posted.
sale_sql "$SHIFT_S" "$VTIE" 30000 1.5 | as_user $SALES aal1 > "$TMP/c" &
sleep 0.4
echo "select public.shift_close('$SHIFT_S', 0, 'race test')->>'expected';" | as_user $SALES aal1 > "$TMP/d" &
wait
expected=$(tail -1 "$TMP/d")
cash_in=$(Q "select 10000 + coalesce(sum(amount),0) from public.payments where shift_id='$SHIFT_S'")
check "close race: the in-flight sale committed" "$(grep -c '^RCP-' "$TMP/c")" "1"
check "close race: closing waited and its expected cash includes that sale" "$expected" "$cash_in"
late=$(sale_sql "$SHIFT_S" "$VTIE" 30000 0 | as_user $SALES aal1)
check "close race: posting after close is refused" "$(echo "$late" | grep -c 'open your shift first')" "1"

check "journal still balanced" "$(Q "select test.all_balanced()")" "t"
rm -rf "$TMP"
echo "concurrency: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
