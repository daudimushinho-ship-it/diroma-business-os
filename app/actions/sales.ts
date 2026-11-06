"use server";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { requireWorkspace } from "@/lib/workspace";
import { db } from "@/lib/stock";
import { amount0, dbMessage, done, f, money } from "@/lib/action-utils";
import { normalizePhone } from "@/lib/phone";
import { myShift } from "@/lib/sales";

// ------------------------------------------------------------------ shift
export async function openShift(fd: FormData) {
  await requireWorkspace("pos.sell");
  const supabase = await db();
  const float = amount0(fd, "float");
  if (Number.isNaN(float)) return done(fd, "/pos", { message: "Opening float must be a whole TZS amount" });
  const { data: drawer } = await supabase.from("money_accounts").select("location_id").eq("id", f(fd, "drawer")).maybeSingle();
  const { error } = await supabase.rpc("shift_open", { p_location: drawer?.location_id ?? null, p_cash_account: f(fd, "drawer"), p_opening_float: float });
  return done(fd, "/pos", error);
}

export async function closeShift(fd: FormData) {
  await requireWorkspace("pos.sell");
  const supabase = await db();
  const counted = amount0(fd, "counted");
  if (Number.isNaN(counted) || f(fd, "counted") === "") return done(fd, "/pos/shift", { message: "Enter the counted cash" });
  const { data, error } = await supabase.rpc("shift_close", { p_shift: f(fd, "shift"), p_counted: counted, p_reason: f(fd, "reason") || null });
  if (error) return done(fd, "/pos/shift", error);
  const r = data as { expected: number; counted: number; variance: number };
  redirect(`/pos/shift?closed=1&expected=${r.expected}&counted=${r.counted}&variance=${r.variance}`);
}

// ------------------------------------------------------------------ POS sale (called from the client terminal)
export type SaleInput = {
  idem: string; location: string; shift: string; customer: string | null; channel: "retail" | "wholesale";
  lines: { variant_id: string; qty: number; discount: number }[];
  delivery_fee: number; fulfillment: "collected" | "awaiting_delivery";
  payments: ({ account_id: string; amount: number; provider_ref?: string } | { method: "customer_credit"; amount: number })[];
  sold_at: string | null; source: string | null; note: string | null; approval: string | null;
};
export type SaleResult =
  | { status: "posted"; sale_id: string; ref_no: string; total: number; due: number }
  | { status: "approval_required"; approval_id: string; reasons: string[] }
  | { status: "error"; message: string };

export async function postSale(input: SaleInput): Promise<SaleResult> {
  await requireWorkspace("pos.sell");
  const supabase = await db();
  if (!/^[0-9a-f-]{36}$/.test(input.idem)) return { status: "error", message: "Invalid request id" };
  const lines = input.lines.filter((l) => Number.isInteger(l.qty) && l.qty > 0)
    .map((l) => ({ variant_id: l.variant_id, qty: l.qty, discount: Math.max(0, Math.round(l.discount || 0)) }));
  const payments = input.payments.filter((p) => Number.isInteger(p.amount) && p.amount > 0);
  const { data, error } = await supabase.rpc("sale_post", {
    p_idem: input.idem, p_location: input.location, p_shift: input.shift, p_customer: input.customer, p_channel: input.channel,
    p_lines: lines, p_delivery_fee: Math.max(0, Math.round(input.delivery_fee || 0)), p_fulfillment: input.fulfillment,
    p_payments: payments, p_sold_at: input.sold_at ? new Date(input.sold_at).toISOString() : null,
    p_source: input.source, p_note: input.note, p_approval: input.approval,
  });
  if (error) return { status: "error", message: dbMessage(error) };
  revalidatePath("/pos");
  return data as SaleResult;
}

export async function setFulfillment(fd: FormData) {
  await requireWorkspace("pos.sell");
  const supabase = await db();
  const { error } = await supabase.rpc("sale_set_fulfillment", { p_sale: f(fd, "sale"), p_status: f(fd, "status"), p_note: f(fd, "note") || null });
  return done(fd, "/sales", error);
}

// ------------------------------------------------------------------ returns
export async function requestReturn(fd: FormData) {
  await requireWorkspace("returns.request");
  const supabase = await db();
  const lines: { sale_line_id: string; qty: number }[] = [];
  for (const [k, v] of fd.entries()) {
    if (!k.startsWith("rq_")) continue;
    const n = Number(v || 0);
    if (Number.isInteger(n) && n > 0) lines.push({ sale_line_id: k.slice(3), qty: n });
  }
  if (!lines.length) return done(fd, "/sales", { message: "Enter a quantity to return" });
  const { error } = await supabase.rpc("return_request", {
    p_idem: f(fd, "idem"), p_sale: f(fd, "sale"), p_lines: lines, p_reason: f(fd, "reason"), p_settlement: f(fd, "settlement"),
  });
  return done(fd, "/sales", error);
}

