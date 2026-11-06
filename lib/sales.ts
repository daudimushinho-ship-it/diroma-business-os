import "server-only";
import { db } from "./stock";

export type Shift = { id: string; ref_no: string; location_id: string; cash_account_id: string; opened_at: string; opening_float: number;
  sales_count: number; sales_total: number; by_method: Record<string, number> };

export async function myShift(): Promise<Shift | null> {
  const supabase = await db();
  const { data } = await supabase.rpc("my_shift");
  return (data as Shift | null) ?? null;
}

export type PosItem = { variant_id: string; design_id: string; code: string; name: string; color: string; size: string; barcode: string;
  retail_price: number | null; wholesale_price: number | null; available: number };

/** Sellable catalogue for one shop: every variant with stock there, with selling prices only. */
export async function posCatalogue(locationId: string): Promise<PosItem[]> {
  const supabase = await db();
  const { data: stock } = await supabase.from("v_stock").select("variant_id, available").eq("location_id", locationId).gt("available", 0).limit(5000);
  const ids = (stock ?? []).map((r) => r.variant_id);
  if (!ids.length) return [];
  const { data: vars } = await supabase.from("variants").select("id, design_id, color, size, barcode, retail_price, wholesale_price, designs(code, name)").in("id", ids);
  const avail = new Map((stock ?? []).map((r) => [r.variant_id, r.available as number]));
  return ((vars ?? []) as unknown as { id: string; design_id: string; color: string; size: string; barcode: string; retail_price: number | null;
    wholesale_price: number | null; designs: { code: string; name: string } }[]).map((v) => ({
    variant_id: v.id, design_id: v.design_id, code: v.designs.code, name: v.designs.name, color: v.color, size: v.size, barcode: v.barcode,
    retail_price: v.retail_price, wholesale_price: v.wholesale_price, available: avail.get(v.id) ?? 0,
  }));
}

export async function moneyAccounts() {
  const supabase = await db();
  const { data } = await supabase.from("money_accounts").select("id, code, name, kind, location_id").eq("is_active", true).order("kind").order("code");
  return (data ?? []) as { id: string; code: string; name: string; kind: "cash" | "mobile" | "bank"; location_id: string | null }[];
}
