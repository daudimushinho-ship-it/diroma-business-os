# Ubao wa Maendeleo / Progress Board

_Imesasishwa: 5 Novemba 2026. Kipimo: Milestones A–B za "DIROMA Master Prompt"._

## ✅ Imekamilika

### Milestone A: Akaunti, nafasi na usalama
- **Database ya msingi:** biashara, maeneo, wafanyakazi, na ruhusa kwa kila nafasi.
- **Ulinzi kwenye database (RLS):** hakuna anayeweza kuandika kwenye jedwali moja kwa moja.
- **MFA ni lazima kwa Owner na Meneja**, ndani ya database yenyewe.
- **Mfanyakazi akisimamishwa, anapoteza ruhusa papo hapo.**
- **Audit log haiwezi kubadilishwa wala kufutwa.**
- **Code za mara moja** kwa usanidi wa Owner, kuwezesha wafanyakazi, na urejeshaji wa nenosiri unaosimamiwa na Owner.
- **Namba za simu zinasawazishwa:** `0712…` = `+255712…`.
- **App:** kuingia, kuwezesha, MFA, Timu, Mipangilio, Kituo cha Udhibiti na Wasifu. Kiswahili/Kiingereza.

### Milestone B: Bidhaa, Stoo na Manunuzi
- **Bidhaa:**
  - Design yenye code halisi (pamoja na `#`).
  - Matrix ya rangi × saizi: suti 42–60, viatu 39–46, shati S–3XL.
  - Bei za rejareja na jumla. Bidhaa isiyo na bei inaonyeshwa "bila bei", **haigeuzwi kuwa sifuri**.
- **Barcode (Code 128) na lebo zisizo na bei.** Zimepimwa kwa decoder huru (ZXing): zinasomwa sahihi, zikiwemo zenye sifuri mwanzoni.
- **CSV import:**
  - Template na hakiki (preview) kabla ya kuingiza.
  - Makosa yanaonyeshwa kwa kila mstari.
  - Sera ya variant iliyopo tayari ni wazi: iwe kosa, au ibadilishe bei.
  - **Inakubaliwa yote au inakataliwa yote.** Kurudia import ileile hakubadilishi kitu.
- **Stock ledger moja** kwa Stoo, Duka na Njiani:
  - Stoki haiwezi kuwa hasi.
  - Stoki iliyohifadhiwa (reserved) haizidi iliyopo.
  - Kila mabadiliko yana hati, mtu aliyefanya na muda.
- **Paneli ya Stoo** (inajitegemea kwenye menyu). Tabs: Muhtasari, Pokea mzigo, Stoki kwa saizi, Maombi ya duka, Mzigo njiani, Mapungufu, Kuhesabu, Historia, Ripoti, Stoki ya mwanzo.
- **Mtiririko wa Stoo → Duka:**
  1. Duka linaomba mzigo.
  2. Meneja anaidhinisha, na stoki inahifadhiwa (reserve).
  3. Mtunza Stoo anatuma mzigo, unaingia "njiani".
  4. Duka linathibitisha kiasi halisi kilichofika.
  5. Kilichopungua kinabaki "njiani" kama pungufu (discrepancy) hadi Meneja huru akitatue.
- **Kuhesabu stoo bila kuona idadi ya mfumo (blind count).** Mabadiliko yaliyotokea wakati wa kuhesabu yanazingatiwa, na idhini lazima itoke kwa mtu tofauti na aliyehesabu.
- **Manunuzi:**
  - Suppliers na PO (TZS/USD/CNY pamoja na kiwango cha ubadilishaji).
  - Mtunza Stoo anaona idadi tu, **haoni bei**.
  - Mzigo unapokelewa kwa sehemu (partial).
  - **Owner** anaidhinisha gharama na kugawa gharama za ziada (usafiri, ushuru, clearing). Mgawanyo unazungushwa ili jumla ilingane kwa shilingi kamili.
- **Gharama za kununua ni siri:** Muuzaji, Mtunza Stoo na Meneja hawazioni.
- **Ripoti ya kipindi** (mwanzo / ingia / toka / mwisho), inayohesabiwa upande wa server, na **CSV export** iliyolindwa dhidi ya formula injection.
- **Stoki ya Dukani:** stoki kwa saizi, mzigo unaoingia, kuomba mzigo, maombi yangu, historia, ripoti.

## 🧪 Ushahidi wa majaribio
| Jaribio | Matokeo |
|---|---|
| `npm run test:db`, Milestone A: ruhusa, RLS, MFA, activation, recovery, audit | **69/69 PASS** |
| `npm run test:db`, Milestone B: catalogue, ledger, mifano ya master prompt, gharama, counts, import, ripoti | **74/74 PASS** |
| Ushindani (vikao 2 halisi vya PostgreSQL): kipande cha mwisho, maombi yanayorudiwa kwa wakati mmoja | **7/7 PASS** |
| Select contract: kila `.from().select()` ya app dhidi ya schema halisi | **36/36 OK** |
| `npm test`: unit tests (simu, nenosiri, roles, barcode decode, CSV, RPC contract 38) | **75/75 PASS** |
| `tsc --noEmit`, `next build` | PASS |

