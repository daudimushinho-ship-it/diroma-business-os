# Ubao wa Maendeleo / Progress Board

_Imesasishwa: 9 Novemba 2026. Kipimo: Milestones A–G za "DIROMA Master Prompt"._

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

### Milestone D: Wateja wa Jumla na Consignment
- **Paneli yake peke yake** kwenye menyu ("Wateja wa Jumla"). Si filter ya wateja, wala duka lenye jina la "wholesale".
- **Njia mbili:**
  - **Mauzo ya jumla ya moja kwa moja** kutoka Stoo au Duka, kwa bei ya jumla. Deni juu ya kikomo au punguzo kubwa vinahitaji idhini ya mtu mwingine.
  - **Consignment:** mzigo wetu unakaa kwa mbia hadi atoe taarifa.
- **Mbia (partner):** mteja wa jumla anayewashiwa consignment. Anapata "eneo" lake kwenye stock ledger ileile, pamoja na siku kati ya taarifa.
- **Mtiririko wa consignment:**
  1. Meneja anaunda oda kwa bei iliyokubaliwa, na stoki inahifadhiwa (reserve) Stoo.
  2. Mtunza Stoo anatuma mzigo, akirekodi jina la aliyepokea na ushahidi. Aliyeunda oda hawezi kuituma mwenyewe.
  3. **Kutuma si mapato wala deni.** Ni mzigo wetu ulioko kwa mbia, na hauhesabiwi kama unaouzika.
  4. Taarifa ya mbia inagawanywa hivi:
     - **Ameuza** → invoice kwa bei iliyokubaliwa (mapato + deni + COGS).
     - **Amerudisha** → bidhaa zinaenda Ukaguzi.
     - **Zimepotea** → zinasubiri uamuzi wa mtu huru: kumtoza mbia, kufuta kama hasara, au kukataa.
  5. Kila mstari wa mzigo uliotumwa unahesabika kikamilifu: aliyouza + aliyorudisha + zilizopotea + zinazosubiri + alizonazo = alizotumiwa.
- **Muhtasari wa wabia wote bila kufungua kila mmoja:** aliyotumiwa, aliyouza, aliyorudisha, zilizopotea, alizonazo (na thamani yake), invoices, alicholipa, deni halisi, salio lake, deni linaloiva, taarifa inayofuata, na mambo yasiyotatuliwa.
- **Malipo** yanalipa invoice za zamani kwanza. **Marejesho ya bidhaa zilizokwisha kuuzwa** yanapitia idhini huru na ukaguzi.
- **Statement ya kila mbia** (salio la mwanzo, mabadiliko, salio la mwisho) na **muhtasari wa wabia wote**, vyote vinaweza kuchapishwa au kuhifadhiwa kama PDF kupitia browser.
- **Ukumbusho:**
  - Wabia waliofikia muda wa kutoa taarifa wanaonyeshwa.
  - Kitufe kinafungua WhatsApp na ujumbe ukiwa tayari, kisha unabofya "Nimekumbusha" ili kurekodi.
  - **Mfumo hautumi ujumbe wenyewe**, na haudai kuwa umefika.
- **Stoo:** tab mpya "Tuma kwa mbia". **Idhini:** sehemu mpya "Upotevu unaosubiri uamuzi".

### Milestone E: Ripoti, PDF za kila siku, backup na urejeshaji
- **Ripoti 12 zinazohesabiwa na server kwa kipindi chote** (hakuna kukatwa kwa kurasa):
  - mauzo, makusanyo, kulinganisha mauzo na makusanyo, faida na hasara (P&L);
  - utendaji wa bidhaa (sell-through, faida %), stoki na thamani (umri, siku za stoki);
  - umri wa madeni, matumizi, wafanyakazi, wateja wa jumla, mambo yasiyo ya kawaida, na trial balance.
- **Tarehe ziko wazi:**
  - Mauzo yanahesabiwa kwa tarehe ya mauzo, makusanyo kwa tarehe ya malipo, na salio "hadi tarehe fulani".
  - Muda ni Africa/Dar_es_Salaam.
- **Kulinganisha mauzo na makusanyo:**
  - Makusanyo = mauzo halisi + kupeleka − mabadiliko ya madeni + mabadiliko ya salio za wateja + pesa zilizorudishwa.
  - Tofauti isiyoelezeka imepimwa kuwa **0**.
