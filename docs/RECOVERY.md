# Backup na urejeshaji / Backup and recovery

## Kwa Mmiliki (lugha rahisi)
- **Kuna ulinzi wa ngazi tatu:**
  1. Backup ya Supabase yenyewe (kwenye mpango wa Pro).
  2. Nakala yetu iliyosimbwa (encrypted) inayohifadhiwa nje ya Supabase.
  3. PDF ya kila siku saa 23:30.
- **Ufunguo wa kusimba backup (backup key)** ni kama ufunguo wa sefu:
  - Uhifadhi sehemu mbili salama, mfano password manager na karatasi kwenye sefu.
  - **Usiuweke** pamoja na backup wala kwenye WhatsApp.
  - Ukipotea, backup zilizosimbwa kwa ufunguo huo haziwezi kufunguliwa tena.
- **Kila mwezi** mtu wa ufundi afanye "jaribio la kurejesha" (restore test). Kituo cha Udhibiti kitaonyesha tarehe ya jaribio la mwisho lililofanikiwa.
  - **Backup ambayo haijawahi kurejeshwa haijathibitishwa.**
- **Kituo cha Udhibiti** kinaonyesha:
  - ripoti ya mwisho iliyofanikiwa;
  - ripoti zilizoshindwa;
  - backup ya mwisho;
  - jaribio la mwisho la kurejesha.

## For the implementer

### What exists
| Layer | Mechanism | Verified |
|---|---|---|
| Logical, encrypted offsite copy | `scripts/backup.sh` → `pg_dump` of schema `public` + `auth.users` rows from **one exported snapshot**, the `recovery_manifest()` taken in the same snapshot, AES-256 (`openssl -pbkdf2 -iter 200000`), SHA-256 manifest | **Yes, locally**: `npm run test:db` → "backup → restore → verify" (11 checks) |
| Restore drill | `scripts/restore-verify.sh` → checksum → decrypt → restore into an **empty, separate** DB → recompute `recovery_manifest()` → every row count, ledger total and checksum must match. Refuses the source DB and non-empty targets | **Yes, locally** (incl. wrong key, altered file, RLS still enforced, audit still append-only) |
| Provider backups / PITR | Supabase Pro daily backups (PITR is a paid add-on) | **No.** Requires the paid plan; enable it and record a hosted restore test |
| Storage objects | Bucket `reports` (generated PDFs). Not in a DB dump | **No.** Copy the bucket with `rclone` / Supabase CLI to the same offsite location |
| Daily PDFs | `/api/jobs/daily` (Vercel Cron 20:30 and 21:15 UTC = 23:30 and 00:15 Dar), versioned by data fingerprint, bounded retries, SHA-256 | PDF content verified against a real DB snapshot; **hosted cron and upload not verified** |

### Running a backup
```bash
SOURCE_DATABASE_URL="postgresql://postgres:...@db.<project>.supabase.co:5432/postgres" \
BACKUP_DIR=/secure/diroma-backups BACKUP_KEY_FILE=/secure/keys/diroma-backup.key \
npm run backup
```
Produces `diroma-<UTC stamp>.tar.enc` and `diroma-<UTC stamp>.manifest.json`, and logs a row in `public.backup_runs`.

### Restore drill (monthly; never against production)
```bash
RESTORE_DATABASE_URL="postgresql://...isolated-restore-db..." BACKUP_KEY_FILE=/secure/keys/diroma-backup.key \
npm run restore:verify -- /secure/diroma-backups/diroma-<stamp>.manifest.json
```
Exit code 0 and `RESTORE VERIFIED` is the evidence. After a successful drill, insert a `restore_test` row into
`backup_runs` (or run it from a script that does) so the Control Center shows it. A restored environment must have no
messaging or payment integrations configured.

### Retention (targets — need cost approval and a scheduler)
- Daily backups kept 30 days, monthly backups kept 12 months, in a location with credentials **separate** from Supabase.
- RPO 15 minutes / RTO 4 hours are **targets**. They require Supabase PITR plus a rehearsed runbook. They are **not active by default**.

### If something goes wrong
1. Disable affected staff accounts (Team → Deactivate). Their access stops immediately.
2. Rotate `SUPABASE_SECRET_KEY` and `CRON_SECRET` in the provider dashboards.
3. Preserve evidence: export the audit log, and do not delete anything.
4. Restore into a **new** project with `restore-verify.sh`, compare the figures, then switch the app's environment variables.
