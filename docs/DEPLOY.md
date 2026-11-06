# Deployment, go-live and rollback

## 0. Ownership (before anything else)
All accounts belong to DIROMA: GitHub organisation/repo, Supabase organisation, Vercel team and the domain (optional).
Developers get **revocable member access**, never the Owner's login. MFA must be on for every account. Keep recovery codes offline.

## 1. Staging (free tiers allowed for testing only)
1. Create a Supabase project `diroma-staging`. Apply `supabase/migrations/*` in order (`supabase db push`).
2. Auth settings:
   - Phone provider ON. Public sign-ups OFF. Minimum password length 12.
   - TOTP MFA ON.
   - Access-token (JWT) expiry 3600 s. Refresh-token rotation and reuse detection ON.
   - Leaked-password protection and CAPTCHA if the plan offers them.
3. `node --env-file=.env.local scripts/setup-storage.mjs` (private `reports` bucket).
4. `node --env-file=.env.local scripts/setup-owner.mjs` → one-time Owner setup code → Owner opens `/setup`, then enables MFA.
5. Run the acceptance rehearsal (`docs/ACCEPTANCE.md`) with **synthetic** data only.

## 2. Production
1. Create a **separate** Supabase project `diroma-production`. Choose the region by measured latency from Dar es Salaam and any data-location requirement, not by map distance.
2. Repeat steps 1.1–1.4 for production. Never copy staging data into production.
3. Hosting (e.g. Vercel Pro):
   - Set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY` and `CRON_SECRET` (`openssl rand -hex 32`).
   - Production auth redirect URLs.
   - `vercel.json` crons.
4. Smoke test (no fake revenue): sign in as each role, open every page, run `/api/jobs/daily?kind=interim&trigger=manual`, download the PDF from Control Center.
5. Backups:
   - Enable Supabase Pro daily backups (PITR only if approved).
   - Schedule `scripts/backup.sh` to an offsite location with **separate credentials**.
   - Do one restore drill (`docs/RECOVERY.md`) and record it.

## 3. Migration from MauzoTrack (rehearse on staging first)
See `docs/MIGRATION.md`. Freeze sales in MauzoTrack at a cut-off time, take a physical count, import, reconcile, then go live.

## 4. Pilot
- Start with one shop, a known product set and the agreed staff.
- **One system posts each sale.** Do not record the same sale in both systems.
- Reconcile every evening: cash counted vs shift closing, stock spot-check, the debts list.
- Exit criteria to stop MauzoTrack: 14 consecutive days with 0 unexplained cash differences, stock spot-checks matching, and the Owner's sign-off.

## 5. Rollback
- **App:** redeploy the previous Vercel deployment (one click). The database stays.
- **Data:** never delete. Correct by reversing documents. For a disaster, restore the latest verified backup into a **new** project, verify with `restore-verify.sh`, then switch the environment variables.
- **Back to MauzoTrack during the pilot:** export customers/debts (Customers page) and stock (Store → Reports → CSV), then re-enter them there.

## 6. Recurring costs (components only — check current prices on each provider's pricing page)
| Component | Needed for | Notes |
|---|---|---|
| Supabase plan (Pro recommended for production) | Database, Auth, Storage, daily backups | PITR is an add-on; extra projects cost extra compute |
| Hosting (e.g. Vercel Pro) | App + cron jobs | Commercial use is not allowed on hobby tiers |
| Offsite backup storage | Encrypted copies | Small (GB-level) |
| SMS provider (optional) | SMS activation/recovery | Per message |
| WhatsApp Business API (optional) | Automatic reminders | Per conversation |
| Domain (optional) | Custom address | Yearly |

No total is given here on purpose: prices change, and taxes and usage vary. Get current quotes before approving.

## 7. Maintenance (who does what)
- **Weekly:** check Control Center (failed reports, last backup, shifts pending review).
- **Monthly:** restore drill; `npm audit`; review staff access (Team page); rotate `CRON_SECRET` if anyone with access left.
- **On staff exit:** Team → Deactivate. This takes effect immediately.
- **Updates:** a developer applies dependency and security updates through a pull request. CI must pass before merging.
- **Support:** decide and write here who the escalation contact is. Free ongoing maintenance is not guaranteed.
