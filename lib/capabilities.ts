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
  { key: "catalogue",   sw: "Bidhaa, rangi × saizi, bei, CSV import", en: "Catalogue, colour × size variants, prices, CSV import", state: "implemented", milestone: "B" },
  { key: "barcodes",    sw: "Barcode (Code 128) na lebo bila bei", en: "Code 128 barcodes and price-free labels", state: "implemented", milestone: "B" },
  { key: "ledger",      sw: "Stock ledger moja (Stoo, Duka, Njiani), bila stoki hasi", en: "Single stock ledger (Store, Shop, Transit), no negative stock", state: "implemented", milestone: "B" },
  { key: "store",       sw: "Paneli ya Stoo: kupokea, maombi, kutuma, kuthibitisha, mapungufu", en: "Store panel: receive, requisitions, dispatch, confirm, discrepancies", state: "implemented", milestone: "B" },
  { key: "counts",      sw: "Kuhesabu stoo bila kuona mfumo, idhini huru", en: "Blind counts with independent approval", state: "implemented", milestone: "B" },
  { key: "purchasing",  sw: "Suppliers, PO, gharama za ziada (landed cost)", en: "Suppliers, POs, landed-cost approval", state: "implemented", milestone: "B" },
  { key: "stockui",     sw: "Kurasa za Bidhaa/Stoo/Duka/Manunuzi (end-to-end na Supabase)", en: "Products/Store/Shop/Purchasing screens (end-to-end with Supabase)", state: "unverified", milestone: "B" },
  { key: "pos",         sw: "POS: saizi lazima, bei ya server, punguzo kwa idhini, malipo mchanganyiko", en: "POS: mandatory size, server pricing, approved discounts, split payments", state: "implemented", milestone: "C" },
  { key: "credit",      sw: "Mkopo, makusanyo (FIFO), salio la mteja", en: "Credit sales, FIFO collections, customer credit", state: "implemented", milestone: "C" },
  { key: "returns",     sw: "Marejesho → ukaguzi → rudisha pesa / salio", en: "Returns → inspection → refund / credit", state: "implemented", milestone: "C" },
  { key: "moneyc",      sw: "Akaunti za pesa, kuweka benki, matumizi, posho za usafirishaji", en: "Money accounts, deposits, expenses, runner advances", state: "implemented", milestone: "C" },
  { key: "closing",     sw: "Kufunga zamu na ukaguzi huru wa tofauti", en: "Shift closing with independent variance review", state: "implemented", milestone: "C" },
  { key: "journal",     sw: "Ledger ya double-entry, COGS kwa gharama ya wastani", en: "Double-entry journal, COGS at average cost", state: "implemented", milestone: "C" },
  { key: "salesui",     sw: "Kurasa za POS/Mauzo/Wateja/Fedha/Idhini (end-to-end na Supabase)", en: "POS/Sales/Customers/Money/Approvals screens (end-to-end with Supabase)", state: "unverified", milestone: "C" },
  { key: "wholesale",   sw: "Wateja wa Jumla: consignment (tuma, ripoti, rudisha, upotevu), mauzo ya jumla, statements", en: "Wholesale: consignment (dispatch, report, return, loss), outright sales, statements", state: "implemented", milestone: "D" },
  { key: "reminders",   sw: "Ukumbusho wa taarifa (kiungo cha WhatsApp + kumbukumbu)", en: "Update reminders (WhatsApp link + log)", state: "implemented", milestone: "D" },
  { key: "wholesaleui", sw: "Kurasa za Wateja wa Jumla (end-to-end na Supabase)", en: "Wholesale screens (end-to-end with Supabase)", state: "unverified", milestone: "D" },
  { key: "portal",      sw: "Portal ya mbia na ujumbe unaotumwa na mfumo", en: "Partner portal and system-sent messages", state: "planned", milestone: "F" },
  { key: "reports",     sw: "Ripoti kamili, PDF za kila siku, backup", en: "Full reports, daily PDFs, backups", state: "planned", milestone: "E" },
  { key: "team",        sw: "Malengo ya timu, commission", en: "Team targets, commissions", state: "planned", milestone: "F" },
];
