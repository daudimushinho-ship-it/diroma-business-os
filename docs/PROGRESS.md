# Ubao wa Maendeleo / Progress Board

_Imesasishwa: 5 Novemba 2026. Kipimo: Milestone A ya "DIROMA Master Prompt"._

## ✅ Imekamilika (imejengwa na kupimwa)
- **Database ya msingi:** biashara, maeneo (Stoo, Duka, Njiani, Mbia, Ukaguzi, Karantini), wafanyakazi (memberships), ruhusa kwa kila nafasi.
- **Ulinzi kwenye database (RLS):** kila nafasi inaona tu kinachoruhusiwa, na hakuna anayeweza kuandika kwenye jedwali moja kwa moja.
- **Owner na Meneja lazima wawe na MFA** (`aal2`). Hili linasimamiwa ndani ya database yenyewe, si kwenye skrini tu.
- **Mfanyakazi akisimamishwa, anapoteza ruhusa papo hapo**, hata kama kikao chake bado kipo hai.
- **Audit log isiyoweza kubadilishwa wala kufutwa.**
- **Usanidi wa Owner kwa code ya mara moja**, na **kuwezesha mfanyakazi kwa code ya mara moja.** Majaribio mabaya yanahesabiwa; code haitumiki mara mbili.
- **Urejeshaji wa nenosiri unaosimamiwa na Owner.**
- **Kusawazisha namba za simu:** `0712…`, `712…`, `255712…` na `+255 712…` zote ni akaunti moja. Namba za nchi nyingine hazibadilishwi.
- **App (Next.js):** ukurasa wa kuingia, kuwezesha, usanidi wa Owner, MFA, na kurasa za kila nafasi zenye menyu inayolingana na ruhusa. Kiswahili/Kiingereza. Inafanya kazi kwenye simu na desktop.
- **Kurasa za Timu, Mipangilio (maeneo), Kituo cha Udhibiti (audit log) na Wasifu (kubadili nenosiri).**

## 🧪 Ushahidi wa majaribio
| Jaribio | Matokeo |
|---|---|
| `npm run test:db`: PostgreSQL 16 halisi, majaribio 69 (ruhusa, RLS, MFA, activation, recovery, audit) | **69/69 PASS** |
| `npm test`: unit tests 28 (namba za simu, nenosiri, routing ya nafasi) | **28/28 PASS** |
| `npx tsc --noEmit` | PASS |
| `npm run build` (Next.js 16 production build) | PASS |
| Screenshots: kuingia (desktop + simu) | Imekaguliwa |

## ⏳ Inasubiri uthibitisho kwenye Supabase halisi (Needs external configuration)
Haya **hayajapimwa** kwa sababu mazingira ya ujenzi hayakuweza kuendesha Supabase Auth. Docker images zilizuiwa, na ruhusa ya kujenga Supabase Auth kutoka source ilikataliwa:
1. Kuingia kwa simu + nenosiri kwa nafasi zote 4 na kufika kwenye ukurasa sahihi.
2. Kuwezesha mfanyakazi (`auth.admin.createUser` → code → nenosiri lake).
3. Kuunda na kuthibitisha MFA ya TOTP, na `aal2` kufika kwenye database.
4. Ujumbe wa jumla kwa namba isiyojulikana au nenosiri baya (bila kuvujisha kama namba ipo).
5. Kubadilisha nenosiri.
6. Rate limiting ya Supabase Auth kwenye majaribio ya kuingia.

**Hatua inayofuata kwa Mmiliki:** fungua project ya Supabase ya bure kwa majaribio (angalia `docs/SETUP.md`). Kisha majaribio haya 6 yatafanywa na kuandikwa hapa kama Pass/Fail.

## 🚧 Imezuiliwa
- **Push kwenda GitHub ilikataliwa (403):** Claude GitHub App haina ruhusa kwenye `diroma-business-os`. Kazi yote imehifadhiwa kwenye commit ya ndani kwenye branch `claude/vibrant-turing-2hlcsn`.
- **Logo rasmi ya DIROMA haijatolewa.** Kwa sasa kuna wordmark ya maandishi. Weka faili rasmi kwenye `public/brand/`.

## ⏭️ Inayofuata
- **A+:** urejeshaji wa akaunti ya Owner (kwa recovery codes), kuzima vikao vyote vya mfanyakazi anaposimamishwa, na SMS recovery (baada ya idhini ya gharama).
- **B:** bidhaa na variants (rangi × saizi), barcode, CSV import, **paneli ya Stoo** (kupokea, maombi ya duka, kutuma, kuthibitisha kupokea, kuhesabu), manunuzi na landed cost, na stock ledger moja.
- **C:** POS, malipo, matumizi, marejesho, akaunti za pesa, kufunga zamu.
- **D:** **Wateja wa Jumla** na consignment.
- **E–G:** ripoti, PDF za kila siku, backup na restore, timu, usalama, handover.

## Hali ya moduli (capability matrix)
| Uwezo | Hali |
|---|---|
| Schema, RLS, audit, ruhusa, MFA-gating kwenye DB | Implemented and tested |
| Kusawazisha namba za simu, sera ya nenosiri | Implemented and tested |
| Login simu+nenosiri, MFA, activation (Supabase Auth) | Needs external configuration |
| Kurasa za nafasi na routing | Implemented, unverified (end-to-end) |
| SMS recovery | Planned |
| Bidhaa, Stoo, Manunuzi | Planned (B) |
| POS, Pesa, Kufunga zamu | Planned (C) |
| Wateja wa Jumla / Consignment | Planned (D) |
| Ripoti, backups | Planned (E) |