export async function decideReturn(fd: FormData) {
  await requireWorkspace("returns.approve");
  const supabase = await db();
  const { error } = await supabase.rpc("return_decide", { p_return: f(fd, "return"), p_approve: f(fd, "decision") === "approve", p_note: f(fd, "note") || null });
  return done(fd, "/approvals", error);
}

export async function payRefund(fd: FormData) {
  await requireWorkspace("refunds.pay");
  const supabase = await db();
  const amt = money(fd, "amount");
  if (!amt || Number.isNaN(amt)) return done(fd, "/sales", { message: "Enter the refund amount" });
  const shift = await myShift();
  const { error } = await supabase.rpc("refund_pay", {
    p_idem: f(fd, "idem"), p_return: f(fd, "return"), p_account: f(fd, "account"), p_shift: shift?.id ?? null, p_amount: amt, p_provider_ref: f(fd, "ref") || null,
  });
  return done(fd, "/sales", error);
}

export async function releaseInspection(fd: FormData) {
  await requireWorkspace("inspection.release");
  const supabase = await db();
  const { error } = await supabase.rpc("inspection_release", {
    p_idem: f(fd, "idem"), p_return_line: f(fd, "line"), p_qty: Number(f(fd, "qty") || 0), p_outcome: f(fd, "outcome"), p_reason: f(fd, "reason"),
  });
  return done(fd, "/store", error);
}

// ------------------------------------------------------------------ customers
export async function saveCustomer(fd: FormData) {
  await requireWorkspace("customers.manage");
  const supabase = await db();
  const rawPhone = f(fd, "phone");
  let phone: string | null = null;
  if (rawPhone) {
    const p = normalizePhone(rawPhone);
    if (!p.ok) return done(fd, "/customers", { message: "Phone number is not valid" });
    phone = p.e164;
  }
  const limit = amount0(fd, "credit_limit");
  const terms = amount0(fd, "terms_days");
  if (Number.isNaN(limit) || Number.isNaN(terms)) return done(fd, "/customers", { message: "Credit limit and days must be whole numbers" });
  const id = f(fd, "id") || null;
  const { data, error } = await supabase.rpc("customer_save", {
    p_id: id, p_name: f(fd, "name"), p_phone: phone, p_kind: f(fd, "kind") || "retail",
    p_credit_limit: fd.has("credit_limit") ? limit : null, p_terms_days: fd.has("terms_days") ? terms : null,
    p_region: f(fd, "region"), p_notes: f(fd, "notes"), p_source: f(fd, "source"),
  });
  if (error) return done(fd, "/customers", error);
  if (!id) redirect(`/customers/${data}?ok=✓`);
  return done(fd, `/customers/${id}`, null);
}

export async function collectPayment(fd: FormData) {
  await requireWorkspace("payments.collect");
  const supabase = await db();
  const amt = money(fd, "amount");
  if (!amt || Number.isNaN(amt)) return done(fd, "/customers", { message: "Enter a whole TZS amount" });
  const shift = await myShift();
  const { error } = await supabase.rpc("payment_collect", {
    p_idem: f(fd, "idem"), p_customer: f(fd, "customer"), p_account: f(fd, "account"), p_amount: amt,
    p_provider_ref: f(fd, "ref") || null, p_shift: shift?.id ?? null, p_allocations: null,
  });
  return done(fd, "/customers", error);
}

// ------------------------------------------------------------------ approvals
export async function decideApproval(fd: FormData) {
  await requireWorkspace("approvals.decide");
  const supabase = await db();
  const { error } = await supabase.rpc("approval_decide", { p_approval: f(fd, "approval"), p_approve: f(fd, "decision") === "approve", p_note: f(fd, "note") || null });
  return done(fd, "/approvals", error);
}

// ------------------------------------------------------------------ money
export async function createMoneyAccount(fd: FormData) {
  await requireWorkspace("money.manage");
  const supabase = await db();
  const { error } = await supabase.rpc("money_account_create", { p_code: f(fd, "code"), p_name: f(fd, "name"), p_kind: f(fd, "kind"), p_location: f(fd, "location") || null });
  return done(fd, "/money", error);
}

export async function postOpeningBalance(fd: FormData) {
  await requireWorkspace("money.manage");
  const supabase = await db();
  const amt = amount0(fd, "amount");
  if (Number.isNaN(amt)) return done(fd, "/money", { message: "Enter a whole TZS amount" });
  const { error } = await supabase.rpc("money_account_opening", { p_account: f(fd, "account"), p_amount: amt, p_as_of: f(fd, "as_of"), p_reason: f(fd, "reason") });
  return done(fd, "/money", error);
}

