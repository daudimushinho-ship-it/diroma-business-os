# Ubao wa Maendeleo / Progress Board

_Imesasishwa: 6 Novemba 2026. Kipimo: Milestones A–C za "DIROMA Master Prompt"._

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

### Milestone C: POS, malipo, fedha na kufunga zamu
- **POS** (desktop safu 3; simu hatua 3: Tafuta → Kikapu → Malipo):
  - Lazima uchague rangi na saizi. **Bei inawekwa na server** kutoka kwenye catalogue, si kutoka kwenye skrini.
  - Bidhaa isiyo na bei haiuzwi.
  - Bei ya jumla inatumika kwa mteja wa jumla tu.
  - Malipo mchanganyiko (cash + M-Pesa + benki + salio la mteja).
  - Kupeleka kwa mteja (delivery fee), na mauzo yaliyosahaulika (tarehe ya nyuma) kwa idhini.
  - Risiti yenye namba ya kipekee. Kuchapisha tena hakurekodi mauzo upya.
- **Idhini zinazofungwa na ombi lenyewe.** Punguzo juu ya kikomo (Muuzaji 5%, Meneja 15%), tarehe ya nyuma, na mkopo juu ya kikomo vinahitaji mtu mwingine kuidhinisha. Ombi likibadilika baada ya idhini (mfano idadi), idhini haifanyi kazi, na idhini moja haitumiki mara mbili.
- **Mkopo:**
  - Mteja wa kupita lazima alipe yote.
  - Mteja aliyesajiliwa anakopeshwa ndani ya kikomo chake.
  - Makusanyo yanalipa deni la zamani kwanza (FIFO), na ziada inakuwa salio la mteja.
  - **Kukusanya deni la zamani si mauzo mapya.**
- **Marejesho:**
  - Ombi → idhini huru → bidhaa zinaingia **Ukaguzi**, hazirudi moja kwa moja dukani.
  - Kiasi kinapunguza deni la mauzo hayo kwanza; kinachobaki kinakuwa salio la mteja au pesa ya kurudisha.
  - Pesa hairudishwi mara mbili, hata ombi likirudiwa.
  - Baada ya ukaguzi: zinarudi dukani au zinaenda "zimeharibika".
- **Mauzo yasiyofika (failed delivery):** ni hali tu, bidhaa hazirudi stoo kimya kimya.
- **Fedha:**
  - Akaunti (droo ya kila duka, M-Pesa, benki) na salio la kuanzia (mara moja tu).
  - **Kuweka benki** ni uhamisho: pesa iko "njiani" hadi mtu mwingine athibitishe, na ada inarekodiwa kama matumizi peke yake.
  - **Matumizi:** ombi → idhini huru → kulipwa mara moja tu.
  - **Posho za usafirishaji:** posho si matumizi. Matumizi yanarekodiwa mara moja tu, wakati wa kufunga posho.
- **Kufunga zamu:**
  - Kinachotarajiwa = float + pesa taslimu iliyoingia − iliyotoka (kwenye droo hiyo tu; M-Pesa na benki hazihesabiwi).
  - Tofauti lazima ielezwe, na inakaguliwa na mtu huru kisha inarekodiwa kama "cash over/short".
  - Mauzo yanayoendelea wakati wa kufunga yanasubiriwa na kujumuishwa. Baada ya kufunga, hakuna mauzo mapya kwenye zamu hiyo.
- **Ledger ya double-entry:**
  - Kila tukio lina entry inayolingana (debit = credit), inayokaguliwa mara mbili.
  - Journal haiwezi kubadilishwa wala kufutwa.
  - COGS kwa gharama ya wastani wakati wa mauzo. Gharama isiyojulikana **inaonyeshwa wazi**, haigeuzwi kuwa sifuri.
  - Risiti za manunuzi, upotevu wa njiani na tofauti za kuhesabu sasa zinaingia kwenye ledger.
