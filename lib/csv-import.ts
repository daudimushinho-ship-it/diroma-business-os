import Papa from "papaparse";

export const IMPORT_COLUMNS = ["design_code", "design_name", "category", "color", "size", "retail_price", "wholesale_price", "barcode", "supplier"] as const;

export type ImportRow = {
  design_code: string; design_name: string | null; category: string | null; color: string; size: string;
  retail_price: number | null; wholesale_price: number | null; barcode: string | null; supplier: string | null;
};
export type RowCheck = { line: number; row: ImportRow; errors: string[] };

function price(v: string | undefined, errors: string[], label: string): number | null {
  const raw = (v ?? "").replace(/[,\s]/g, "").replace(/^TZS/i, "");
  if (!raw) return null;
  const n = Number(raw);
  if (!Number.isInteger(n) || n <= 0) { errors.push(`${label} must be a whole positive TZS amount`); return null; }
  return n;
}

/**
 * Parse and validate a catalogue CSV. Validation here is for the preview only;
 * the database re-validates everything inside one all-or-nothing transaction.
 */
export function parseCatalogueCsv(text: string, validCategories: Set<string>, validSizes: Map<string, Set<string>>, maxRows = 2000): {
  rows: RowCheck[]; fatal?: string;
} {
  const parsed = Papa.parse<Record<string, string>>(text.replace(/^﻿/, ""), { header: true, skipEmptyLines: "greedy", transformHeader: (h) => h.trim().toLowerCase() });
  const fields = parsed.meta.fields ?? [];
  const missing = ["design_code", "color", "size"].filter((c) => !fields.includes(c));
  if (missing.length) return { rows: [], fatal: `Missing column(s): ${missing.join(", ")}` };
  if (parsed.data.length > maxRows) return { rows: [], fatal: `Too many rows (max ${maxRows})` };
  const seen = new Map<string, number>();
  const rows = parsed.data.map((r, i): RowCheck => {
    const errors: string[] = [];
    const row: ImportRow = {
      design_code: (r.design_code ?? "").trim(),
      design_name: (r.design_name ?? "").trim() || null,
      category: (r.category ?? "").trim().toLowerCase() || null,
      color: (r.color ?? "").trim(),
      size: (r.size ?? "").trim().toUpperCase(),
      retail_price: price(r.retail_price, errors, "retail_price"),
      wholesale_price: price(r.wholesale_price, errors, "wholesale_price"),
      barcode: (r.barcode ?? "").trim().toUpperCase() || null,
      supplier: (r.supplier ?? "").trim() || null,
    };
    if (!row.design_code) errors.push("design_code is required");
    if (!row.color) errors.push("color is required");
    if (!row.size) errors.push("size is required");
    if (row.category && !validCategories.has(row.category)) errors.push(`unknown category "${row.category}"`);
    if (row.category && row.size && validCategories.has(row.category) && !validSizes.get(row.category)?.has(row.size)) {
      errors.push(`size ${row.size} not configured for ${row.category}`);
    }
    if (row.barcode && !/^[0-9A-Z-]{4,32}$/.test(row.barcode)) errors.push("barcode may only contain 0-9, A-Z and -");
    const key = `${row.design_code}|${row.color.toLowerCase()}|${row.size}`;
    if (seen.has(key)) errors.push(`duplicate of line ${seen.get(key)}`);
    else seen.set(key, i + 2);
    return { line: i + 2, row, errors };
  });
  return { rows };
}
