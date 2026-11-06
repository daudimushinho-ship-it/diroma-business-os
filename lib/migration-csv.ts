import Papa from "papaparse";
import { normalizePhone } from "./phone";

export type Checked<T> = { line: number; row: T; errors: string[] };
export type CustomerRow = { name: string; phone: string | null; kind: "retail" | "wholesale"; credit_limit: number | null; terms_days: number | null;
  region: string | null; source: string | null; opening_balance: number | null };
export type StockRow = { design_code: string; color: string; size: string; location_code: string; qty: number };

// Accept common export headings (English / Swahili) so a MauzoTrack or spreadsheet export needs little editing.
const ALIASES: Record<string, string[]> = {
  name: ["name", "customer", "customer name", "jina", "mteja"], phone: ["phone", "phone number", "simu", "namba ya simu", "mobile"],
  kind: ["kind", "type", "aina"], credit_limit: ["credit_limit", "limit", "credit limit", "kikomo"], terms_days: ["terms_days", "terms", "credit days", "siku"],
  region: ["region", "mkoa", "location"], source: ["source", "chanzo"], opening_balance: ["opening_balance", "owed", "debt", "balance", "deni", "owes", "owed to you"],
  design_code: ["design_code", "code", "product code", "sku code"], color: ["color", "colour", "rangi"], size: ["size", "saizi"],
  location_code: ["location_code", "location", "shop", "branch", "eneo"], qty: ["qty", "quantity", "stock", "idadi", "on hand"],
};
function header(h: string): string {
  const k = h.trim().toLowerCase();
  for (const [canon, al] of Object.entries(ALIASES)) if (al.includes(k)) return canon;
  return k;
}
function num(v: unknown, errors: string[], label: string): number | null {
  const s = String(v ?? "").replace(/[,\s]/g, "").replace(/^TZS/i, "");
  if (!s) return null;
  const n = Number(s);
  if (!Number.isInteger(n) || n < 0) { errors.push(`${label} must be a whole number ≥ 0`); return null; }
  return n;
}
function parse(text: string) {
  return Papa.parse<Record<string, string>>(text.replace(/^﻿/, ""), { header: true, skipEmptyLines: "greedy", transformHeader: header });
}

export function parseCustomers(text: string): { rows: Checked<CustomerRow>[]; fatal?: string } {
  const p = parse(text);
  if (!(p.meta.fields ?? []).includes("name")) return { rows: [], fatal: "Missing column: name" };
  if (p.data.length > 5000) return { rows: [], fatal: "Too many rows (max 5000)" };
  const seen = new Map<string, number>();
  return { rows: p.data.map((r, i) => {
    const errors: string[] = [];
    let phone: string | null = null;
    if ((r.phone ?? "").trim()) { const n = normalizePhone(r.phone); if (n.ok) phone = n.e164; else errors.push("phone is not valid"); }
    const kindRaw = (r.kind ?? "").trim().toLowerCase();
    const kind = kindRaw === "" || kindRaw === "retail" || kindRaw === "rejareja" ? "retail" : kindRaw === "wholesale" || kindRaw === "jumla" ? "wholesale" : null;
    if (!kind) errors.push("kind must be retail/wholesale");
    const row: CustomerRow = { name: (r.name ?? "").trim(), phone, kind: kind ?? "retail", credit_limit: num(r.credit_limit, errors, "credit_limit"),
      terms_days: num(r.terms_days, errors, "terms_days"), region: (r.region ?? "").trim() || null, source: (r.source ?? "").trim() || null,
      opening_balance: num(r.opening_balance, errors, "opening_balance") };
    if (row.name.length < 2) errors.push("name is required");
    if (phone) { if (seen.has(phone)) errors.push(`same phone as line ${seen.get(phone)}`); else seen.set(phone, i + 2); }
    return { line: i + 2, row, errors };
  }) };
}

export function parseStock(text: string): { rows: Checked<StockRow>[]; fatal?: string } {
  const p = parse(text);
  const missing = ["design_code", "color", "size", "location_code", "qty"].filter((c) => !(p.meta.fields ?? []).includes(c));
  if (missing.length) return { rows: [], fatal: `Missing column(s): ${missing.join(", ")}` };
  return { rows: p.data.map((r, i) => {
    const errors: string[] = [];
    const qty = num(r.qty, errors, "qty") ?? 0;
    if (qty <= 0) errors.push("qty must be positive");
    const row: StockRow = { design_code: (r.design_code ?? "").trim(), color: (r.color ?? "").trim(), size: (r.size ?? "").trim().toUpperCase(),
      location_code: (r.location_code ?? "").trim().toUpperCase(), qty };
    for (const k of ["design_code", "color", "size", "location_code"] as const) if (!row[k]) errors.push(`${k} is required`);
    return { line: i + 2, row, errors };
  }) };
}