- **Kurasa:** POS, Zamu yangu, Risiti, Rejista ya mauzo, Mauzo moja (marejesho, kurudisha pesa, kupeleka), Wateja (salio, makusanyo), Idhini, Fedha (akaunti, kuweka benki, matumizi, posho, journal), Ukaguzi kwenye Stoo.
- **Muhtasari wa Owner** wenye takwimu halisi kutoka kwenye ledger:
  - Mauzo halisi (kwa tarehe ya mauzo) dhidi ya makusanyo (kwa tarehe ya malipo).
  - Faida ghafi, pamoja na onyo vipande vikiuzwa bila gharama inayojulikana.
  - Pesa kwa aina, madeni, salio za wateja, stoki inayouzika, na thamani ya stoki.

## 🧪 Ushahidi wa majaribio
| Jaribio | Matokeo |
|---|---|
| `npm run test:db`, Milestone A: ruhusa, RLS, MFA, activation, recovery, audit | **69/69 PASS** |
| `npm run test:db`, Milestone B: catalogue, ledger, mifano ya master prompt, gharama, counts, import, ripoti | **74/74 PASS** |
| `npm run test:db`, Milestone C: POS, idhini, mkopo, makusanyo, marejesho, matumizi, kuweka benki, posho, zamu, journal, muhtasari | **70/70 PASS** |
| Ushindani B (vikao 2 halisi): kipande cha mwisho kwa transfer, maombi yanayorudiwa | **7/7 PASS** |
| Ushindani C (vikao 2 halisi): wauzaji 2 wakiuza kipande cha mwisho; kufunga zamu wakati mauzo yanaendelea | **8/8 PASS** |
| Select contract: kila `.from().select()` ya app dhidi ya schema halisi | **67/67 OK** |
| `npm test`: unit tests (simu, nenosiri, roles, barcode decode, CSV, RPC contracts) | **103/103 PASS** |
| POS terminal kwenye browser (data za majaribio): hesabu ya kikapu, "Lipa yote", desktop na simu | Imekaguliwa |
| `tsc --noEmit`, `next build` | PASS |

**Mifano ya lazima ya master prompt (§7B), yote imepita:**
- **Pokea 50, tuma 10:** Stoo 40, njiani 10, duka 0. Duka likithibitisha: Stoo 40, duka 10. Stoki yote ya kampuni inabaki 50; transfer haihesabiwi mara mbili.
- **Tuma 10, pokea 8:** duka 8, na 2 zinabaki njiani kama pungufu wazi. Hazifutwi wala hazihesabiwi kama zimeuzwa.
- **Kurudia kutuma au kuthibitisha:** idadi hazibadiliki.
- **Watu wawili wakitoa kipande cha mwisho kwa wakati mmoja:** mmoja tu anafanikiwa.

**Mifano ya master prompt §17 iliyothibitishwa kwenye Milestone C:**
- **Mauzo 2 ya wakati mmoja ya kipande cha mwisho:** moja tu linafanikiwa.
- **Maombi yanayorudiwa:** hayarudii mauzo, stoki, malipo, kuweka benki, marejesho wala kurudisha pesa. Ufunguo uleule ukija na data tofauti, unakataliwa.
- **Malipo kiasi, salio la mteja, mgawanyo, marejesho na kurudisha pesa** vinalingana na ledger.
- **Hakuna kurudisha pesa juu ya kinachostahili,** na idhini ni huru.
- **Kuweka benki si mapato wala matumizi;** posho ya usafirishaji haihesabiwi mara mbili.
- **Kufunga zamu kunashughulikia mauzo yanayoendelea,** na M-Pesa/benki haziingii kwenye pesa ya droo.
- **Gharama isiyojulikana haileti faida ya uongo.**

**Hitilafu halisi zilizogunduliwa na majaribio kisha kurekebishwa:**
- `count_decide` ilipitisha `bigint` kwa `_move(int)`.
- Majaribio mabaya ya code yalikuwa yanafutwa pamoja na rollback, hivyo hayakuhesabiwa.
- Trigger ya kukagua usawa wa journal ilifichwa na RLS (sasa ni `SECURITY DEFINER`).
- Script ya majaribio haikurudisha exit code ya kosa. Sasa inarudisha.

