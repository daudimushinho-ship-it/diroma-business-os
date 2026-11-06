# Security — OWASP ASVS 4.0 control-to-test map

Scope: DIROMA Business OS (Next.js 16 on Vercel, Supabase Postgres/Auth/Storage). Level target: ASVS L2 for the business app.
"Evidence" points to the automated test that proves the control. **No certification is claimed.**
Status: ✅ tested here · 🟡 implemented, needs hosted verification · ⛔ gap / owner decision.

| ASVS | Control | Implementation | Evidence | Status |
|---|---|---|---|---|
| V1.4 | Server-side access control, deny by default | All writes via SECURITY DEFINER RPCs with `require_permission`. Tables: SELECT only, through RLS. Clients have no INSERT/UPDATE/DELETE | `60_privileges_test` (no write grants, RLS on every table), every `*_test.sql` "cannot … directly" | ✅ |
| V1.4 | Least privilege on functions | EXECUTE revoked from PUBLIC/anon/authenticated; client RPCs granted by rule; internals and service-only functions locked | `60_privileges_test` (verified to fail without the fix) | ✅ |
| V2.1 | Password policy | ≥ 12 chars, ≤ 72 bytes, never trimmed, password managers allowed | `tests/unit/password.test.ts` | ✅ |
| V2.2 | Generic auth errors, throttling | Generic "phone or password incorrect". Supabase Auth rate limits. Activation/setup codes: 5 attempts, hashed, single use, 24 h | `10_foundation_test` (attempts persisted, replay refused) | ✅ DB / 🟡 Auth limits |
| V2.5 | Credential recovery | Owner-assisted reset cuts access immediately and issues a new one-time code. SMS recovery not configured | `10_foundation_test` recovery block | ✅ / ⛔ SMS |
| V2.8 | MFA for privileged roles | Owner/Manager permissions require `aal2` in the database, not only in the UI | `10_foundation_test` aal1 vs aal2 | ✅ DB / 🟡 TOTP flow |
| V3.3 | Session termination | Suspension/deactivation cuts data access on the next query, and the auth identity is banned (no new tokens) | `10_foundation_test` "suspended (token still valid)" | ✅ DB / 🟡 ban call |
| V3.4 | Cookie security | `@supabase/ssr` cookies (HttpOnly/Secure/SameSite set by the library) | — | 🟡 |
| V4.1 | Object-level authorization | Location scoping (`can_access_location`), business scoping, self-only rows (tasks, commission lines) | `20/30/40/50` tests "sees only …" | ✅ |
| V4.2 | Operation-level / segregation of duties | Requester ≠ approver for discounts, returns, expenses, counts, discrepancies, losses, commissions, shifts, deposits | many "cannot approve own" tests | ✅ |
| V5.1 | Input validation | Server re-validates everything (prices from catalogue, quantities, enums, E.164, URLs, dates) | DB tests: invalid inputs rejected | ✅ |
| V5.3 | Output encoding / injection | React escaping; SQL only via parameterised RPC; CSV formula-injection guard; PDF text sanitised | `csv-import.test.ts`, `pdf.test.ts` | ✅ |
| V7.1 | Logging, no secrets in logs | Append-only `audit_log` (also for superuser); credentials never logged | `10_foundation_test` audit immutable; `secrets.test.ts` | ✅ |
| V8.1 | Data protection / caching | `Cache-Control: private, no-store` on exports; costs hidden from non-cost roles at the DB | `20/30` secrecy tests | ✅ |
| V8.3 | Sensitive data minimisation | Public catalogue: published fields only, yes/no availability | `50_team_test` public catalogue block | ✅ |
| V9.1 | TLS | HSTS 2 years. `upgrade-insecure-requests` on https | header check (curl) | ✅ headers / 🟡 hosting TLS |
| V10.3 | Dependency integrity | `npm audit --omit=dev` = 0 known vulnerabilities (2026-11-10); lockfile committed | CI step | ✅ (point in time) |
| V11.1 | Business logic limits | Idempotency keys (same key + different payload rejected), row locks, CHECK constraints (no negative stock, balanced journal) | concurrency scripts (21 two-session checks), load test | ✅ |
| V12.1 | File upload | CSV only, size limits (2–3 MB), parsed server-side. No user file storage yet | unit tests | ✅ |
| V13.1 | API / cron authentication | `/api/jobs/daily` requires `Authorization: Bearer CRON_SECRET` (≥ 32 chars, timing-safe compare) | code review | 🟡 |
| V14.4 | HTTP security headers | CSP (per-request nonce, `strict-dynamic`, no inline scripts, `frame-ancestors 'none'`), X-Frame-Options, nosniff, Referrer-Policy, Permissions-Policy, COOP | `scripts/a11y-check.cjs`: 0 CSP violations and app hydrates under CSP | ✅ |
| V14.3 | Secrets management | Server keys only in env. `.env*` ignored. Repository secret scan | `tests/unit/secrets.test.ts` | ✅ |

## Known gaps and owner decisions
- **SMS** activation/recovery and **WhatsApp/M-Pesa APIs** are not configured. They need providers and cost approval.
- **Owner account recovery** relies on the Supabase dashboard (Owner's email + MFA on the provider account). Store MFA recovery codes offline.
- **Style CSP** allows inline styles (`'unsafe-inline'` for styles only). Scripts remain strict.
- **Penetration test** by an independent party is recommended before go-live. Not performed.
- Supabase Auth settings (JWT expiry, refresh-token reuse detection, leaked-password protection, CAPTCHA) must be set in the dashboard. See DEPLOY.md.
