export type CapState = "implemented" | "unverified" | "external" | "planned";

export type Capability = { key: string; sw: string; en: string; state: CapState; milestone: string };

/** Living capability matrix shown in the app and mirrored in docs/PROGRESS.md. Keep honest. */
export const CAPABILITIES: Capability[] = [
  { key: "schema",      sw: "Database: biashara, maeneo, wafanyakazi, ruhusa", en: "Database: business, locations, memberships, permissions", state: "implemented", milestone: "A" },
  { key: "rls",         sw: "Ruhusa kwenye database (RLS) na kuzuia uandishi wa moja kwa moja", en: "Database permissions (RLS) and blocked direct writes", state: "implemented", milestone: "A" },
  { key: "audit",       sw: "Audit log isiyobadilika", en: "Append-only audit log", state: "implemented", milestone: "A" },
  { key: "phone",       sw: "Kusawazisha namba za simu (0712… = +255712…)", en: "Phone normalization (0712… = +255712…)", state: "implemented", milestone: "A" },
  { key: "login",       sw: "Kuingia kwa simu + nenosiri (Supabase Auth)", en: "Phone + password sign-in (Supabase Auth)", state: "external", milestone: "A" },
  { key: "mfa",         sw: "MFA (TOTP) kwa Mmiliki na Meneja", en: "MFA (TOTP) for Owner and Manager", state: "external", milestone: "A" },
  { key: "activation",  sw: "Kuwezesha mfanyakazi kwa code ya mara moja", en: "Staff activation with one-time code", state: "external", milestone: "A" },
  { key: "workspaces",  sw: "Kurasa za kila nafasi (Owner/Meneja/Muuzaji/Stoo)", en: "Role workspaces and routing", state: "unverified", milestone: "A" },
  { key: "sms",         sw: "Kurejesha nenosiri kwa SMS", en: "SMS password recovery", state: "planned", milestone: "A+" },
  { key: "catalogue",   sw: "Bidhaa, rangi/saizi, barcode, CSV", en: "Catalogue, colour/size variants, barcodes, CSV", state: "planned", milestone: "B" },
  { key: "store",       sw: "Stoo: kupokea, maombi ya duka, kutuma, kuhesabu", en: "Store/Stoo: receive, requisitions, dispatch, counts", state: "planned", milestone: "B" },
  { key: "purchasing",  sw: "Manunuzi na landed cost", en: "Purchasing and landed cost", state: "planned", milestone: "B" },
  { key: "pos",         sw: "POS, malipo, matumizi, marejesho", en: "POS, payments, expenses, returns", state: "planned", milestone: "C" },
  { key: "closing",     sw: "Kufunga zamu (shift) na tofauti za pesa", en: "Shift closing and cash variance", state: "planned", milestone: "C" },
  { key: "wholesale",   sw: "Wateja wa Jumla na consignment", en: "Wholesale customers and consignment", state: "planned", milestone: "D" },
  { key: "reports",     sw: "Ripoti kamili, PDF za kila siku, backup", en: "Full reports, daily PDFs, backups", state: "planned", milestone: "E" },
  { key: "team",        sw: "Malengo ya timu, commission", en: "Team targets, commissions", state: "planned", milestone: "F" },
];
