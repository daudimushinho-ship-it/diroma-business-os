import "server-only";
import { createClient } from "./supabase/server";
import { sizeSort } from "./format";

export type Variant = {
  id: string; design_id: string; color: string; size: string; sku: string; barcode: string;
  retail_price: number | null; wholesale_price: number | null; is_active: boolean;
};
export type Design = { id: string; code: string; name: string; category: string; supplier_id: string | null; description: string | null };

export async function db() {
  const c = await createClient();
  if (!c) throw new Error("Supabase is not configured");
  return c;
}

export async function listDesigns(q?: string) {
  const supabase = await db();
  let query = supabase.from("v_catalogue").select("design_id, code, name, category, variant_count, retail_from, retail_to, unpriced_variants, colors").eq("is_active", true).order("code");
  if (q) query = query.or(`code.ilike.%${q.replace(/[%,()]/g, "")}%,name.ilike.%${q.replace(/[%,()]/g, "")}%`);
  const { data } = await query.limit(500);
  return data ?? [];
}

export async function getDesign(id: string) {
  const supabase = await db();
  const [{ data: design }, { data: variants }] = await Promise.all([
    supabase.from("designs").select("id, code, name, category, supplier_id, description").eq("id", id).maybeSingle(),
    supabase.from("variants").select("id, design_id, color, size, sku, barcode, retail_price, wholesale_price, is_active").eq("design_id", id),
  ]);
  return { design: design as Design | null, variants: sortVariants((variants ?? []) as Variant[]) };
}

export function sortVariants<T extends { color: string; size: string }>(v: T[]): T[] {
  return [...v].sort((a, b) => a.color.localeCompare(b.color) || sizeSort(a.size, b.size));
}

export function matrixAxes(variants: { color: string; size: string }[]) {
  const colors = [...new Set(variants.map((v) => v.color))].sort();
  const sizes = [...new Set(variants.map((v) => v.size))].sort(sizeSort);
  return { colors, sizes };
}

export async function categories() {
  const supabase = await db();
  const [{ data: cats }, { data: sizes }] = await Promise.all([
    supabase.from("categories").select("code, name_en, name_sw, size_set").order("code"),
    supabase.from("size_set_sizes").select("size_set, size, sort").order("sort"),
  ]);
  return { cats: cats ?? [], sizes: sizes ?? [] };
}

/** Collect `q_<variantId>` positive integers from a form. */
export function readQtyFields(fd: FormData, prefix = "q_"): { variant_id: string; qty: number }[] {
  const out: { variant_id: string; qty: number }[] = [];
  for (const [k, v] of fd.entries()) {
    if (!k.startsWith(prefix)) continue;
    const n = Number(String(v).trim() || "0");
    if (Number.isInteger(n) && n > 0) out.push({ variant_id: k.slice(prefix.length), qty: n });
  }
  return out;
}

/** Pick the active location from ?loc= among the user's locations of the given kinds. */
export function pickLocation<T extends { id: string; kind: string }>(locs: T[], kinds: string[], requested?: string): T | null {
  const allowed = locs.filter((l) => kinds.includes(l.kind));
  return allowed.find((l) => l.id === requested) ?? allowed[0] ?? null;
}

export async function locationDirectory() {
  const supabase = await db();
  const { data } = await supabase.rpc("location_directory");
  return new Map(((data ?? []) as { id: string; code: string; name: string; kind: string }[]).map((l) => [l.id, l]));
}

export type VariantLabel = { code: string; name: string; color: string; size: string; barcode: string };

export async function variantLabels(ids: string[]): Promise<Map<string, VariantLabel>> {
  const unique = [...new Set(ids)].filter(Boolean);
  if (!unique.length) return new Map();
  const supabase = await db();
  const { data } = await supabase.from("variants").select("id, color, size, barcode, designs(code, name)").in("id", unique);
  const out = new Map<string, VariantLabel>();
  for (const v of (data ?? []) as unknown as { id: string; color: string; size: string; barcode: string; designs: { code: string; name: string } }[]) {
    out.set(v.id, { code: v.designs.code, name: v.designs.name, color: v.color, size: v.size, barcode: v.barcode });
  }
  return out;
}

export function variantText(l?: VariantLabel): string {
  return l ? `${l.code} · ${l.color} · ${l.size}` : "—";
}
