"use server";
import { redirect } from "next/navigation";
import { requireWorkspace } from "@/lib/workspace";
import { db, readQtyFields } from "@/lib/stock";
import { done, f, money } from "@/lib/action-utils";

export async function configurePartner(fd: FormData) {
  await requireWorkspace("wholesale.manage");
  const supabase = await db();
  const days = Number(f(fd, "interval") || "7");
  const { error } = await supabase.rpc("partner_configure", {
    p_customer: f(fd, "partner"), p_enabled: f(fd, "enabled") === "on" || f(fd, "enabled") === "true", p_interval_days: Number.isInteger(days) ? days : 7,
  });
  return done(fd, "/wholesale?tab=partners", error);
}

export async function createConsignment(fd: FormData) {
  await requireWorkspace("wholesale.manage");
  const supabase = await db();
  const price = money(fd, "unit_price");
  if (Number.isNaN(price)) return done(fd, "/wholesale?tab=consign", { message: "Agreed price must be a whole TZS amount" });
  const lines = readQtyFields(fd).map((l) => ({ variant_id: l.variant_id, qty: l.qty, unit_price: price }));
  if (!lines.length) return done(fd, "/wholesale?tab=consign", { message: "Enter at least one quantity" });
  const { error } = await supabase.rpc("consignment_order_create", {
    p_idem: f(fd, "idem"), p_partner: f(fd, "partner"), p_source: f(fd, "source"), p_lines: lines, p_notes: f(fd, "notes") || null,
  });
  return done(fd, "/wholesale?tab=orders", error);
}

export async function cancelConsignment(fd: FormData) {
  await requireWorkspace("wholesale.manage");
  const supabase = await db();
  const { error } = await supabase.rpc("consignment_order_cancel", { p_order: f(fd, "order"), p_reason: f(fd, "reason") });
  return done(fd, "/wholesale?tab=orders", error);
}

export async function dispatchConsignment(fd: FormData) {
  await requireWorkspace("store.operate");
  const supabase = await db();
  const lines: { order_line_id: string; qty: number }[] = [];
  for (const [k, v] of fd.entries()) {
    if (!k.startsWith("d_")) continue;
    const n = Number(v || 0);
    if (Number.isInteger(n) && n > 0) lines.push({ order_line_id: k.slice(2), qty: n });
  }
  if (!lines.length) return done(fd, "/store", { message: "Enter at least one quantity" });
  const { error } = await supabase.rpc("consignment_dispatch", {
    p_idem: f(fd, "idem"), p_order: f(fd, "order"), p_lines: lines, p_recipient: f(fd, "recipient"),
    p_evidence: f(fd, "evidence") || null, p_override_reason: f(fd, "override") || null,
  });
  return done(fd, "/store", error);
}

export async function reportConsignment(fd: FormData) {
  await requireWorkspace("wholesale.manage");
  const supabase = await db();
  const byVariant = new Map<string, { variant_id: string; sold: number; returned: number; lost: number }>();
  for (const [k, v] of fd.entries()) {
    const m = /^(sold|returned|lost)_(.+)$/.exec(k);
    if (!m) continue;
    const n = Number(v || 0);
    if (!Number.isInteger(n) || n < 0) return done(fd, "/wholesale", { message: "Quantities must be whole numbers" });
    const row = byVariant.get(m[2]) ?? { variant_id: m[2], sold: 0, returned: 0, lost: 0 };
    row[m[1] as "sold" | "returned" | "lost"] = n;
    byVariant.set(m[2], row);
  }
  const lines = [...byVariant.values()].filter((l) => l.sold + l.returned + l.lost > 0);
  if (!lines.length) return done(fd, "/wholesale", { message: "Nothing reported" });
  const { error } = await supabase.rpc("consignment_report", {
    p_idem: f(fd, "idem"), p_partner: f(fd, "partner"), p_report_date: f(fd, "date"), p_lines: lines, p_note: f(fd, "note") || null,
  });
  return done(fd, "/wholesale", error);
}

export async function decideLoss(fd: FormData) {
  await requireWorkspace("approvals.decide");
  const supabase = await db();
  const { error } = await supabase.rpc("consignment_loss_decide", { p_loss: f(fd, "loss"), p_decision: f(fd, "decision"), p_note: f(fd, "note") });
  return done(fd, "/approvals", error);
}

export async function logReminder(fd: FormData) {
  await requireWorkspace("wholesale.manage");
  const supabase = await db();
  const { error } = await supabase.rpc("consignment_reminder_log", { p_partner: f(fd, "partner"), p_channel: f(fd, "channel") || "whatsapp", p_note: f(fd, "note") || null });
  return done(fd, "/wholesale", error);
}

/** Outright wholesale sale. If approval is needed, the exact request is kept on the approval and can be resubmitted unchanged. */
export async function wholesaleSale(fd: FormData) {
  await requireWorkspace("wholesale.manage");
  const supabase = await db();
  const lines = readQtyFields(fd).map((l) => ({ variant_id: l.variant_id, qty: l.qty, discount: 0 }));
  if (!lines.length) return done(fd, "/wholesale?tab=sell", { message: "Enter at least one quantity" });
  const { data, error } = await supabase.rpc("wholesale_sale_post", {
    p_idem: f(fd, "idem"), p_partner: f(fd, "partner"), p_source: f(fd, "source"), p_lines: lines, p_note: f(fd, "note") || null, p_approval: null,
  });
  if (error) return done(fd, "/wholesale?tab=sell", error);
  const r = data as { status: string; sale_id?: string; approval_id?: string };
  if (r.status === "approval_required") redirect(`/wholesale?tab=sell&pending=${r.approval_id}`);
  redirect(`/sales/${r.sale_id}?ok=✓`);
}

export async function resubmitWholesaleSale(fd: FormData) {
  await requireWorkspace("wholesale.manage");
  const supabase = await db();
  const id = f(fd, "approval");
  const { data: appr } = await supabase.from("approval_requests").select("summary, status").eq("id", id).maybeSingle();
  const p = (appr?.summary as { payload?: { partner: string; source: string; lines: unknown; note: string | null } } | undefined)?.payload;
  if (!p) return done(fd, "/wholesale?tab=sell", { message: "Approval not found" });
  const { data, error } = await supabase.rpc("wholesale_sale_post", {
    p_idem: crypto.randomUUID(), p_partner: p.partner, p_source: p.source, p_lines: p.lines, p_note: p.note, p_approval: id,
  });
  if (error) return done(fd, `/wholesale?tab=sell&pending=${id}`, error);
  redirect(`/sales/${(data as { sale_id: string }).sale_id}?ok=✓`);
}
