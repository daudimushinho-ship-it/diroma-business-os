"use server";
import { requireWorkspace } from "@/lib/workspace";
import { db } from "@/lib/stock";
import { parseCustomers, parseStock, type Checked } from "@/lib/migration-csv";

export type MigState =
  | { stage: "preview"; kind: "customers" | "stock"; rows: Checked<Record<string, unknown>>[]; importId: string; fatal?: string; asOf?: string; location?: string; mode?: string; reason?: string }
  | { stage: "done"; result: Record<string, unknown> }
  | { stage: "error"; message: string }
  | undefined;

async function readCsv(fd: FormData): Promise<string> {
  const file = fd.get("file");
  if (file instanceof File && file.size > 0) {
    if (file.size > 3_000_000) throw new Error("File too large (max 3 MB)");
    return await file.text();
  }
  return String(fd.get("csv") ?? "");
}

export async function migrate(prev: MigState, fd: FormData): Promise<MigState> {
  const kind = String(fd.get("kind")) === "stock" ? "stock" : "customers";
  await requireWorkspace(kind === "stock" ? "stock.opening" : "settings.manage");
  if (String(fd.get("intent")) === "commit" && prev?.stage === "preview") {
    if (prev.rows.some((r) => r.errors.length)) return { stage: "error", message: "Fix the errors first" };
    const supabase = await db();
    const rows = prev.rows.map((r) => r.row);
    const { data, error } = prev.kind === "customers"
      ? await supabase.rpc("customer_import", { p_import: prev.importId, p_rows: rows, p_mode: prev.mode ?? "create_only", p_as_of: prev.asOf ?? null, p_location: prev.location || null })
      : await supabase.rpc("opening_stock_import", { p_import: prev.importId, p_rows: rows, p_reason: prev.reason ?? "" });
    if (error) return { stage: "error", message: error.message };
    return { stage: "done", result: data as Record<string, unknown> };
  }
  try {
    const text = await readCsv(fd);
    if (!text.trim()) return { stage: "error", message: "No CSV provided" };
    const parsed = kind === "stock" ? parseStock(text) : parseCustomers(text);
    return { stage: "preview", kind, rows: parsed.rows as Checked<Record<string, unknown>>[], fatal: parsed.fatal, importId: crypto.randomUUID(),
      asOf: String(fd.get("as_of") ?? ""), location: String(fd.get("location") ?? ""), mode: String(fd.get("mode") ?? "create_only"), reason: String(fd.get("reason") ?? "") };
  } catch (e) {
    return { stage: "error", message: e instanceof Error ? e.message : "Could not read file" };
  }
}
