import type { Lang } from "./i18n";

type Scope = { milestone: string; permission: string | null; sw: string[]; en: string[] };

/** Scope of modules not yet built (from the DIROMA master brief). Shown honestly as "Planned". */
export const PLANNED: Record<string, Scope> = {
  pos: { milestone: "C", permission: "pos.sell",
    sw: ["Bidhaa / Kikapu / Malipo kwenye desktop; hatua kwa hatua kwenye simu", "Lazima kuchagua rangi na saizi; bei ya variant halisi inathibitishwa", "Malipo kiasi, malipo mchanganyiko (cash + M-Pesa), punguzo linalodhibitiwa", "Risiti yenye namba ya kipekee; kuchapisha tena hakurekodi mauzo upya"],
    en: ["Desktop products/cart/checkout; staged flow on mobile", "Mandatory colour/size; the selected variant's price is validated", "Partial and split payments (cash + M-Pesa), controlled discounts", "Unique receipt numbers; reprints never re-post"] },
  products: { milestone: "B", permission: "products.view",
    sw: ["Design yenye code halisi (pamoja na #), picha, supplier", "Variants: rangi × saizi (42–60 suti, 39–46 viatu)", "Barcode bila bei, CSV import yenye preview na makosa kwa kila mstari"],
    en: ["Designs with original codes (incl. #), images, supplier", "Variants: colour × size (suits 42–60, shoes 39–46)", "Barcodes without prices; CSV import with preview and per-row errors"] },
  store: { milestone: "B", permission: "store.operate",
    sw: ["Muhtasari wa Stoo: zilizopo, zilizohifadhiwa, zinazopatikana, njiani, ukaguzi", "Kupokea mzigo kwa matrix ya saizi; mapungufu yanaonekana", "Maombi ya duka → kuidhinisha → kutuma → duka linathibitisha kupokea", "Kuhesabu stoo (blind count) na idhini huru; historia ya kila mzigo"],
    en: ["Store overview: on-hand, reserved, available, in transit, inspection", "Receive goods by size matrix; shortages stay visible", "Shop requisition → authorize → dispatch → shop confirms receipt", "Blind counts with independent approval; movement history"] },
  "shop-stock": { milestone: "B", permission: "shop_stock.view",
    sw: ["Stoki ya duka kwa design/rangi/saizi", "Kuthibitisha mzigo unaoingia kutoka Stoo", "Kuomba mzigo kutoka Stoo"],
    en: ["Shop availability by design/colour/size", "Confirm incoming receipts from the Store", "Request stock from the Store"] },
  wholesale: { milestone: "D", permission: "wholesale.manage",
    sw: ["Njia mbili: mauzo ya jumla ya moja kwa moja, na consignment", "Muhtasari wa kila mbia: aliyotumiwa, aliyouza, aliyorudisha, aliyonayo, deni halisi", "Malipo yanagawiwa kwa invoice; statements za PDF", "Ukumbusho kila siku 2 kwa wasiotoa taarifa (kwa idhini yao)"],
    en: ["Two modes: outright wholesale sale and consignment", "Per-partner: dispatched, sold, returned, still held, genuine debt", "Payment allocation to invoices; PDF statements", "Optional 2-day no-update reminders (consented channels only)"] },
  money: { milestone: "C", permission: "money.view",
    sw: ["Akaunti: cash ya kila duka, M-Pesa, benki", "Kuweka benki ni uhamisho, si mapato", "Kufunga zamu: kinachotarajiwa vs kilichohesabiwa, sababu, idhini ya meneja", "Matumizi yenye risiti na idhini"],
    en: ["Accounts: cash per shop, M-Pesa, bank", "Deposits are transfers, not revenue", "Shift closing: expected vs counted, reason, manager review", "Expenses with evidence and approval"] },
  customers: { milestone: "C", permission: "customers.view",
    sw: ["Wateja wa rejareja, jumla na consignment kwenye rekodi moja", "Masharti ya mkopo, umri wa madeni, statements"],
    en: ["Retail, wholesale and consignment relationships on one record", "Credit terms, debt ageing, statements"] },
  reports: { milestone: "E", permission: "reports.view",
    sw: ["Mauzo kwa tarehe ya mauzo, makusanyo kwa tarehe ya malipo", "Faida yenye alama ya ukamilifu wa gharama", "PDF ya kila siku saa 23:30 na backup inayojaribiwa kurejeshwa"],
    en: ["Sales by sale date, collections by payment date", "Profit with cost-completeness labels", "Daily 23:30 PDF and restore-tested backups"] },
  help: { milestone: "G", permission: null,
    sw: ["Miongozo mifupi kwa kila nafasi kwa Kiswahili", "Mawasiliano ya msaada yaliyowekwa na Mmiliki"],
    en: ["Short role-specific guides in Swahili and English", "Owner-configured support contact"] },
};

export function plannedScope(key: string, lang: Lang) {
  const s = PLANNED[key];
  return { milestone: s.milestone, permission: s.permission, scope: lang === "sw" ? s.sw : s.en };
}
