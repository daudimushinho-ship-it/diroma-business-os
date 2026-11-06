#!/usr/bin/env bash
# Restore a DIROMA backup into a SEPARATE, empty database and prove it matches the backup manifest.
#
#   RESTORE_DATABASE_URL=postgres://...isolated...   [BACKUP_KEY_FILE=/secure/key]   [PREPARE_SQL=file.sql]
#   scripts/restore-verify.sh backups/diroma-<stamp>.manifest.json
#
# Steps: verify SHA-256 → decrypt → restore auth.users + public schema → recompute recovery_manifest() → compare.
# Refuses a target equal to SOURCE_DATABASE_URL or a target that already has tables. Exit 0 only if everything matches.
# A restore environment must never send real messages or payments (no integrations are configured in it).
set -euo pipefail
MAN="$1"
DIR="$(cd "$(dirname "$MAN")" && pwd)"
DST="${RESTORE_DATABASE_URL:-}"
[ -n "$DST" ] || { echo "Set RESTORE_DATABASE_URL to an isolated database" >&2; exit 2; }
if [ -n "${SOURCE_DATABASE_URL:-}" ] && [ "$DST" = "$SOURCE_DATABASE_URL" ]; then echo "Refusing: restore target equals source" >&2; exit 2; fi
FILE="$DIR/$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["file"])' "$MAN")"
WANT_SHA="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["sha256"])' "$MAN")"
GOT_SHA="$(sha256sum "$FILE" | cut -d' ' -f1)"
[ "$WANT_SHA" = "$GOT_SHA" ] || { echo "CHECKSUM MISMATCH: backup file is corrupted or altered" >&2; exit 3; }

WORK="$(mktemp -d)"
cleanup() { rm -f -- "${WORK:?}"/*; rmdir -- "${WORK:?}" 2>/dev/null || true; }
trap cleanup EXIT
if [[ "$FILE" == *.enc ]]; then
  [ -n "${BACKUP_KEY_FILE:-}" ] || { echo "Encrypted backup: set BACKUP_KEY_FILE" >&2; exit 2; }
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -in "$FILE" -out "$WORK/b.tar" -pass "file:$BACKUP_KEY_FILE" \
    || { echo "DECRYPTION FAILED (wrong key?)" >&2; exit 3; }
else
  cp "$FILE" "$WORK/b.tar"
fi
tar -C "$WORK" -xf "$WORK/b.tar"
PUB="$(ls "$WORK"/*.public.dump)"; AUTH="$(ls "$WORK"/*.auth.dump)"

PSQL=(psql -X -q -tA "$DST" -v ON_ERROR_STOP=1)
if [ -n "${PREPARE_SQL:-}" ]; then "${PSQL[@]}" -f "$PREPARE_SQL" >/dev/null; fi
if [ "$("${PSQL[@]}" -c "select count(*) from information_schema.tables where table_schema='public'")" != "0" ]; then
  echo "Refusing: target database is not empty" >&2; exit 2
fi
pg_restore --dbname="$DST" --no-owner --exit-on-error --data-only "$AUTH"
# the target already has schema "public" (every PostgreSQL/Supabase database does): skip only that entry
pg_restore -l "$PUB" | grep -v -E ' SCHEMA - public | COMMENT - SCHEMA public ' > "$WORK/restore.list"
pg_restore --dbname="$DST" --no-owner --exit-on-error --use-list="$WORK/restore.list" "$PUB"
GOT="$("${PSQL[@]}" -c "select public.recovery_manifest()")"
printf '%s' "$GOT" > "$WORK/got.json"
python3 -I - "$MAN" "$WORK/got.json" <<'PY'
import json, sys
want = json.load(open(sys.argv[1]))["recovery_manifest"]; got = json.load(open(sys.argv[2]))
diffs = [(k, sk, want[k][sk], got.get(k, {}).get(sk)) for k in want for sk in want[k] if want[k][sk] != got.get(k, {}).get(sk)]
if diffs:
    for d in diffs: print("MISMATCH %s.%s: backup=%s restored=%s" % d)
    sys.exit(4)
print("RESTORE VERIFIED: %d row counts, %d totals, %d checksums match" % (len(want["rows"]), len(want["totals"]), len(want["checksums"])))
PY