- **Vipindi:** leo, jana, wiki, siku 7, mwezi, mwezi uliopita, robo, nusu mwaka, mwaka, au tarehe unazochagua.
  - **Ulinganisho ni wa kipindi sawa.** Mfano: tarehe 1–15 Nov inalinganishwa na 1–15 Okt, si Oktoba yote.
  - Ulinganisho unaandikwa "haupatikani" kama hakuna data ya kipindi hicho.
- **Usiri:**
  - Gharama na faida zinaonekana kwa wenye ruhusa ya gharama tu.
  - Meneja haoni P&L wala trial balance.
  - Muuzaji haoni ripoti.
- **Export:**
  - CSV, iliyolindwa dhidi ya formula injection.
  - PDF yenye nembo, kipindi, muda, aliyeitengeneza, namba ya rejea, jumla, na "Page X of Y".
- **PDF ya kila siku** (saa 23:30 ya siku, na ya mwisho saa 00:15 kwa siku iliyopita):
  - Inatengenezwa na server, kwa hiyo haihitaji simu wala browser kuwa wazi.
  - **Inazuia nakala zinazojirudia:** kama hakuna data mpya, toleo jipya haliundwi. Data ikiongezeka baadaye, toleo la 2 linaundwa.
  - Ikishindwa, inajaribiwa tena hadi mara 3.
  - Inahifadhiwa kwenye storage ya siri pamoja na SHA-256.
  - Kituo cha Udhibiti kinaonyesha hali yake, na PDF inapakuliwa kwa kiungo cha sekunde 60.
- **Backup:**
  - `scripts/backup.sh` inachukua data yote kwa wakati mmoja (snapshot moja), inaisimba kwa AES-256, na inatengeneza manifest yenye idadi za rekodi, jumla za ledger na checksums.
  - `scripts/restore-verify.sh` inarejesha kwenye database tupu tofauti, kisha inathibitisha kuwa **kila namba inalingana**.

### Milestone F: Timu, malengo, commission na catalogue ya umma
- **Malengo ya maudhui (msingi wa master prompt):** reels 3 kwa siku, 21 kwa wiki, na 3 × siku za mwezi kwa mwezi (mfano Novemba = 90). Posts za bidhaa ni 100 kwa mwezi. **Owner anaweza kuyabadilisha.**
- **Malengo ya mauzo hayabuniwi.** Yanaonekana tu Owner akiyaweka (kwa biashara au kwa mfanyakazi). Maendeleo yanahesabiwa kutoka kwenye mauzo halisi, baada ya marejesho.
- **Maudhui yenye ushahidi:**
  - Kila reel au post inahitaji kiungo `https://`. Kiungo kimoja hakihesabiwi mara mbili, na huwezi kurekodi posts za zaidi ya siku 31 zilizopita.
  - **Mtu mwingine anathibitisha.** Post iliyokataliwa haihesabiwi.
- **Kazi:** Meneja anampa mfanyakazi kazi yenye muda wa mwisho. Mhusika peke yake ndiye anaimaliza, na lazima aweke ushahidi. Meneja anaithibitisha, au anairudisha akieleza kinachokosekana. Zilizochelewa zinaonyeshwa.
- **Wateja watarajiwa:**
  - Mtiririko ni ombi → ufuatiliaji → kufika dukani → **kuunganishwa kwa mauzo kwa mkono**. Mfumo haukisii.
  - Mteja akijulikana, mauzo lazima yawe yake. Asipojulikana, sababu lazima iandikwe.
  - Mauzo moja hayahesabiwi kwa maombi mawili.
  - Kuna ripoti ya "wanatoka wapi" kwa kila chanzo (Instagram, WhatsApp, n.k.).
- **Commission:**
  - Viwango vinawekwa na Owner tu (si zaidi ya 50%). Kunaweza kuwa na mpango kwa nafasi, au kwa mtu mmoja.
  - Inaweza kuwa na kiwango cha chini cha mauzo, au sharti la kazi zote kuthibitishwa.
  - **Marejesho yanakatwa.**
  - Mtiririko ni: kuhesabiwa → kuidhinishwa na mtu mwingine (ikirekodiwa kwenye ledger kama deni la kulipa) → kulipwa mara moja kutoka benki au simu.
  - Hakuna vipindi vinavyopishana. Mfanyakazi anaona commission yake tu, baada ya kuidhinishwa.
  - **Hakuna makato ya kisheria yanayobuniwa.**
  - P&L na muhtasari sasa vinajumuisha commission.