## ⏳ Inasubiri uthibitisho kwenye Supabase halisi
Mazingira ya ujenzi hayawezi kuendesha Supabase Auth wala PostgREST: Docker images zimezuiwa, na ruhusa ya kujenga Auth ilikataliwa. Kwa hiyo haya hayajapimwa **end-to-end** kupitia skrini:
1. Kuingia kwa simu + nenosiri (nafasi 4), MFA, kuwezesha mfanyakazi, kubadili nenosiri, rate limiting.
2. Kurasa za Milestone B–C: Bidhaa, Stoo, Stoki ya Dukani, Manunuzi, POS, Mauzo, Wateja, Fedha, Idhini.
   - Mantiki yote iliyo nyuma yake imepimwa kwenye database.
   - Wito wote wa `rpc()` na `select` umethibitishwa kulingana na schema.
   - Kilichobaki ni kubofya skrini kwenye mfumo halisi.
3. Barcode kwa scanner na printer halisi za dukani.

**Hatua inayofuata kwa Mmiliki:** fungua project ya bure ya Supabase (`docs/SETUP.md`). Kisha nitapima kila mtiririko kwenye skrini na kuandika hapa Pass/Fail.

## 🚧 Imezuiliwa
- **Push kwenda GitHub ilikataliwa (403):** Claude GitHub App haina ruhusa kwenye `diroma-business-os`. Kazi iko kwenye commits za ndani kwenye `claude/vibrant-turing-2hlcsn`.
- **Logo rasmi ya DIROMA haijatolewa.**

## 📝 Maamuzi ya muda (yameandikwa wazi)
- **Gharama ya wastani:** COGS inatumia wastani wa manunuzi yote yaliyoidhinishwa (cumulative purchase-weighted) wakati wa mauzo. Stoki ya mwanzo haina gharama hadi Owner aiweke, kwa hiyo thamani ya stoki kwenye ledger inaweza kutofautiana kidogo na idadi × wastani. Ripoti ya kulinganisha hizo mbili itakuja Milestone E.
- **Droo ya pesa:** float ya kuanzia zamu haiingizwi kwenye ledger (ni pesa iliyokuwepo tayari). Tumia "salio la kuanzia" la akaunti ya droo ikiwa unataka salio la droo kwenye rekodi lilingane na pesa halisi.
- **Kufungua tena zamu iliyofungwa:** bado haijajengwa. Marekebisho yanafanywa kwa entry mpya, si kwa kufuta.
- **Uthibitisho wa M-Pesa:** malipo yote yamewekwa alama "manual" (yameingizwa kwa mkono). Kulinganisha na statement ya M-Pesa kutakuja na integrations.
- **Kodi (TRA/EFD) na mishahara:** hazijajengwa, na hazitabuniwa bila nyaraka rasmi.
- **Saa za biashara:** Africa/Dar_es_Salaam (UTC+03:00, haina DST). Mipaka ya siku kwenye ripoti inafuata saa hizi.

## ⏭️ Inayofuata
- **D:** **Wateja wa Jumla** na consignment.
- **E–G:** ripoti kamili, PDF za kila siku, backup na restore, timu, usalama, handover.

## Hali ya moduli (capability matrix)
| Uwezo | Hali |
|---|---|
| Schema, RLS, audit, ruhusa, MFA-gating kwenye DB | Implemented and tested |
| Catalogue, variants, barcodes, CSV import | Implemented and tested (DB + unit) |
| Stock ledger, Stoo, maombi, transfers, mapungufu, counts | Implemented and tested (DB + concurrency) |
| Manunuzi, landed cost, usiri wa gharama | Implemented and tested (DB) |
| POS, idhini, mkopo, makusanyo, marejesho, ukaguzi | Implemented and tested (DB + concurrency) |
| Akaunti za pesa, kuweka benki, matumizi, posho, kufunga zamu, journal | Implemented and tested (DB + concurrency) |
| Kurasa za Milestone B–C (UI) | Implemented, unverified end-to-end (POS terminal imekaguliwa kwa data za majaribio) |
| Login simu+nenosiri, MFA, activation (Supabase Auth) | Needs external configuration |
| SMS recovery | Planned |
| Wateja wa Jumla / Consignment | Planned (D) |
| Ripoti kamili, backups | Planned (E) |
