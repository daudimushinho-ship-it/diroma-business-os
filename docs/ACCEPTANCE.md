# Mazoezi ya kukubali mfumo (Acceptance rehearsal) — master prompt §19C

**Hali:**
- **Pass (DB)** = imepimwa kwenye PostgreSQL halisi kupitia majaribio ya kiotomatiki (`npm run test:db`).
- **Pass (browser)** = imepimwa kwenye browser halisi kwa data za majaribio.
- **Not tested** = inahitaji Supabase halisi, au kifaa / mtu halisi.

Data zote za majaribio ni za kubuni.

| # | Mazoezi | Matokeo yanayotarajiwa | Hali | Ushahidi |
|---|---|---|---|---|
| 1 | Kuingia kwa namba ya simu + nenosiri: Muuzaji, Meneja, Mtunza Stoo, Owner | Kila mmoja anafika ukurasa wake. `0712…` na `+255712…` ni akaunti moja | Pass (DB + unit): ruhusa na routing. **Not tested**: kuingia halisi kupitia Supabase Auth | `10_foundation_test`, `phone.test.ts`, `roles.test.ts` |
| 2 | Kuunda design yenye saizi kadhaa na kupokea mzigo | Matrix ya rangi × saizi; Stoo inaongezeka | Pass (DB) | `20_stock_test` |
| 3 | Kuhamisha mzigo Stoo → Duka na kuthibitisha kupokea | Stoo 40, njiani 10 → duka 10 | Pass (DB) | `20_stock_test` ACCEPT 1 |
| 4 | Kuuza kipande kimoja | Saizi hiyo inapungua mara moja; risiti = malipo | Pass (DB + browser: POS terminal kwa data za majaribio) | `30_sales_test` |
| 5 | Malipo ya sehemu, kisha kulipa kilichobaki | Hakuna mauzo mapya yanayoundwa | Pass (DB) | `30_sales_test` (makusanyo) |
| 6 | Kutuma consignment 10, kuripoti 6 zimeuzwa, kurudisha 2 | Zinabaki 2 kwa mbia | Pass (DB) | `40_wholesale_test` |
| 7 | Kurudisha bidhaa (idhini ya mtu mwingine) na ukaguzi | Inaingia Ukaguzi; mwombaji hawezi kuidhinisha | Pass (DB) | `30_sales_test` |
| 8 | Kufungua na kufunga zamu yenye tofauti ya pesa | Tofauti inaelezwa na kukaguliwa; M-Pesa/benki haziingii kwenye droo | Pass (DB) | `30_sales_test` |
| 9 | Statement ya mteja + ripoti ya kipindi chote | Zinalingana na ledger (tofauti isiyoelezeka = 0) | Pass (DB) | `40_wholesale_test`, `_reports_checks` |
| 10 | Kunyimwa ruhusa moja kwa moja (si kuficha kitufe tu) | API/RPC/jedwali vinakataa | Pass (DB) | kila suite + `60_privileges_test` |
| 11 | Backup na kurejesha kwenye mazingira tofauti | Kila idadi, jumla na checksum vinalingana | Pass (DB, local) · **Not tested** hosted | recovery 11/11 |
| 12 | Mtandao kukatika, kisha kurudia ombi | Hakuna mauzo yanayorudiwa | Pass (DB: idempotency + maombi 2 ya wakati mmoja) · **Not tested**: simu halisi offline | `20/30` concurrency |
| — | Ufikivu (WCAG 2.1 AA) kwa kurasa za umma | Makosa 0 | Pass (browser, axe) | `npm run a11y` |
| — | Mzigo (wauzaji 8 kwa wakati mmoja) | Hakuna kosa; ledger sahihi | Pass (local, ~418 mauzo/sekunde) — si ahadi ya mfumo halisi | `LOAD_TEST=1 npm run test:db` |
| — | Barcode/QR kwa scanner na printer halisi | Inasomeka | Pass (decoder huru) · **Not tested**: kifaa halisi | `barcode.test.ts` |

## Kinachohitaji kupimwa baada ya Supabase kuunganishwa (kwa vifaa halisi)
1. Kuingia kwa nafasi 4, kuwasha MFA kwa Owner na Meneja, kuwezesha mfanyakazi, na kubadilisha nenosiri.
2. Mzunguko mzima wa POS kwenye simu ya Android ya duka na kwenye laptop.
3. Printer ya risiti (58/80 mm) na scanner ya barcode.
4. Kazi ya kila siku saa 23:30 (Vercel Cron), PDF kufika kwenye storage, na kuipakua kutoka Kituo cha Udhibiti.
5. Backup na kurejesha kwenye project mpya ya Supabase.
6. Catalogue ya umma na QR code kwenye simu ya mteja.

Kila kipengele kinaandikwa Pass / Fail / Not tested, pamoja na tarehe na aliyepima.