export async function sendTransfer(fd: FormData) {
  await requireWorkspace();
  const supabase = await db();
  const amt = money(fd, "amount");
  if (!amt || Number.isNaN(amt)) return done(fd, "/money", { message: "Enter a whole TZS amount" });
  const shift = await myShift();
  const { error } = await supabase.rpc("money_transfer_send", {
    p_idem: f(fd, "idem"), p_from: f(fd, "from"), p_to: f(fd, "to"), p_amount: amt, p_reference: f(fd, "reference") || null,
    p_evidence_note: f(fd, "evidence") || null, p_shift: shift && shift.cash_account_id === f(fd, "from") ? shift.id : null,
  });
  return done(fd, "/money", error);
}

export async function confirmTransfer(fd: FormData) {
  await requireWorkspace("money.transfer");
  const supabase = await db();
  const fee = amount0(fd, "fee");
  if (Number.isNaN(fee)) return done(fd, "/money", { message: "Fee must be a whole TZS amount" });
  const { error } = await supabase.rpc("money_transfer_confirm", { p_transfer: f(fd, "transfer"), p_fee: fee, p_provider_ref: f(fd, "ref") || null });
  return done(fd, "/money", error);
}

export async function requestExpense(fd: FormData) {
  await requireWorkspace("expenses.request");
  const supabase = await db();
  const amt = money(fd, "amount");
  if (!amt || Number.isNaN(amt)) return done(fd, "/money", { message: "Enter a whole TZS amount" });
  const { error } = await supabase.rpc("expense_request", {
    p_idem: f(fd, "idem"), p_location: f(fd, "location") || null, p_category: f(fd, "category"), p_amount: amt,
    p_payee: f(fd, "payee") || null, p_description: f(fd, "description") || null, p_expense_date: f(fd, "date") || null, p_evidence_path: null,
  });
  return done(fd, "/money", error);
}

export async function decideExpense(fd: FormData) {
  await requireWorkspace("expenses.approve");
  const supabase = await db();
  const { error } = await supabase.rpc("expense_decide", { p_expense: f(fd, "expense"), p_approve: f(fd, "decision") === "approve", p_note: f(fd, "note") || null });
  return done(fd, "/approvals", error);
}

export async function payExpense(fd: FormData) {
  await requireWorkspace("expenses.pay");
  const supabase = await db();
  const shift = await myShift();
  const { error } = await supabase.rpc("expense_pay", {
    p_idem: f(fd, "idem"), p_expense: f(fd, "expense"), p_account: f(fd, "account"),
    p_shift: shift && shift.cash_account_id === f(fd, "account") ? shift.id : null, p_provider_ref: f(fd, "ref") || null,
  });
  return done(fd, "/money", error);
}

export async function reviewShift(fd: FormData) {
  await requireWorkspace("shift.review");
  const supabase = await db();
  const { error } = await supabase.rpc("shift_review", { p_shift: f(fd, "shift"), p_note: f(fd, "note") });
  return done(fd, "/approvals", error);
}

export async function issueAdvance(fd: FormData) {
  await requireWorkspace("deliveries.manage");
  const supabase = await db();
  const amt = money(fd, "amount");
  if (!amt || Number.isNaN(amt)) return done(fd, "/money", { message: "Enter a whole TZS amount" });
  const shift = await myShift();
  const { error } = await supabase.rpc("advance_issue", {
    p_idem: f(fd, "idem"), p_runner_name: f(fd, "runner"), p_sale: f(fd, "sale") || null, p_account: f(fd, "account"), p_amount: amt,
    p_shift: shift && shift.cash_account_id === f(fd, "account") ? shift.id : null,
  });
  return done(fd, "/money", error);
}

export async function settleAdvance(fd: FormData) {
  await requireWorkspace("deliveries.manage");
  const supabase = await db();
  const spent = amount0(fd, "spent"), returned = amount0(fd, "returned");
  if (Number.isNaN(spent) || Number.isNaN(returned)) return done(fd, "/money", { message: "Enter whole TZS amounts" });
  const shift = await myShift();
  const { error } = await supabase.rpc("advance_settle", {
    p_advance: f(fd, "advance"), p_expense: spent, p_returned: returned, p_return_account: f(fd, "account") || null,
    p_shift: shift && shift.cash_account_id === f(fd, "account") ? shift.id : null, p_evidence_note: f(fd, "evidence"),
  });
  return done(fd, "/money", error);
}