**Mifano ya lazima ya master prompt (§7B), yote imepita:**
- **Pokea 50, tuma 10:** Stoo 40, njiani 10, duka 0. Duka likithibitisha: Stoo 40, duka 10. Stoki yote ya kampuni inabaki 50; transfer haihesabiwi mara mbili.
- **Tuma 10, pokea 8:** duka 8, na 2 zinabaki njiani kama pungufu wazi. Hazifutwi wala hazihesabiwi kama zimeuzwa.
- **Kurudia kutuma au kuthibitisha:** idadi hazibadiliki.
- **Watu wawili wakitoa kipande cha mwisho kwa wakati mmoja:** mmoja tu anafanikiwa.

**Hitilafu 2 halisi zilizogunduliwa na majaribio kisha kurekebishwa:**
- `count_decide` ilipitisha `bigint` kwa `_move(int)`.
- Majaribio mabaya ya code yalikuwa yanafutwa pamoja na rollback, hivyo hayakuhesabiwa.

## ⏳ Inasubiri uthibitisho kwenye Supabase halisi
Mazingira ya ujenzi hayawezi kuendesha Supabase Auth wala PostgREST: Docker images zimezuiwa, na ruhusa ya kujenga Auth ilikataliwa. Kwa hiyo haya hayajapimwa **end-to-end** kupitia skrini:
1. Kuingia kwa simu + nenosiri (nafasi 4), MFA, kuwezesha mfanyakazi, kubadili nenosiri, rate limiting.
2. Kurasa za Milestone B: Bidhaa, Stoo, Stoki ya Dukani, Manunuzi.
   - Mantiki yote iliyo nyuma yake imepimwa kwenye database.
   - Wito wote wa `rpc()` na `select` umethibitishwa kulingana na schema.
   - Kilichobaki ni kubofya skrini kwenye mfumo halisi.
3. Barcode kwa scanner na printer halisi za dukani.

**Hatua inayofuata kwa Mmiliki:** fungua project ya bure ya Supabase (`docs/SETUP.md`). Kisha nitapima kila mtiririko kwenye skrini na kuandika hapa Pass/Fail.

## 🚧 Imezuiliwa
- **Push kwenda GitHub ilikataliwa (403):** Claude GitHub App haina ruhusa kwenye `diroma-business-os`. Kazi iko kwenye commits za ndani kwenye `claude/vibrant-turing-2hlcsn`.
- **Logo rasmi ya DIROMA haijatolewa.**

## 📝 Maamuzi ya muda (yameandikwa wazi)
- **Gharama ya wastani (avg cost):** kwa sasa ni wastani wa manunuzi yote yaliyoidhinishwa (cumulative purchase-weighted). Wastani endelevu unaoendana na COGS utaongezwa pamoja na mauzo katika Milestone C.
- **Bidhaa iliyopotea njiani ("written off"):** inatoka kwenye stoki ya kampuni. Athari yake ya kifedha (hasara) itaingizwa kwenye ledger ya fedha katika Milestone C.
- **Saa za biashara:** Africa/Dar_es_Salaam (UTC+03:00, haina DST). Mipaka ya siku kwenye ripoti inafuata saa hizi.

## ⏭️ Inayofuata
- **C:** POS (lazima uchague saizi, bei ya variant), malipo (cash/M-Pesa/benki, malipo kiasi au mchanganyiko), matumizi, marejesho + ukaguzi, akaunti za pesa, kufunga zamu, ledger ya fedha (double-entry), COGS.
- **D:** **Wateja wa Jumla** na consignment.
- **E–G:** ripoti kamili, PDF za kila siku, backup na restore, timu, usalama, handover.

## Hali ya moduli (capability matrix)
| Uwezo | Hali |
|---|---|
| Schema, RLS, audit, ruhusa, MFA-gating kwenye DB | Implemented and tested |
| Catalogue, variants, barcodes, CSV import | Implemented and tested (DB + unit) |
| Stock ledger, Stoo, maombi, transfers, mapungufu, counts | Implemented and tested (DB + concurrency) |
| Manunuzi, landed cost, usiri wa gharama | Implemented and tested (DB) |
| Kurasa za Milestone B (UI) | Implemented, unverified end-to-end |
| Login simu+nenosiri, MFA, activation (Supabase Auth) | Needs external configuration |
| SMS recovery | Planned |
| POS, Pesa, Kufunga zamu | Planned (C) |
| Wateja wa Jumla / Consignment | Planned (D) |
| Ripoti kamili, backups | Planned (E) |
