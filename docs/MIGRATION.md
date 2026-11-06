# Kuhamisha data kutoka MauzoTrack / Migrating from MauzoTrack

## Mpango (siku ya kuhamia)
1. **Siku 3 kabla:** fanya mazoezi kwenye mfumo wa majaribio (staging) kwa nakala ya data. Linganisha jumla, kisha rekebisha CSV.
2. **Saa ya kukata (cut-off), mfano Jumapili saa 3 usiku:**
   - Acha kurekodi mauzo kwenye MauzoTrack.
   - Funga zamu zote.
   - Hesabu stoki halisi (Stoo na Duka).
3. **Pakua kutoka MauzoTrack:** bidhaa (Export Products), wateja (Download all) na madeni yao. Mauzo ya zamani yanabaki MauzoTrack kama kumbukumbu; hayaingizwi kama mauzo mapya.
4. **Ingiza DIROMA** (Mipangilio → MauzoTrack → DIROMA):
   1. **Bidhaa:** Bidhaa → Import CSV (design_code, design_name, category, color, size, retail_price, wholesale_price).
   2. **Wateja na madeni ya mwanzo**, kwa tarehe ya kukata. Madeni yanaingia kama "salio la mwanzo", **si mauzo**.
   3. **Stoki ya mwanzo** kutoka kwenye hesabu halisi (design_code, color, size, location_code, qty).
   4. **Pesa:** Fedha → Akaunti → salio la kuanzia kwa kila droo, M-Pesa na benki (kutoka statement).
   5. **Gharama za stoki:** idhinisha gharama, au weka gharama za manunuzi. Bila gharama, faida itaonyeshwa kama "haijakamilika".
5. **Linganisha kabla ya kufungua:**
   - Jumla ya madeni (Ripoti → Umri wa madeni) = jumla ya MauzoTrack.
   - Stoki (Ripoti → Stoki) = hesabu halisi.
   - Pesa = statements.
6. **Fungua.** Kuanzia sasa, mauzo yote yanarekodiwa DIROMA pekee.

## Sheria za kuingiza (kila faili)
- **Hakiki kwanza.** Makosa yanaonyeshwa kwa kila mstari, na faili lenye kosa hata moja linakataliwa lote (all-or-nothing).
- Kuingiza faili lilelile mara mbili hakubadilishi kitu (import id).
- **Simu iliyopo tayari:** chagua "error" (default), au "update" ili kusasisha maelezo. Salio la mwanzo linaingia **mara moja tu** kwa kila mteja.
- Vichwa vya safu (headers) vinavyokubalika kutoka exports nyingi: `Customer`, `Phone`, `Owed to you`, `Type`, `Jina`, `Simu`, `Deni`, n.k.
- Kila uingizaji unarekodiwa kwenye `data_imports` na kwenye audit log.

## Ushahidi wa mazoezi
`tests/db/70_migration_test.sql` (majaribio 21) inathibitisha:
- Faili lenye kosa moja haliingizi chochote.
- Madeni ya mwanzo yanaingia kwenye ledger kama deni dhidi ya "opening equity", si kama mapato.
- Madeni hayo hayaonekani kwenye ripoti ya mauzo, lakini yanaonekana kwenye umri wa madeni.
- Malipo ya kwanza yanalipa deni la mwanzo kwanza (FIFO), na yanahesabiwa kama "madeni ya zamani".
- Stoki ya mwanzo inaingia kama hati moja kwa kila eneo.
- Muuzaji hawezi kuingiza data hizi.
