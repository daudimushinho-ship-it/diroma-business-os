#!/usr/bin/env bash
# Runs the database acceptance tests on a throwaway local PostgreSQL 16 cluster.
# Each tests/db/NN_*_test.sql runs in its own fresh database (stub + all migrations).
# Requires PostgreSQL server binaries (initdb/pg_ctl). No Docker needed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
WORK="$(mktemp -d)"
PORT="${PGPORT_TEST:-54329}"
cleanup() { "$PGBIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

RUNAS=()
if [ "$(id -u)" = "0" ]; then
  id postgres >/dev/null 2>&1 || useradd -r postgres
  chown -R postgres "$WORK"; chmod 755 "$WORK"
  RUNAS=(runuser -u postgres --)
fi

"${RUNAS[@]}" "$PGBIN/initdb" -D "$WORK/data" -U postgres -A trust >/dev/null
"${RUNAS[@]}" "$PGBIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -k $WORK -c listen_addresses=''" -l "$WORK/pg.log" -w start >/dev/null

export PGHOST="$WORK" PGPORT="$PORT" PGUSER=postgres
PSQL=(psql -v ON_ERROR_STOP=1 -q)

fresh_db() {
  local db="$1"
  "${PSQL[@]}" -d postgres -c "drop database if exists $db" -c "create database $db" >/dev/null
  if ! "${PSQL[@]}" -d postgres -tAc "select 1 from pg_roles where rolname='authenticated'" | grep -q 1; then
    "${PSQL[@]}" -d "$db" -f "$ROOT/tests/db/00_supabase_stub.sql" >/dev/null
  else
    # roles are cluster-wide; only (re)create the per-database parts of the stub
    sed -e '/^create role/d' "$ROOT/tests/db/00_supabase_stub.sql" | "${PSQL[@]}" -d "$db" >/dev/null
  fi
  for f in "$ROOT"/supabase/migrations/*.sql; do
    "${PSQL[@]}" -d "$db" -f "$f" >/dev/null 2> >(grep -v NOTICE >&2)
  done
}

status=0
for t in "$ROOT"/tests/db/[0-9][0-9]_*_test.sql; do
  name="$(basename "$t" .sql)"
  db="t_${name//[^a-zA-Z0-9]/_}"
  echo "=== $name"
  fresh_db "$db"
  EXTRA=()
  if [ -n "${REGEN_FIXTURES:-}" ] && [ "$name" = "30_sales_test" ]; then EXTRA=(-v "FIXTURE_OUT=$ROOT/tests/fixtures/daily-snapshot.json"); fi
  if ! "${PSQL[@]}" "${EXTRA[@]}" -d "$db" -f "$t"; then status=1; continue; fi
  # optional companion shell test that reuses the same database state
  if [ -x "${t%_test.sql}_extra.sh" ]; then
    "${t%_test.sql}_extra.sh" "$db" || status=1
  fi
done
echo "=== backup → restore → verify"
"$ROOT/tests/db/90_recovery_check.sh" t_40_wholesale_test "$ROOT/tests/db/00_supabase_stub.sql" "$WORK/recovery" || status=1
echo "=== select contract (app columns vs real schema)"
fresh_db t_select_contract
if node "$ROOT/scripts/select-contract.mjs" > "$WORK/selects.sql" && "${PSQL[@]}" -d t_select_contract -f "$WORK/selects.sql" >/dev/null; then
  echo "select contract: $(grep -c '^select' "$WORK/selects.sql") queries OK"
else
  echo "select contract: FAILED"; status=1
fi
exit $status
