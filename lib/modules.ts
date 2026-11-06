import type { Lang } from "./i18n";

type Scope = { milestone: string; permission: string | null; sw: string[]; en: string[] };

/** Scope of modules not yet built (from the DIROMA master brief). Shown honestly as "Planned". */
export const PLANNED: Record<string, Scope> = {
  help: { milestone: "G", permission: null,
    sw: ["Miongozo mifupi kwa kila nafasi kwa Kiswahili", "Mawasiliano ya msaada yaliyowekwa na Mmiliki"],
    en: ["Short role-specific guides in Swahili and English", "Owner-configured support contact"] },
};

export function plannedScope(key: string, lang: Lang) {
  const s = PLANNED[key];
  return { milestone: s.milestone, permission: s.permission, scope: lang === "sw" ? s.sw : s.en };
}
