# Makabidhiano / Handover — DIROMA Business OS

_9 Novemba 2026. Majibu ya maswali ya Mmiliki (master prompt §19F)._

**1. Ninaingia wapi?**
Kwenye anwani ya app itakayowekwa wakati wa kuweka mfumo mtandaoni (deployment, angalia `DEPLOY.md`), ukurasa wa `/login`. Unaingia kwa namba ya simu, nenosiri, kisha MFA.
**Bado haijawekwa mtandaoni:** Supabase na hosting havijasanidiwa.

**2. Ninaongezaje, kuzuia au kuondoa mfanyakazi?**
**Timu → Alika mfanyakazi** (code ya mara moja, ana kwa ana). Kuzuia ni **⋯ → Simamisha**, na kuondoa ni **Ondoa**. Vyote vinaanza kufanya kazi papo hapo. Angalia `guides/mmiliki.md`.

**3. Ninarekodije mauzo, kupokea na kuhamisha mzigo, na kufuatilia wabia wa jumla?**
- Mauzo: **Uza (POS)**.
- Kupokea na kutuma mzigo: **Stoo**.
- Kuthibitisha mzigo uliofika dukani: **Stoki ya Dukani**.
- Wabia wa jumla: **Wateja wa Jumla**.
Kila nafasi ina mwongozo wake ndani ya `docs/guides/`.

**4. Ninaona wapi pesa, ripoti na tofauti za pesa?**
- **Muhtasari wa Biashara:** kila siku.
- **Ripoti:** ripoti 12, zinazoweza kupakuliwa kama CSV au PDF.
- **Fedha:** akaunti na journal.
- **Idhini:** zamu zenye tofauti ya pesa.
- **Kituo cha Udhibiti:** audit log.

**5. Nitajuaje backup imefanikiwa, na nani anaweza kuirejesha?**
Kituo cha Udhibiti kinaonyesha "Backup ya mwisho" na "Jaribio la kurejesha". Mtu wa ufundi mwenye ruhusa ndiye anayerejesha, kwa kufuata `RECOVERY.md`. Ufunguo wa backup unakaa kwako na kwenye sefu.
**Bado:** backup ya mfumo halisi haijaanza, kwa sababu inahitaji Supabase.

**6. Ninalipa nini, lini, na kwa nani?**
Gharama ni:
- Supabase (database);
- hosting;
- hifadhi ya backup;
- kwa hiari: SMS, WhatsApp API, domain.
Bei halisi chukua kwenye kurasa za bei za kila mtoa huduma kabla ya kuidhinisha. Sijabuni jumla. Angalia `DEPLOY.md` §6.

**7. Nifanye nini app au mtandao ukikosekana?**
- **Andika mauzo kwenye daftari:** risiti, saa, bidhaa, saizi na malipo.
- Mtandao ukirudi, yaingize kama **"mauzo yaliyosahaulika"** kwenye POS. Meneja ataidhinisha tarehe ya nyuma.
- App ikiharibika baada ya mabadiliko mapya, inarudishwa kwenye toleo lililopita (`DEPLOY.md` §5).
- POS haifanyi kazi bila mtandao kwa makusudi: mauzo ya wakati huo hayawezi kulindwa dhidi ya kuuza kitu kimoja mara mbili.

**8. Nani anamiliki source code, data na akaunti?**
DIROMA, yaani wewe. Repo ya GitHub, Supabase, Vercel na domain ziwe chini ya akaunti zako. Watengenezaji wanapewa ruhusa unayoweza kuiondoa wakati wowote.
**Kwa sasa:** code iko kwenye branch `claude/vibrant-turing-2hlcsn`, ndani ya repo `daudimushinho-ship-it/diroma-business-os`. Push imezuiwa (403) hadi GitHub iunganishwe upya.

**9. Nini bado hakijakamilika au hakijathibitishwa?**
- **Kuingia, MFA na kuwezesha wafanyakazi** kupitia Supabase Auth halisi: hakijapimwa.
- **Kurasa zote** hazijapimwa end-to-end kwenye mfumo halisi. Mantiki yote imepimwa kwenye database (majaribio 400+), na POS imepimwa kwenye browser kwa data za majaribio.
- **Kazi ya kila siku iliyowekwa mtandaoni** (Vercel Cron + storage), **backup za Supabase Pro/PITR** na **kurejesha data kwenye mfumo halisi:** havijapimwa.
- **Vifaa halisi:** simu za duka, printer ya risiti na scanner havijapimwa.
- **Havipo:** SMS, WhatsApp API, M-Pesa API, TRA/EFD, mishahara, na portal ya mbia.
- **Kabla ya kuanza kutumika kweli:** jaribio la usalama (penetration test) kutoka kwa mtaalamu huru linapendekezwa.
- **Logo rasmi ya DIROMA** bado haijawekwa.

## Nyaraka
| Hati | Ina nini |
|---|---|
| `PROGRESS.md` | Kilichojengwa na ushahidi wake |
| `ACCEPTANCE.md` | Mazoezi ya kukubali mfumo (Pass / Not tested) |
| `SECURITY.md` | Ramani ya OWASP ASVS |
| `SETUP.md`, `DEPLOY.md` | Kusanidi, kuweka mtandaoni, gharama na matengenezo |
| `RECOVERY.md` | Backup na kurejesha |
| `MIGRATION.md` | Kuhamia kutoka MauzoTrack |
| `guides/` | Miongozo ya Mmiliki, Meneja, Muuzaji na Mtunza Stoo |
