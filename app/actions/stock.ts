"use server";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { requireWorkspace } from "@/lib/workspace";
import { db, readQtyFields } from "@/lib/stock";

// ------------------------------------------------------------------ helpers
function f(fd: FormData, k: string): string {
  const v = fd.get(k);
  return typeof v === "string" ? v.trim() : "";
}
function money(fd: FormData, k: string): number | null {
  const raw = f(fd, k).replace(/[,\s]/g, "");
  if (!raw) return null;
  const n = Number(raw);
  return Number.isInteger(n) && n > 0 ? n : NaN;
}
function backTo(fd: FormData, fallback: string): string {
  const b = f(fd, "back");
  return b.startsWith("/") && !b.startsWith("//") ? b : fallback;
}
function withMsg(path: string, key: "ok" | "err", msg: string): string {
  const u = new URL(path, "http://x");
  u.searchParams.delete("ok"); u.searchParams.delete("err");
  u.searchParams.set(key, msg.slice(0, 200));
  return u.pathname + u.search;
}
/** Database exceptions raised by our functions are written to be user-readable; others become generic. */
function dbMessage(e: { message?: string; code?: string } | null): string {
  if (!e) return "Error";
  if (e.code === "42501") return `Not allowed: ${e.message ?? ""}`;
  return e.message ?? "Error";
}
async function done(fd: FormData, fallback: string, error: { message?: string; code?: string } | null, ok = "✓") {
  const path = backTo(fd, fallback);
  revalidatePath(path.split("?")[0]);
  redirect(withMsg(path, error ? "err" : "ok", error ? dbMessage(error) : ok));
}

// ------------------------------------------------------------------ catalogue
export async function createDesign(fd: FormData) {
  await requireWorkspace("products.manage");
  const supabase = await db();
  const colors = f(fd, "colors").split(",").map((c) => c.trim()).filter(Boolean);
  const sizes = fd.getAll("sizes").map(String);
  const retail = money(fd, "retail"), wholesale = money(fd, "wholesale");
  if (Number.isNaN(retail) || Number.isNaN(wholesale)) return done(fd, "/products/new", { message: "Price must be a whole positive number" });
  const { data, error } = await supabase.rpc("design_create", {
    p_code: f(fd, "code"), p_name: f(fd, "name"), p_category: f(fd, "category"), p_supplier: f(fd, "supplier") || null,
    p_description: f(fd, "description") || null, p_colors: colors, p_sizes: sizes, p_retail: retail, p_wholesale: wholesale,
  });
  if (error) return done(fd, "/products/new", error);
  redirect(`/products/${data}?ok=✓`);
}

export async function setPrices(fd: FormData) {
  await requireWorkspace("products.manage");
  const supabase = await db();
  const retail = money(fd, "retail"), wholesale = money(fd, "wholesale");
  if (Number.isNaN(retail) || Number.isNaN(wholesale)) return done(fd, "/products", { message: "Price must be a whole positive number" });
  const { error } = await supabase.rpc("variant_set_prices", { p_variant: f(fd, "variant"), p_retail: retail, p_wholesale: wholesale, p_reason: f(fd, "reason") || null });
  return done(fd, "/products", error);
}

export async function addVariant(fd: FormData) {
  await requireWorkspace("products.manage");
  const supabase = await db();
  const retail = money(fd, "retail"), wholesale = money(fd, "wholesale");
  if (Number.isNaN(retail) || Number.isNaN(wholesale)) return done(fd, "/products", { message: "Price must be a whole positive number" });
  const { error } = await supabase.rpc("variant_add", { p_design: f(fd, "design"), p_color: f(fd, "color"), p_size: f(fd, "size"), p_retail: retail, p_wholesale: wholesale });
  return done(fd, "/products", error);
}

// ------------------------------------------------------------------ purchasing
export async function saveSupplier(fd: FormData) {
  await requireWorkspace("purchasing.manage");
  const supabase = await db();
  const { error } = await supabase.rpc("supplier_save", { p_id: null, p_name: f(fd, "name"), p_phone: f(fd, "phone"), p_country: f(fd, "country"), p_notes: f(fd, "notes") });
  return done(fd, "/purchasing", error);
}

