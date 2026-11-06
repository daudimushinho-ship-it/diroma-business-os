"use server";
import { requireWorkspace } from "@/lib/workspace";
import { db } from "@/lib/stock";
import { amount0, done, f } from "@/lib/action-utils";
import { normalizePhone } from "@/lib/phone";

const back = (fd: FormData) => f(fd, "back") || "/performance";

export async function setTarget(fd: FormData) {
  await requireWorkspace("targets.manage");
  const supabase = await db();
  const v = amount0(fd, "value");
  if (Number.isNaN(v)) return done(fd, back(fd), { message: "Enter a whole number" });
  const scope = f(fd, "scope");
  const { error } = await supabase.rpc("target_set", {
    p_metric: f(fd, "metric"), p_scope: scope, p_location: null, p_member: scope === "member" ? f(fd, "member") : null,
    p_kind: f(fd, "kind"), p_date: f(fd, "date"), p_value: v, p_note: f(fd, "note") || null,
  });
  return done(fd, back(fd), error);
}

export async function logContent(fd: FormData) {
  await requireWorkspace("team.work");
  const supabase = await db();
  const { error } = await supabase.rpc("content_log", {
    p_kind: f(fd, "kind"), p_platform: f(fd, "platform"), p_url: f(fd, "url"), p_design: f(fd, "design") || null,
    p_posted_on: f(fd, "posted_on"), p_note: f(fd, "note") || null,
  });
  return done(fd, back(fd), error);
}

export async function verifyContent(fd: FormData) {
  await requireWorkspace("content.verify");
  const supabase = await db();
  const { error } = await supabase.rpc("content_verify", { p_post: f(fd, "post"), p_approve: f(fd, "decision") === "verify", p_note: f(fd, "note") || null });
  return done(fd, back(fd), error);
}

export async function createTask(fd: FormData) {
  await requireWorkspace("tasks.assign");
  const supabase = await db();
  const due = f(fd, "due");
  const dueAt = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(due) ? new Date(due + ":00+03:00").toISOString() : null; // business time (UTC+3)
  const { error } = await supabase.rpc("task_create", {
    p_title: f(fd, "title"), p_details: f(fd, "details") || null, p_assignee: f(fd, "assignee"), p_location: f(fd, "location") || null,
    p_due_at: dueAt, p_priority: f(fd, "priority") || "normal",
  });
  return done(fd, back(fd), error);
}

export async function completeTask(fd: FormData) {
  await requireWorkspace("team.work");
  const supabase = await db();
  const { error } = await supabase.rpc("task_complete", { p_task: f(fd, "task"), p_evidence: f(fd, "evidence") });
  return done(fd, back(fd), error);
}

export async function reviewTask(fd: FormData) {
  await requireWorkspace("tasks.assign");
  const supabase = await db();
  const { error } = await supabase.rpc("task_review", { p_task: f(fd, "task"), p_decision: f(fd, "decision"), p_note: f(fd, "note") || null });
  return done(fd, back(fd), error);
}

export async function createInquiry(fd: FormData) {
  await requireWorkspace("team.work");
  const supabase = await db();
  let phone: string | null = null;
  if (f(fd, "phone")) {
    const p = normalizePhone(f(fd, "phone"));
    if (!p.ok) return done(fd, back(fd), { message: "Phone number is not valid" });
    phone = p.e164;
  }
  const { error } = await supabase.rpc("inquiry_create", {
    p_name: f(fd, "name"), p_phone: phone, p_customer: f(fd, "customer") || null, p_channel: f(fd, "channel"), p_interest: f(fd, "interest") || null,
    p_design: f(fd, "design") || null, p_assigned_to: f(fd, "assigned_to") || null, p_next_follow_up: f(fd, "next") || null,
  });
  return done(fd, back(fd), error);
}

export async function inquiryEvent(fd: FormData) {
  await requireWorkspace("team.work");
  const supabase = await db();
  const { error } = await supabase.rpc("inquiry_event", { p_inquiry: f(fd, "inquiry"), p_kind: f(fd, "kind"), p_note: f(fd, "note") || null, p_next_follow_up: f(fd, "next") || null });
  return done(fd, back(fd), error);
}

export async function linkInquirySale(fd: FormData) {
  await requireWorkspace("team.work");
  const supabase = await db();
  const ref = f(fd, "ref").toUpperCase();
  const { data: sale } = await supabase.from("sales").select("id").eq("ref_no", ref).maybeSingle();
  if (!sale) return done(fd, back(fd), { message: `Receipt ${ref} not found (or not visible to you)` });
  const { error } = await supabase.rpc("inquiry_link_sale", { p_inquiry: f(fd, "inquiry"), p_sale: sale.id, p_note: f(fd, "note") || null });
  return done(fd, back(fd), error);
}

export async function saveCommissionPlan(fd: FormData) {
  await requireWorkspace("commissions.approve");
  const supabase = await db();
  const rate = Number(f(fd, "rate"));
  const min = amount0(fd, "min");
  if (!(rate > 0) || Number.isNaN(min)) return done(fd, back(fd), { message: "Rate must be above 0 and minimum a whole amount" });
  const member = f(fd, "member");
  const { error } = await supabase.rpc("commission_plan_save", {
    p_id: f(fd, "id") || null, p_name: f(fd, "name"), p_role: member ? null : f(fd, "role") || "sales_staff", p_member: member || null,
    p_basis: f(fd, "basis") || "net_sales", p_rate: rate, p_min: min, p_require_tasks: f(fd, "require_tasks") === "on", p_active: f(fd, "active") !== "off",
  });
  return done(fd, back(fd), error);
}

export async function calculateCommissions(fd: FormData) {
  await requireWorkspace("commissions.calculate");
  const supabase = await db();
  const { error } = await supabase.rpc("commission_calculate", { p_from: f(fd, "from"), p_to: f(fd, "to") });
  return done(fd, back(fd), error);
}

export async function decideCommission(fd: FormData) {
  await requireWorkspace("commissions.approve");
  const supabase = await db();
  const run = f(fd, "run");
  const action = f(fd, "action");
  const { error } = action === "approve"
    ? await supabase.rpc("commission_approve", { p_run: run, p_note: f(fd, "note") || null })
    : action === "pay"
      ? await supabase.rpc("commission_pay", { p_run: run, p_account: f(fd, "account"), p_reference: f(fd, "note") || null })
      : await supabase.rpc("commission_cancel", { p_run: run, p_reason: f(fd, "note") });
  return done(fd, back(fd), error);
}

export async function configureCatalogue(fd: FormData) {
  await requireWorkspace("settings.manage");
  const supabase = await db();
  let wa: string | null = null;
  if (f(fd, "whatsapp")) {
    const p = normalizePhone(f(fd, "whatsapp"));
    if (!p.ok) return done(fd, "/settings", { message: "WhatsApp number is not valid" });
    wa = p.e164;
  }
  const { error } = await supabase.rpc("catalogue_configure", { p_enabled: f(fd, "enabled") === "on", p_slug: f(fd, "slug"), p_whatsapp: wa });
  return done(fd, "/settings", error);
}

export async function publishDesign(fd: FormData) {
  await requireWorkspace("products.manage");
  const supabase = await db();
  const { error } = await supabase.rpc("design_publish", {
    p_design: f(fd, "design"), p_published: f(fd, "published") === "on", p_show_price: f(fd, "show_price") === "on", p_description: f(fd, "description") || null,
  });
  return done(fd, back(fd), error);
}