- **Catalogue ya umma `/c/<slug>`** (hiari): designs zilizochapishwa tu, bei ya "kuanzia" ya rejareja, na saizi "ipo / haipo". Hakuna gharama, bei ya jumla wala idadi kamili ya stoki. Ina kitufe cha "Uliza WhatsApp" na QR code ya kuchapisha.
- **Integrations (Mipangilio):** inaonyesha kwa uaminifu kipi kimesanidiwa na kipi bado (SMS, WhatsApp API, M-Pesa API, TRA/EFD).

### Milestone G: Usalama, kuhamia kutoka MauzoTrack, ukaguzi na makabidhiano
- **Usalama wa browser:** kila ukurasa una Content-Security-Policy yenye nonce ya kila ombi (`proxy.ts`), na scripts za nje zimezuiwa. Pia HSTS, COOP, `frame-ancestors 'none'`, na Permissions-Policy (kamera, mic, mahali, malipo vimezimwa).
- **Mfanyakazi akisimamishwa au kuondolewa:** sasa anazuiwa pia kwenye Supabase Auth (si ruhusa za database tu), kwa hiyo hawezi kuingia tena hata akiwa na nenosiri.
- **Ramani ya OWASP ASVS** (`docs/SECURITY.md`): kila hitaji na ushahidi wake, au "haijapimwa" pale ambapo halijapimwa.
- **Kuhamia kutoka MauzoTrack** (`Mipangilio → MauzoTrack → DIROMA`, `docs/MIGRATION.md`):
  - Kuingiza wateja na madeni yao ya mwanzo: deni linakuwa "salio la kuanzia" (journal Dr 1100 / Cr 3000), si mauzo mapya.
  - Kuingiza stoki ya mwanzo kwa kila eneo, kama hati moja kwa kila eneo.
  - Kuna "jaribio" (dry-run) linaloonyesha makosa ya kila mstari kabla ya kuandika chochote. Kurudia import ileile hakuongezi data mara mbili.
  - Madeni ya mwanzo **hayahesabiwi** kama mauzo kwenye ripoti, malengo wala commission.
- **Audit log inapakuliwa kama CSV** kutoka Kituo cha Udhibiti.
- **Ukaguzi wa ufikivu (axe-core) na CSP** kwenye kila ukurasa wa umma na wa kuingia: hakuna kosa la ufikivu, hakuna ukiukaji wa CSP, na kurasa zinafanya kazi (hydrated).
- **Jaribio la mzigo (pgbench):** wauzaji 8 kwa wakati mmoja kwa sekunde 20.
- **Jaribio la siri:** hakuna ufunguo wa siri (service role, CRON_SECRET) unaoweza kufika kwenye code ya browser.
- **CI** (`.github/workflows/ci.yml`): tsc, unit tests, npm audit, majaribio ya database na build. Inaendeshwa na GitHub Actions kwenye kila pull request na kila push kwenda `main`.
- **Nyaraka za makabidhiano:** `HANDOVER.md`, `ACCEPTANCE.md`, `DEPLOY.md`, `MIGRATION.md`, `SECURITY.md`, na miongozo ya nafasi 4 ndani ya `docs/guides/`.

### 🔐 Marekebisho ya usalama yaliyogunduliwa kwenye Milestone F
PostgreSQL inampa kila mtu (`PUBLIC`) ruhusa ya kuendesha function mpya kwa default. Functions za Milestones C–F, zikiwemo za ndani kama `_post_journal` na `_move`, na za server pekee kama `daily_snapshot`, zingeweza kuitwa na mtumiaji yeyote, hata asiyeingia.
- **Imerekebishwa:** migration mpya inafunga kila kitu, kisha inatoa ruhusa kwa majina tu.
- **Jaribio jipya la kudumu (`60_privileges_test`, ukaguzi 9) linashindwa mara moja kama tatizo hili litarudi.** Nimethibitisha kuwa linashindwa (mara 5) bila marekebisho haya.
- Pia linakagua kuwa kila jedwali lina RLS, na kwamba watumiaji hawana INSERT/UPDATE/DELETE moja kwa moja.

## 🌐 Supabase staging (`diroma-staging`, Frankfurt): 6 Novemba 2026
Imesanidiwa kupitia Supabase Management API kwa token ya muda iliyowekwa na Mmiliki kwenye fomu salama:
- **Migrations zote 13 zimeingia** kwenye PostgreSQL 17 halisi bila kosa.
- **Ukaguzi wa ruhusa kwenye DB halisi:**
  - Majedwali 72, yote yana RLS.
  - Function 0 zinazoweza kuitwa na `anon` (isipokuwa `public_catalogue`).
  - Ruhusa 0 za INSERT/UPDATE/DELETE moja kwa moja.
  - Helper 1 tu ya RLS (`_has_commission_line`), kwa makusudi.
