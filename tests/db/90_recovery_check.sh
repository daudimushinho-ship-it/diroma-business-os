#!/usr/bin/env bash
# Backup → restore → verify, on the database left by 40_wholesale_test (stock, ledger, consignment, audit).
# Called by scripts/test-db.sh with: <source_db> <stub.sql> <scratch_dir>
set -uo pipefail
SRC_DB="$1"; STUB="$2"; S="$3"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1 (got '$2', want '$3')"; fail=$((fail+1)); fi; }
url() { echo "postgresql://postgres@/$1?host=$PGHOST&port=$PGPORT"; }
mkdir -p "$S/backups"
sed -e '/^create role/d' "$STUB" > "$S/prepare.sql"
openssl rand -base64 48 > "$S/backup.key"; chmod 600 "$S/backup.key"

MAN=$(SOURCE_DATABASE_URL="$(url "$SRC_DB")" BACKUP_DIR="$S/backups" BACKUP_KEY_FILE="$S/backup.key" "$ROOT/scripts/backup.sh" 2>"$S/backup.err")
check "backup: completed and wrote a manifest" "$( [ -f "$MAN" ] && echo yes )" "yes"
check "backup: archive is encrypted (not a readable tar)" "$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["encrypted"])' "$MAN")" "True"
check "backup: run logged as succeeded" "$(psql -X -tA -d "$SRC_DB" -c "select status from public.backup_runs order by started_at desc limit 1")" "succeeded"

psql -X -q -d postgres -c "drop database if exists t_restore" -c "create database t_restore" >/dev/null
OUT=$(RESTORE_DATABASE_URL="$(url t_restore)" SOURCE_DATABASE_URL="$(url "$SRC_DB")" BACKUP_KEY_FILE="$S/backup.key" PREPARE_SQL="$S/prepare.sql" \
      "$ROOT/scripts/restore-verify.sh" "$MAN" 2>&1)
check "restore: every row count, total and checksum matches" "$(echo "$OUT" | grep -c '^RESTORE VERIFIED')" "1"
echo "$OUT" | grep -v '^RESTORE VERIFIED' | head -5
check "restore: RLS still enforced (sales user sees only own membership)" \
  "$(psql -X -tA -d t_restore -c "set role authenticated; select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-0000000000d3\",\"aal\":\"aal1\"}', false) is not null; select count(*) from public.memberships;" | tail -1)" "1"
check "restore: journal still balanced" "$(psql -X -tA -d t_restore -c "select sum(debit) = sum(credit) from public.journal_lines")" "t"
check "restore: audit log still append-only" "$(psql -X -tA -d t_restore -c "delete from public.audit_log" 2>&1 | grep -c 'append-only')" "1"

psql -X -q -d postgres -c "drop database if exists t_restore2" -c "create database t_restore2" >/dev/null
openssl rand -base64 48 > "$S/wrong.key"
RESTORE_DATABASE_URL="$(url t_restore2)" BACKUP_KEY_FILE="$S/wrong.key" PREPARE_SQL="$S/prepare.sql" "$ROOT/scripts/restore-verify.sh" "$MAN" >/dev/null 2>&1
check "restore: wrong key is refused" "$?" "3"
cp "$MAN" "$S/backups/tampered.manifest.json"
FILE="$S/backups/$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["file"])' "$MAN")"
cp "$FILE" "$FILE.orig"; printf 'X' | dd of="$FILE" bs=1 seek=200 conv=notrunc 2>/dev/null
RESTORE_DATABASE_URL="$(url t_restore2)" BACKUP_KEY_FILE="$S/backup.key" "$ROOT/scripts/restore-verify.sh" "$S/backups/tampered.manifest.json" >/dev/null 2>&1
check "restore: altered backup file is detected by checksum" "$?" "3"
mv "$FILE.orig" "$FILE"
RESTORE_DATABASE_URL="$(url t_restore)" BACKUP_KEY_FILE="$S/backup.key" "$ROOT/scripts/restore-verify.sh" "$MAN" >/dev/null 2>&1
check "restore: refuses a non-empty target" "$?" "2"
RESTORE_DATABASE_URL="$(url "$SRC_DB")" SOURCE_DATABASE_URL="$(url "$SRC_DB")" BACKUP_KEY_FILE="$S/backup.key" "$ROOT/scripts/restore-verify.sh" "$MAN" >/dev/null 2>&1
check "restore: refuses to restore over the source" "$?" "2"
echo "recovery: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
