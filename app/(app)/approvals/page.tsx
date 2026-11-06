import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { APPROVALS_AREA, can } from "@/lib/roles";
import { db } from "@/lib/stock";
import { tzs } from "@/lib/format";
import { decideApproval, decideExpense, decideReturn, reviewShift } from "@/app/actions/sales";
import { decideLoss } from "@/app/actions/wholesale";
import { variantLabels, variantText } from "@/lib/stock";

function DecideButtons({ x, nameField = "decision" }: { x: { approve: string; reject: string; note: string }; nameField?: string }) {
  return (
    <div className="mt-2 flex flex-wrap items-end gap-2">
      <input name="note" placeholder={x.note} className="input min-w-48 flex-1" />
      <button name={nameField} value="approve" className="btn btn-primary">{x.approve}</button>
      <button name={nameField} value="reject" className="btn btn-danger">{x.reject}</button>
    </div>
  );
}

export default async function ApprovalsPage({ searchParams }: { searchParams: Promise<{ ok?: string; err?: string }> }) {
  const ws = await requireWorkspace([...APPROVALS_AREA, "pos.sell"]);
  const { x } = await getSalesDict();
  const sp = await searchParams;
  const supabase = await db();
  const me = ws.membership_id;
  const { data: members } = await supabase.from("memberships").select("id, display_name");
  const who = new Map((members ?? []).map((m) => [m.id, m.display_name]));
  const fmt = new Intl.DateTimeFormat("en-GB", { dateStyle: "short", timeStyle: "short", timeZone: ws.business.timezone });

  const { data: losses } = can(ws, "approvals.decide")
    ? await supabase.from("consignment_losses").select("id, partner_id, variant_id, qty, reported_by, created_at").eq("status", "pending").neq("reported_by", me)
    : { data: [] };
  const lossLabels = await variantLabels((losses ?? []).map((l) => l.variant_id));
  const { data: lossPartners } = (losses ?? []).length ? await supabase.from("customers").select("id, name").in("id", (losses ?? []).map((l) => l.partner_id)) : { data: [] };
  const lpName = new Map((lossPartners ?? []).map((c) => [c.id, c.name]));
  const [appr, rets, exps, shifts, mine] = await Promise.all([
    can(ws, "approvals.decide") ? supabase.from("approval_requests").select("id, operation, reasons, summary, requested_by, created_at").eq("status", "pending").neq("requested_by", me).order("created_at") : Promise.resolve({ data: [] }),
    can(ws, "returns.approve") ? supabase.from("sale_returns").select("id, ref_no, amount, settlement, reason, requested_by, created_at").eq("status", "requested").neq("requested_by", me).order("created_at") : Promise.resolve({ data: [] }),
    can(ws, "expenses.approve") ? supabase.from("expenses").select("id, ref_no, category, amount, payee, description, requested_by, expense_date").eq("status", "requested").neq("requested_by", me).order("created_at") : Promise.resolve({ data: [] }),
    can(ws, "shift.review") ? supabase.from("shifts").select("id, ref_no, opened_by, closed_at, expected_cash, counted_cash, variance, variance_reason").eq("status", "pending_review").neq("opened_by", me) : Promise.resolve({ data: [] }),
    supabase.from("approval_requests").select("id, reasons, summary, status, decision_note, created_at").eq("requested_by", me).order("created_at", { ascending: false }).limit(20),
  ]);
  const empty = (appr.data ?? []).length + (rets.data ?? []).length + (exps.data ?? []).length + (shifts.data ?? []).length + (losses ?? []).length === 0;

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <PageHeader title={x.approvals.title} />
      <Flash ok={sp.ok} err={sp.err} />
      {empty && <p className="card p-6 text-sm text-muted">{x.approvals.none}</p>}

      {(appr.data ?? []).length > 0 && <section><h2 className="mb-2 font-semibold">{x.approvals.sales}</h2>
        {(appr.data ?? []).map((a) => {
          const s = a.summary as { total: number; discount: number; discount_pct: number; due: number; customer: string | null; sold_at: string };
          return (
            <form key={a.id} action={decideApproval} className="card mb-3 p-4 text-sm">
              <input type="hidden" name="approval" value={a.id} /><input type="hidden" name="back" value="/approvals" />
              <p><strong>{who.get(a.requested_by)}</strong> · {fmt.format(new Date(a.created_at))}</p>
              <p className="mt-1">{x.approvals.reasons}: <strong>{(a.reasons as string[]).map((r) => x.pos.approvalWhy[r] ?? r).join(", ")}</strong></p>
              <p className="text-muted">{x.pos.total} {tzs(s.total)} · {x.pos.discount} {tzs(s.discount)} ({s.discount_pct}%) · {x.pos.due} {tzs(s.due)}
                {s.customer && ` · ${s.customer}`} · {fmt.format(new Date(s.sold_at))}</p>
              <DecideButtons x={x.approvals} />
            </form>
          );
        })}</section>}

      {(rets.data ?? []).length > 0 && <section><h2 className="mb-2 font-semibold">{x.approvals.returns}</h2>
        {(rets.data ?? []).map((r) => (
          <form key={r.id} action={decideReturn} className="card mb-3 p-4 text-sm">
            <input type="hidden" name="return" value={r.id} /><input type="hidden" name="back" value="/approvals" />
            <p><strong>{r.ref_no}</strong> · {who.get(r.requested_by)} · {tzs(r.amount)} · {r.settlement}</p>
            <p className="text-muted">{r.reason}</p>
            <DecideButtons x={x.approvals} />
          </form>
        ))}</section>}

      {(exps.data ?? []).length > 0 && <section><h2 className="mb-2 font-semibold">{x.approvals.expenses}</h2>
        {(exps.data ?? []).map((e) => (
          <form key={e.id} action={decideExpense} className="card mb-3 p-4 text-sm">
            <input type="hidden" name="expense" value={e.id} /><input type="hidden" name="back" value="/approvals" />
            <p><strong>{e.ref_no}</strong> · {e.category} · <strong>{tzs(e.amount)}</strong> · {who.get(e.requested_by)} · {e.expense_date}</p>
            <p className="text-muted">{[e.payee, e.description].filter(Boolean).join(" — ")}</p>
            <DecideButtons x={x.approvals} />
          </form>
        ))}</section>}

      {(shifts.data ?? []).length > 0 && <section><h2 className="mb-2 font-semibold">{x.approvals.shifts}</h2>
        {(shifts.data ?? []).map((s) => (
          <form key={s.id} action={reviewShift} className="card mb-3 p-4 text-sm">
            <input type="hidden" name="shift" value={s.id} /><input type="hidden" name="back" value="/approvals" />
            <p><strong>{s.ref_no}</strong> · {who.get(s.opened_by)} · {s.closed_at && fmt.format(new Date(s.closed_at))}</p>
            <p>{x.shift.expected} {tzs(s.expected_cash ?? 0)} · {x.shift.counted} {tzs(s.counted_cash ?? 0)} ·{" "}
              <strong className={(s.variance ?? 0) < 0 ? "text-bad" : "text-warn"}>{x.shift.variance} {tzs(s.variance ?? 0)}</strong></p>
            <p className="text-muted">{s.variance_reason}</p>
            <div className="mt-2 flex flex-wrap gap-2"><input name="note" required placeholder={x.money.reviewNote} className="input min-w-48 flex-1" />
              <button className="btn btn-primary">{x.money.review}</button></div>
          </form>
        ))}</section>}

      {(losses ?? []).length > 0 && <section><h2 className="mb-2 font-semibold">{x.wholesale.losses}</h2>
        {(losses ?? []).map((l) => (
          <form key={l.id} action={decideLoss} className="card mb-3 p-4 text-sm">
            <input type="hidden" name="loss" value={l.id} /><input type="hidden" name="back" value="/approvals" />
            <p><strong>{lpName.get(l.partner_id)}</strong> · {variantText(lossLabels.get(l.variant_id))} · {l.qty} pcs · {who.get(l.reported_by)}</p>
            <div className="mt-2 flex flex-wrap items-end gap-2">
              <input name="note" required placeholder={x.approvals.note} className="input min-w-48 flex-1" />
              <button name="decision" value="charge" className="btn btn-primary">{x.wholesale.charge}</button>
              <button name="decision" value="write_off" className="btn btn-ghost">{x.wholesale.writeOff}</button>
              <button name="decision" value="reject" className="btn btn-danger">{x.wholesale.reject}</button>
            </div>
          </form>
        ))}</section>}

      {(mine.data ?? []).length > 0 && <section><h2 className="mb-2 font-semibold">{x.approvals.mine}</h2>
        <ul className="card divide-y divide-line text-sm">
          {(mine.data ?? []).map((m) => (
            <li key={m.id} className="flex flex-wrap justify-between gap-2 px-4 py-2">
              <span>{fmt.format(new Date(m.created_at))} · {(m.reasons as string[]).map((r) => x.pos.approvalWhy[r] ?? r).join(", ")} · {tzs((m.summary as { total: number }).total)}</span>
              <span className="badge border border-line bg-ivory">{m.status}{m.decision_note ? ` — ${m.decision_note}` : ""}</span>
            </li>
          ))}
        </ul></section>}
    </div>
  );
}