- **Auth:**
  - Usajili wa umma umezimwa.
  - Kuingia kwa simu kumewashwa, na email login imezimwa.
  - Nenosiri lazima liwe angalau herufi 12, na TOTP MFA imewashwa.
- **Bucket ya `reports`** (private, PDF tu) imeundwa.
- **Majaribio ya Auth halisi** (kwa mtumiaji wa muda, aliyefutwa baadaye):

| Jaribio | Matokeo |
|---|---|
| Kuunda mtumiaji kwa simu bila SMS | PASS |
| Usajili wa umma unakataliwa | PASS |
| Simu + nenosiri | PASS |
| Nenosiri baya linakataliwa | PASS |
| Session inaanza `aal1` | PASS |
| Asiye na membership haoni data | PASS |
| Kuandika moja kwa moja kwenye jedwali kunakataliwa | PASS |
| Email login inakataliwa | PASS |
| QR ya MFA inatengenezwa | PASS |

- **Hitilafu halisi iliyogunduliwa na kurekebishwa:**
  - **Tatizo:** Supabase haiwezi kutengeneza QR ya MFA kwa mtumiaji mwenye simu tu ("Error generating QR Code").
  - **Suluhisho:** kila mtumiaji sasa anapewa anwani isiyopokea barua, `<namba>@phone.diroma.invalid`, ambayo haiwezi kutumika kuingia kwa sababu email login imezimwa.
  - Imethibitishwa kwenye Supabase halisi.