export async function createPo(fd: FormData) {
  await requireWorkspace("purchasing.manage");
  const supabase = await db();
  const lines = readQtyFields(fd).map((l) => {
    const p = f(fd, `p_${l.variant_id}`) || f(fd, "unit_price");
    return { variant_id: l.variant_id, qty: l.qty, unit_price_fx: p ? Number(p) : null };
  });
  if (!lines.length) return done(fd, "/purchasing", { message: "Enter at least one quantity" });
  const { error } = await supabase.rpc("po_create", {
    p_idem: f(fd, "idem"), p_supplier: f(fd, "supplier"), p_currency: f(fd, "currency") || "TZS",
    p_fx_rate: Number(f(fd, "fx") || "1"), p_expected: f(fd, "expected") || null, p_lines: lines, p_notes: f(fd, "notes") || null,
  });
  return done(fd, "/purchasing", error);
}

export async function approveCosts(fd: FormData) {
  await requireWorkspace("costs.approve");
  const supabase = await db();
  const lines: { line_id: string; unit_cost: number }[] = [];
  for (const [k, v] of fd.entries()) {
    if (!k.startsWith("c_")) continue;
    const n = Number(String(v).replace(/[,\s]/g, ""));
    if (!Number.isInteger(n) || n < 0) return done(fd, "/purchasing", { message: "Unit costs must be whole TZS amounts" });
    lines.push({ line_id: k.slice(2), unit_cost: n });
  }
  const extras = [0, 1, 2].map((i) => ({ label: f(fd, `xl_${i}`), amount: Number(f(fd, `xa_${i}`).replace(/[,\s]/g, "") || "0") }))
    .filter((x) => x.amount > 0);
  if (extras.some((x) => !Number.isInteger(x.amount) || !x.label)) return done(fd, "/purchasing", { message: "Each extra cost needs a label and a whole TZS amount" });
  const { error } = await supabase.rpc("receipt_approve_costs", {
    p_receipt: f(fd, "receipt"), p_lines: lines, p_extras: extras, p_allocation: f(fd, "allocation"), p_reason: f(fd, "reason") || null,
  });
  if (error) return done(fd, "/purchasing", error);
  redirect("/purchasing?ok=✓");
}

// ------------------------------------------------------------------ store
export async function receiveGoods(fd: FormData) {
  await requireWorkspace("store.operate");
  const supabase = await db();
  const lines = readQtyFields(fd, "r_").map((l) => ({
    variant_id: l.variant_id, qty_received: l.qty, qty_expected: f(fd, `e_${l.variant_id}`) ? Number(f(fd, `e_${l.variant_id}`)) : null,
  }));
  if (!lines.length) return done(fd, "/store", { message: "Enter at least one received quantity" });
  const { error } = await supabase.rpc("goods_receive", {
    p_idem: f(fd, "idem"), p_location: f(fd, "location"), p_supplier: f(fd, "supplier") || null, p_po: f(fd, "po") || null,
    p_supplier_ref: f(fd, "supplier_ref") || null, p_lines: lines, p_notes: f(fd, "notes") || null,
  });
  return done(fd, "/store", error);
}

export async function openingStock(fd: FormData) {
  await requireWorkspace("stock.opening");
  const supabase = await db();
  const lines = readQtyFields(fd);
  if (!lines.length) return done(fd, "/store", { message: "Enter at least one quantity" });
  const { error } = await supabase.rpc("opening_stock_post", { p_idem: f(fd, "idem"), p_location: f(fd, "location"), p_lines: lines, p_reason: f(fd, "reason") });
  return done(fd, "/store", error);
}

export async function createRequisition(fd: FormData) {
  await requireWorkspace("stock.request");
  const supabase = await db();
  const lines = readQtyFields(fd);
  if (!lines.length) return done(fd, "/shop-stock", { message: "Enter at least one quantity" });
  const { error } = await supabase.rpc("requisition_create", { p_idem: f(fd, "idem"), p_from: f(fd, "from"), p_to: f(fd, "to"), p_lines: lines, p_notes: f(fd, "notes") || null });
  return done(fd, "/shop-stock", error);
}

