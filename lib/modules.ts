import type { Lang } from "./i18n";

type Scope = { milestone: string; permission: string | null; sw: string[]; en: string[] };

/** Scope of modules not yet built (from the DIROMA master brief). Shown honestly as "Planned". */
export const PLANNED: Record<string, Scope> = {
  wholesale: { milestone: "D", permission: "wholesale.manage",
    sw: ["Njia mbili: mauzo ya jumla ya moja kwa moja, na consignment", "Muhtasari wa kila mbia: aliyotumiwa, aliyouza, aliyorudisha, aliyonayo, deni halisi", "Malipo yanagawiwa kwa invoice; statements za PDF", "Ukumbusho kila siku 2 kwa wasiotoa taarifa (kwa idhini yao)"],
    en: ["Two modes: outright wholesale sale and consignment", "Per-partner: dispatched, sold, returned, still held, genuine debt", "Payment allocation to invoices; PDF statements", "Optional 2-day no-update reminders (consented channels only)"] },
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