- **Hosting:** Vercel project `diroma-business-os` (https://diroma-business-os.vercel.app). Funguo 4 zimewekwa kupitia API (secret key na CRON_SECRET kama "sensitive"), kwa hiyo Mmiliki hakunakili funguo yoyote kwa mkono.
- **Usanidi wa Mmiliki: PASS (end-to-end kwenye mfumo halisi, 6 Nov 2026).**
  - Mtiririko: `/setup` kwa code ya mara moja → akaunti → MFA (TOTP) → Muhtasari wa Biashara.
  - DB inaonyesha: membership `owner`/`active`, MFA factor 1 imethibitishwa, anwani ya ndani ipo, na audit `owner.bootstrap`.
- **Bado:** kuwezesha wafanyakazi, kurasa za kazi (POS, Stoo n.k.) na cron hazijapimwa end-to-end.

## 🧪 Ushahidi wa majaribio
| Jaribio | Matokeo |
|---|---|
| `npm run test:db`, Milestone A: ruhusa, RLS, MFA, activation, recovery, audit | **69/69 PASS** |
| `npm run test:db`, Milestone B: catalogue, ledger, mifano ya master prompt, gharama, counts, import, ripoti | **74/74 PASS** |
| `npm run test:db`, Milestone C: POS, idhini, mkopo, makusanyo, marejesho, matumizi, kuweka benki, posho, zamu, journal, muhtasari | **70/70 PASS** |
| Ushindani B (vikao 2 halisi): kipande cha mwisho kwa transfer, maombi yanayorudiwa | **7/7 PASS** |
| Ushindani C (vikao 2 halisi): wauzaji 2 wakiuza kipande cha mwisho; kufunga zamu wakati mauzo yanaendelea | **8/8 PASS** |
| `npm run test:db`, Milestone D: consignment, taarifa, upotevu, mauzo ya jumla, statement, usiri | **44/44 PASS** |
| Ushindani D (vikao 2 halisi): watu 2 wakiripoti kipande cha mwisho kilichopo kwa mbia | **6/6 PASS** |
| `npm run test:db`, Milestone E (ndani ya suite ya mauzo, 97 kwa jumla): ripoti zinalingana na ledger, kulinganisha = 0, mauzo 300 ya ziada yote yamehesabiwa, usiri, matoleo ya kazi za kila siku | **97/97 PASS** |
| Backup → restore → verify kwenye PostgreSQL halisi: kila idadi/jumla/checksum, RLS bado inafanya kazi, ufunguo usio sahihi unakataliwa, faili lililobadilishwa linagunduliwa | **11/11 PASS** |
| `npm run test:db`, Milestone F: malengo ya msingi, ushahidi, uthibitisho huru, kazi, attribution, commission na ledger, catalogue ya umma | **53/53 PASS** |
| `npm run test:db`, ruhusa: hakuna function/jedwali lililo wazi kwa asiyestahili; kila jedwali lina RLS | **9/9 PASS** |
| `npm run test:db`, Milestone G: import ya wateja na stoki, dry-run, kurudia, madeni ya mwanzo hayaingii kwenye mauzo/commission, ruhusa | **21/21 PASS** |
| Jaribio la mzigo (`LOAD_TEST=1`): wauzaji 8 × sekunde 20 | **8,369 mauzo, 0 yaliyoshindwa, ~19 ms kwa wastani, ~418 kwa sekunde; ledger 3/3 sawa** |
| axe-core + CSP (`npm run a11y`): login, activate, setup, catalogue ya umma | **0 makosa, 0 ukiukaji wa CSP** |
| `npm audit --omit=dev` | **0 vulnerabilities** |
| Select contract | **95/95 OK** |
| `npm test`: unit tests (PDF, QR inayosomwa tena, vipindi, contracts, siri, CSV ya MauzoTrack n.k.) | **166/166 PASS** |
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

**Mifano ya master prompt §7B/§10/§17 iliyothibitishwa kwenye Milestone D:**
- **Tuma 10, auze 6, arudishe 2:** zinabaki 2 kwa mbia.
- **Kutuma consignment hakuleti mauzo wala deni.**
- **Taarifa ya mbia inapunguza mzigo alionao tu**, haipunguzi tena Stoo.
- **Kurudia kutuma au kurudia taarifa hakubadilishi kitu.**
- Mzigo alionao mbia kwenye rekodi za kutuma unalingana na stoki ya eneo lake kwenye ledger.

**Hitilafu halisi zilizogunduliwa na majaribio ya Milestone F kisha kurekebishwa:**
- Ruhusa za functions zilizokuwa wazi (tazama sehemu ya usalama hapo juu).
- Policies za commission zilikuwa zinaitana kila moja (infinite recursion).
- Regex ya kiungo ilizidi kikomo cha PostgreSQL.

**Hitilafu halisi zilizogunduliwa na majaribio ya Milestone E kisha kurekebishwa:**
- Temp table ndani ya function ya `STABLE` (sasa inatumia CTE).
- `pg_dump` inaongeza `CREATE SCHEMA public`, kwa hiyo restore ilishindwa. Sasa kipengee hicho kinarukwa.
- Tarehe za kipindi cha "custom" zilikuwa zinabadilishwa nafasi baada ya kuwekewa ukomo wa leo.
- Jaribio la RPC contract halikukubali tarakimu kwenye majina ya parameters.

**Hitilafu halisi zilizogunduliwa na majaribio (Milestones A–D):**
- `count_decide` ilipitisha `bigint` kwa `_move(int)`.
- Majaribio mabaya ya code yalikuwa yanafutwa pamoja na rollback, hivyo hayakuhesabiwa.
- Trigger ya kukagua usawa wa journal ilifichwa na RLS (sasa ni `SECURITY DEFINER`).
- Script ya majaribio haikurudisha exit code ya kosa. Sasa inarudisha.
- Salio linaloendelea kwenye statement lilikuwa `numeric` badala ya `bigint` (sasa linabadilishwa ipasavyo).

## ⏳ Inasubiri uthibitisho kwenye Supabase halisi
Mazingira ya ujenzi hayawezi kuendesha Supabase Auth wala PostgREST: Docker images zimezuiwa, na ruhusa ya kujenga Auth ilikataliwa. Kwa hiyo haya hayajapimwa **end-to-end** kupitia skrini:
1. Kuingia kwa simu + nenosiri (nafasi 4), MFA, kuwezesha mfanyakazi, kubadili nenosiri, rate limiting.
2. Kurasa za Milestone B–D: Bidhaa, Stoo, Stoki ya Dukani, Manunuzi, POS, Mauzo, Wateja, Fedha, Idhini, Wateja wa Jumla.
   - Mantiki yote iliyo nyuma yake imepimwa kwenye database.
   - Wito wote wa `rpc()` na `select` umethibitishwa kulingana na schema.
   - Kilichobaki ni kubofya skrini kwenye mfumo halisi.
3. Barcode kwa scanner na printer halisi za dukani.
4. **Kazi ya kila siku iliyo hosted** (Vercel Cron + kupakia kwenye Supabase Storage), na **backup za Supabase Pro/PITR**. Ripoti na restore zimethibitishwa hapa tu, si kwenye mfumo halisi.

**Hatua inayofuata kwa Mmiliki:** fungua project ya bure ya Supabase (`docs/SETUP.md`). Kisha nitapima kila mtiririko kwenye skrini na kuandika hapa Pass/Fail.

## 🚧 Imezuiliwa
- **Logo rasmi ya DIROMA haijatolewa.**

## 📝 Maamuzi ya muda (yameandikwa wazi)
- **Gharama ya wastani:** COGS inatumia wastani wa manunuzi yote yaliyoidhinishwa (cumulative purchase-weighted) wakati wa mauzo. Stoki ya mwanzo haina gharama hadi Owner aiweke, kwa hiyo thamani ya stoki kwenye ledger inaweza kutofautiana kidogo na idadi × wastani. Ripoti ya kulinganisha hizo mbili itakuja Milestone E.
- **Droo ya pesa:** float ya kuanzia zamu haiingizwi kwenye ledger (ni pesa iliyokuwepo tayari). Tumia "salio la kuanzia" la akaunti ya droo ikiwa unataka salio la droo kwenye rekodi lilingane na pesa halisi.
- **Kufungua tena zamu iliyofungwa:** bado haijajengwa. Marekebisho yanafanywa kwa entry mpya, si kwa kufuta.
- **Uthibitisho wa M-Pesa:** malipo yote yamewekwa alama "manual" (yameingizwa kwa mkono). Kulinganisha na statement ya M-Pesa kutakuja na integrations.
- **Kodi (TRA/EFD) na mishahara:** hazijajengwa, na hazitabuniwa bila nyaraka rasmi.
- **Statements:** kwa sasa ni ukurasa unaochapishwa, au unahifadhiwa kama PDF kupitia browser. PDF zinazotengenezwa na server, na kutumwa kila siku, zinakuja Milestone E.
- **Portal ya mbia** (mbia kujiingia na kuona hesabu zake) na **ujumbe unaotumwa na mfumo** (WhatsApp/SMS API): bado. Vinahitaji provider na idhini ya gharama zake.
- **Saa za biashara:** Africa/Dar_es_Salaam (UTC+03:00, haina DST). Mipaka ya siku kwenye ripoti inafuata saa hizi.

## ⏭️ Inayofuata
Milestones A–G zimekamilika kwa kiwango kinachoweza kupimwa hapa. Kinachofuata kinamhitaji Mmiliki:
1. Kufungua Supabase + hosting (`docs/SETUP.md`, `docs/DEPLOY.md`), kisha kupitia `docs/ACCEPTANCE.md` kwenye mfumo halisi na vifaa halisi vya dukani.
2. Jaribio la usalama la mtaalamu huru kabla ya kuanza kutumia kweli.

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
| Login simu+nenosiri, MFA (Supabase Auth) | Implemented and tested end-to-end (Owner, staging) |
| Kuwezesha wafanyakazi (activation) | Implemented; not yet tested end-to-end |
| SMS recovery | Planned |
| Wateja wa Jumla / Consignment, statements, ukumbusho | Implemented and tested (DB + concurrency) |
| Kurasa za Wateja wa Jumla (UI) | Implemented, unverified end-to-end |
| Malengo, maudhui, kazi, wateja watarajiwa, commission | Implemented and tested (DB) |
| Catalogue ya umma + QR | Implemented and tested (DB + QR decode); page needs Supabase to run |
| Kurasa za Milestone F (UI) | Implemented, unverified end-to-end |
| Portal ya mbia, ujumbe wa mfumo | Planned |
| Ripoti 12 za vipindi, ulinganisho, CSV/PDF | Implemented and tested (DB + unit) |
| PDF ya kila siku (cron + storage) | Implemented; needs external configuration (CRON_SECRET, bucket, hosting) |
| Backup iliyosimbwa + restore inayothibitishwa | Implemented and tested (local PostgreSQL) |
| Backup za Supabase Pro / PITR / nakala ya storage | Needs external configuration + cost approval |
| CSP, security headers, kuzuia Auth kwa aliyesimamishwa | Implemented and tested (browser + unit); Auth ban needs Supabase |
| Kuhamia kutoka MauzoTrack (wateja, madeni, stoki ya mwanzo) | Implemented and tested (DB + unit); UI unverified end-to-end |
| Ufikivu (axe) | Tested on public/auth pages; app pages need Supabase |
| Vifaa halisi (simu, printer, scanner) | Not tested |