export async function decideRequisition(fd: FormData) {
  await requireWorkspace("stock.approve");
  const supabase = await db();
  const approve = f(fd, "decision") === "approve";
  const lines: { line_id: string; qty_approved: number }[] = [];
  for (const [k, v] of fd.entries()) if (k.startsWith("a_")) lines.push({ line_id: k.slice(2), qty_approved: Number(v || 0) });
  const { error } = await supabase.rpc("requisition_decide", { p_req: f(fd, "req"), p_approve: approve, p_lines: lines, p_note: f(fd, "note") || null });
  return done(fd, "/store", error);
}

export async function dispatchRequisition(fd: FormData) {
  await requireWorkspace("store.operate");
  const supabase = await db();
  const lines: { variant_id: string; qty: number; requisition_line_id: string }[] = [];
  for (const [k, v] of fd.entries()) {
    if (!k.startsWith("d_")) continue;
    const n = Number(v || 0);
    if (Number.isInteger(n) && n > 0) lines.push({ requisition_line_id: k.slice(2), variant_id: f(fd, `v_${k.slice(2)}`), qty: n });
  }
  if (!lines.length) return done(fd, "/store", { message: "Enter at least one quantity" });
  const { error } = await supabase.rpc("transfer_dispatch", { p_idem: f(fd, "idem"), p_requisition: f(fd, "req"), p_from: null, p_to: null, p_lines: lines, p_notes: f(fd, "notes") || null });
  return done(fd, "/store", error);
}

export async function receiveTransfer(fd: FormData) {
  await requireWorkspace("stock.confirm_receipt");
  const supabase = await db();
  const lines: { line_id: string; qty_received: number }[] = [];
  for (const [k, v] of fd.entries()) if (k.startsWith("rcv_")) lines.push({ line_id: k.slice(4), qty_received: Number(v === "" ? NaN : v) });
  if (lines.some((l) => !Number.isInteger(l.qty_received) || l.qty_received < 0)) return done(fd, "/shop-stock", { message: "Enter the received quantity for every line (0 if none)" });
  const { error } = await supabase.rpc("transfer_receive", { p_idem: f(fd, "idem"), p_transfer: f(fd, "transfer"), p_lines: lines, p_override_reason: f(fd, "override") || null });
  return done(fd, "/shop-stock", error);
}

export async function resolveDiscrepancy(fd: FormData) {
  await requireWorkspace("stock.approve");
  const supabase = await db();
  const { error } = await supabase.rpc("discrepancy_resolve", { p_discrepancy: f(fd, "disc"), p_resolution: f(fd, "resolution"), p_reason: f(fd, "reason") });
  return done(fd, "/store", error);
}

export async function startCount(fd: FormData) {
  await requireWorkspace("store.operate");
  const supabase = await db();
  const { error } = await supabase.rpc("count_start", { p_location: f(fd, "location"), p_variants: null });
  return done(fd, "/store", error);
}

export async function submitCount(fd: FormData) {
  await requireWorkspace("store.operate");
  const supabase = await db();
  const lines: { line_id: string; counted_qty: number }[] = [];
  for (const [k, v] of fd.entries()) if (k.startsWith("cnt_")) lines.push({ line_id: k.slice(4), counted_qty: Number(v === "" ? NaN : v) });
  if (lines.some((l) => !Number.isInteger(l.counted_qty) || l.counted_qty < 0)) return done(fd, "/store", { message: "Enter a counted quantity for every line (0 if none)" });
  const { error } = await supabase.rpc("count_submit", { p_count: f(fd, "count"), p_lines: lines });
  return done(fd, "/store", error);
}

export async function decideCount(fd: FormData) {
  await requireWorkspace("stock.approve");
  const supabase = await db();
  const { error } = await supabase.rpc("count_decide", { p_count: f(fd, "count"), p_approve: f(fd, "decision") === "approve", p_reason: f(fd, "reason") });
  return done(fd, "/store", error);
}
