#!/usr/bin/env bash
# DIROMA logical backup with an integrity manifest (an offsite copy in addition to the provider's own backups).
#
#   SOURCE_DATABASE_URL=postgres://...   (or PG* env vars)   BACKUP_DIR=./backups   [BACKUP_KEY_FILE=/secure/key]
#   scripts/backup.sh
#
# - Dumps schema "public" (all business data) and auth.users rows from ONE consistent snapshot.
# - Computes public.recovery_manifest() in that same snapshot: row counts, ledger totals and checksums.
# - Encrypts with AES-256 (openssl, PBKDF2) when BACKUP_KEY_FILE is set. Keep the key OUTSIDE the backup location.
# - Writes <name>.manifest.json with the file's SHA-256 and records the run in public.backup_runs.
# Storage objects (photos / PDF files) are NOT in a database dump: copy the storage bucket separately (docs/RECOVERY.md).
set -euo pipefail
SRC="${SOURCE_DATABASE_URL:-}"
OUT="${BACKUP_DIR:-./backups}"
mkdir -p "$OUT"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
NAME="diroma-$STAMP"
PSQL=(psql -X -q -tA -v ON_ERROR_STOP=1)
[ -n "$SRC" ] && PSQL+=("$SRC")
DUMP_CONN=()
[ -n "$SRC" ] && DUMP_CONN=(--dbname="$SRC")

log_run() { # status location manifest_sql error
  "${PSQL[@]}" -c "insert into public.backup_runs (kind, status, finished_at, location, manifest, error)
    values ('backup', '$1', now(), \$q\$$2\$q\$, $3, nullif(\$q\$$4\$q\$, ''))" >/dev/null 2>&1 || true
}
fail() { echo "BACKUP FAILED: $*" >&2; log_run failed "$OUT/$NAME" null "$*"; exit 1; }

# Hold a repeatable-read transaction open and export its snapshot so the dump and the manifest see identical data.
TMPD="$(mktemp -d)"
mkfifo "$TMPD/in" "$TMPD/out"
"${PSQL[@]}" < "$TMPD/in" > "$TMPD/out" 2>&1 &
HOLDER=$!
exec 3>"$TMPD/in" 4<"$TMPD/out"
cleanup() {
  exec 3>&- 2>/dev/null || true
  wait "$HOLDER" 2>/dev/null || true
  rm -f -- "${TMPD:?}/in" "${TMPD:?}/out"
  rmdir -- "${TMPD:?}" 2>/dev/null || true
}
trap cleanup EXIT
echo "begin isolation level repeatable read read only; select pg_export_snapshot();" >&3
read -r SNAP <&4 || fail "could not export snapshot"
echo "select public.recovery_manifest();" >&3
read -r MANIFEST <&4 || fail "could not compute manifest"

# privileges ARE kept: RLS grants for anon/authenticated/service_role must survive a restore
pg_dump "${DUMP_CONN[@]}" --snapshot="$SNAP" --format=custom --no-owner \
  --schema=public --file="$OUT/$NAME.public.dump" || fail "pg_dump public failed"
pg_dump "${DUMP_CONN[@]}" --snapshot="$SNAP" --format=custom --no-owner --no-privileges --data-only \
  --table=auth.users --file="$OUT/$NAME.auth.dump" || fail "pg_dump auth.users failed"
echo "commit;" >&3

# bundle both dumps into one archive, then optionally encrypt
tar -C "$OUT" -cf "$OUT/$NAME.tar" "$NAME.public.dump" "$NAME.auth.dump"
rm -f -- "$OUT/$NAME.public.dump" "$OUT/$NAME.auth.dump"
FILE="$OUT/$NAME.tar"
ENCRYPTED=false
if [ -n "${BACKUP_KEY_FILE:-}" ]; then
  openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -in "$FILE" -out "$FILE.enc" -pass "file:$BACKUP_KEY_FILE" || fail "encryption failed"
  rm -f -- "$FILE"
  FILE="$FILE.enc"; ENCRYPTED=true
fi
SHA="$(sha256sum "$FILE" | cut -d' ' -f1)"
SIZE="$(stat -c %s "$FILE")"
printf '%s' "$MANIFEST" > "$OUT/$NAME.recovery.json"
python3 -I - "$OUT/$NAME.manifest.json" "$(basename "$FILE")" "$SHA" "$SIZE" "$ENCRYPTED" "$STAMP" "$OUT/$NAME.recovery.json" <<'PY'
import json, sys
path, file, sha, size, enc, stamp, rec = sys.argv[1:]
json.dump({"file": file, "sha256": sha, "size_bytes": int(size), "encrypted": enc == "true", "created_utc": stamp,
           "format": "tar of pg_dump custom archives: public schema + auth.users data",
           "recovery_manifest": json.load(open(rec))}, open(path, "w"), indent=2)
PY
rm -f -- "$OUT/$NAME.recovery.json"
MJSON="$(python3 -I -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' "$OUT/$NAME.manifest.json")"
log_run succeeded "$FILE" "\$m\$$MJSON\$m\$::jsonb" ""
echo "$OUT/$NAME.manifest.json"
