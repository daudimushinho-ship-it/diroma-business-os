"use server";
import { requireWorkspace } from "@/lib/workspace";
import { categories, db } from "@/lib/stock";
import { parseCatalogueCsv, type RowCheck } from "@/lib/csv-import";

export type ImportState =
  | { stage: "preview"; rows: RowCheck[]; importId: string; mode: string; fatal?: string }
  | { stage: "done"; result: Record<string, unknown> }
  | { stage: "error"; message: string; rows?: RowCheck[]; importId?: string; mode?: string }
  | undefined;

export async function importCatalogue(prev: ImportState, fd: FormData): Promise<ImportState> {
  await requireWorkspace("products.manage");
  const intent = String(fd.get("intent") ?? "preview");
  const mode = String(fd.get("mode") ?? "create_only") === "update_prices" ? "update_prices" : "create_only";

  if (intent === "commit" && prev && "rows" in prev && prev.rows && prev.importId) {
    if (prev.rows.some((r) => r.errors.length)) return { ...prev, stage: "error", message: "Fix the errors first" } as ImportState;
    const supabase = await db();
    const { data, error } = await supabase.rpc("catalogue_import", {
      p_import: prev.importId, p_rows: prev.rows.map((r) => r.row), p_mode: prev.mode ?? mode,
    });
    if (error) return { stage: "error", message: error.message, rows: prev.rows, importId: prev.importId, mode: prev.mode };
    return { stage: "done", result: data as Record<string, unknown> };
  }

  const file = fd.get("file");
  let text = String(fd.get("csv") ?? "");
  if (file instanceof File && file.size > 0) {
    if (file.size > 2_000_000) return { stage: "error", message: "File too large (max 2 MB)" };
    text = await file.text();
  }
  if (!text.trim()) return { stage: "error", message: "No CSV provided" };
  const { cats, sizes } = await categories();
  const validCats = new Set(cats.map((c) => c.code));
  const bySet = new Map<string, Set<string>>();
  for (const z of sizes) bySet.set(z.size_set, (bySet.get(z.size_set) ?? new Set()).add(z.size));
  const validSizes = new Map(cats.map((c) => [c.code, bySet.get(c.size_set) ?? new Set<string>()]));
  const { rows, fatal } = parseCatalogueCsv(text, validCats, validSizes);
  return { stage: "preview", rows, fatal, importId: crypto.randomUUID(), mode };
}
