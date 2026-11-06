import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { Tabs } from "@/components/Tabs";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { MONEY_AREA, can } from "@/lib/roles";
import { db, locationDirectory } from "@/lib/stock";
import { moneyAccounts, myShift } from "@/lib/sales";
import { businessToday, tzs } from "@/lib/format";
import {
  confirmTransfer, createMoneyAccount, issueAdvance, payExpense, postOpeningBalance, requestExpense, sendTransfer, settleAdvance,
} from "@/app/actions/sales";

type SP = { tab?: string; ok?: string; err?: string };

export default async function MoneyPage({ searchParams }: { searchParams: Promise<SP> }) {
  const ws = await requireWorkspace([...MONEY_AREA, "pos.sell"]);
  const { x } = await getSalesDict();
  const sp = await searchParams;
  const supabase = await db();
  const tabs = [
    ...(can(ws, "money.view") ? [{ key: "accounts", label: x.money.accounts }] : []),
    ...(can(ws, ["money.transfer", "pos.sell"]) ? [{ key: "transfers", label: x.money.transfers }] : []),
    ...(can(ws, ["expenses.request", "expenses.pay"]) ? [{ key: "expenses", label: x.money.expenses }] : []),
    ...(can(ws, "deliveries.manage") ? [{ key: "advances", label: x.money.advances }] : []),
    ...(can(ws, "journal.view") ? [{ key: "journal", label: x.money.journal }] : []),
  ];
  const tab = tabs.some((t) => t.key === sp.tab) ? sp.tab! : tabs[0]?.key ?? "expenses";
  const back = `/money?tab=${tab}`;
  const shift = await myShift();
  const all = await moneyAccounts();
  const usable = all.filter((a) => a.kind !== "cash" || a.id === shift?.cash_account_id || can(ws, "money.transfer"));
  const payFrom = all.filter((a) => a.kind !== "cash" || a.id === shift?.cash_account_id);
  const dir = await locationDirectory();
  const accName = new Map(all.map((a) => [a.id, a.name]));
  const { data: members } = await supabase.from("memberships").select("id, display_name");
  const who = new Map((members ?? []).map((m) => [m.id, m.display_name]));

  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader title={x.money.title} />
      <Tabs active={tab} items={tabs.map((t) => ({ ...t, href: `/money?tab=${t.key}` }))} />
      <Flash ok={sp.ok} err={sp.err} />
      {tab === "accounts" && <Accounts />}
      {tab === "transfers" && <Transfers />}
      {tab === "expenses" && <Expenses />}
      {tab === "advances" && <Advances />}
      {tab === "journal" && <Journal />}
    </div>
  );

  async function Accounts() {
    const { data } = await supabase.rpc("money_balances");
    const rows = (data ?? []) as { account_id: string; code: string; name: string; kind: string; location_id: string | null; balance: number }[];
    return (
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <div className="space-y-3">
          <p className="text-xs text-muted">{x.money.unreconciled}</p>
          <div className="card overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-ivory text-left text-muted"><tr><th className="px-4 py-2 font-medium">{x.money.code}</th><th className="px-4 py-2 font-medium">{x.money.name}</th>
                <th className="px-4 py-2 font-medium">{x.money.kind}</th><th className="px-4 py-2 text-right font-medium">{x.money.balance}</th></tr></thead>
              <tbody className="divide-y divide-line">
                {rows.map((r) => <tr key={r.account_id}><td className="px-4 py-2 font-mono">{r.code}</td><td className="px-4 py-2">{r.name}{r.location_id && <span className="text-xs text-muted"> · {dir.get(r.location_id)?.name}</span>}</td>
                  <td className="px-4 py-2">{x.money[r.kind as "cash"]}</td><td className="px-4 py-2 text-right font-semibold tabular-nums">{tzs(Number(r.balance))}</td></tr>)}
              </tbody>
            </table>
          </div>
        </div>
        {can(ws, "money.manage") && (
          <div className="space-y-4">
            <form action={createMoneyAccount} className="card space-y-2 p-4">
              <input type="hidden" name="back" value={back} /><h2 className="font-semibold">{x.money.newAccount}</h2>
              <input name="code" required placeholder={x.money.code} className="input font-mono uppercase" />
              <input name="name" required placeholder={x.money.name} className="input" />
              <select name="kind" className="input"><option value="cash">{x.money.cash}</option><option value="mobile">{x.money.mobile}</option><option value="bank">{x.money.bank}</option></select>
              <select name="location" className="input" defaultValue=""><option value="">{x.money.location}</option>
                {[...dir.values()].filter((l) => l.kind === "shop" || l.kind === "warehouse").map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select>
              <button className="btn btn-primary w-full">{x.money.newAccount}</button>
            </form>
            <form action={postOpeningBalance} className="card space-y-2 p-4">
              <input type="hidden" name="back" value={back} /><h2 className="font-semibold">{x.money.opening}</h2>
              <select name="account" className="input">{all.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select>
              <input name="amount" inputMode="numeric" required placeholder={x.money.amount} className="input" />
              <input name="as_of" type="date" required defaultValue={businessToday()} className="input" />
              <input name="reason" required placeholder={x.money.reason} className="input" />
              <button className="btn btn-primary w-full">{x.money.opening}</button>
            </form>
          </div>
        )}
      </div>
    );
  }

  async function Transfers() {
    const { data } = await supabase.from("money_transfers").select("id, ref_no, from_account, to_account, amount, fee, status, reference, sent_by, sent_at").order("sent_at", { ascending: false }).limit(50);
    const sendFrom = can(ws, "money.transfer") ? all : all.filter((a) => a.id === shift?.cash_account_id);
    return (
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <div className="space-y-3">
          <p className="text-xs text-muted">{x.money.transferNote}</p>
          {(data ?? []).map((t) => (
            <div key={t.id} className="card p-4 text-sm">
              <p><strong>{t.ref_no}</strong> · {accName.get(t.from_account)} → {accName.get(t.to_account)} · <strong>{tzs(t.amount)}</strong> · {t.status === "in_transit" ? x.money.inTransit : "✓"}</p>
              <p className="text-xs text-muted">{who.get(t.sent_by)} · {t.reference}</p>
              {t.status === "in_transit" && can(ws, "money.transfer") && t.sent_by !== ws.membership_id && (
                <form action={confirmTransfer} className="mt-2 flex flex-wrap gap-2">
                  <input type="hidden" name="transfer" value={t.id} /><input type="hidden" name="back" value={back} />
                  <input name="fee" inputMode="numeric" placeholder={x.money.fee} className="input w-32" />
                  <input name="ref" placeholder={x.pos.providerRef} className="input w-48" />
                  <button className="btn btn-primary">{x.money.confirm}</button>
                </form>
              )}
            </div>
          ))}
        </div>
        {sendFrom.length > 0 && (
          <form action={sendTransfer} className="card h-fit space-y-2 p-4">
            <input type="hidden" name="back" value={back} /><input type="hidden" name="idem" value={crypto.randomUUID()} />
            <h2 className="font-semibold">{x.money.transfers}</h2>
            <label className="block"><span className="label">{x.money.from}</span><select name="from" className="input">{sendFrom.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select></label>
            <label className="block"><span className="label">{x.money.to}</span><select name="to" className="input">{all.filter((a) => a.kind !== "cash").map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select></label>
            <input name="amount" inputMode="numeric" required placeholder={x.money.amount} className="input" />
            <input name="reference" placeholder={x.money.reference} className="input" />
            <input name="evidence" placeholder={x.money.evidence} className="input" />
            <button className="btn btn-primary w-full">{x.money.send}</button>
          </form>
        )}
      </div>
    );
  }

  async function Expenses() {
    const { data } = await supabase.from("expenses").select("id, ref_no, category, amount, payee, status, requested_by, expense_date").order("created_at", { ascending: false }).limit(100);
    return (
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <div className="space-y-2">
          {(data ?? []).map((e) => (
            <div key={e.id} className="card p-4 text-sm">
              <p><strong>{e.ref_no}</strong> · {e.category} · <strong>{tzs(e.amount)}</strong> · {e.status} · {e.expense_date}</p>
              <p className="text-xs text-muted">{who.get(e.requested_by)}{e.payee ? ` → ${e.payee}` : ""}</p>
              {e.status === "approved" && can(ws, "expenses.pay") && (
                <form action={payExpense} className="mt-2 flex flex-wrap gap-2">
                  <input type="hidden" name="expense" value={e.id} /><input type="hidden" name="back" value={back} /><input type="hidden" name="idem" value={crypto.randomUUID()} />
                  <select name="account" className="input w-auto">{payFrom.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select>
                  <input name="ref" placeholder={x.pos.providerRef} className="input w-44" />
                  <button className="btn btn-primary">{x.money.pay}</button>
                </form>
              )}
            </div>
          ))}
        </div>
        {can(ws, "expenses.request") && (
          <form action={requestExpense} className="card h-fit space-y-2 p-4">
            <input type="hidden" name="back" value={back} /><input type="hidden" name="idem" value={crypto.randomUUID()} />
            <h2 className="font-semibold">{x.money.request}</h2>
            <input name="category" required list="exp-cats" placeholder={x.money.category} className="input" />
            <datalist id="exp-cats">{["Transport", "Rent", "Electricity", "Packaging", "Marketing", "Food", "Repairs", "Salary advance"].map((c) => <option key={c} value={c} />)}</datalist>
            <input name="amount" inputMode="numeric" required placeholder={x.money.amount} className="input" />
            <input name="payee" placeholder={x.money.payee} className="input" />
            <input name="description" placeholder={x.money.description} className="input" />
            <input name="date" type="date" defaultValue={businessToday()} className="input" />
            <select name="location" className="input" defaultValue={ws.locations[0]?.id ?? ""}>{ws.locations.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select>
            <button className="btn btn-primary w-full">{x.money.request}</button>
          </form>
        )}
      </div>
    );
  }

  async function Advances() {
    const { data } = await supabase.from("runner_advances").select("id, ref_no, runner_name, amount, status, issued_by, issued_at, expense_amount, returned_amount").order("issued_at", { ascending: false }).limit(50);
    return (
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <div className="space-y-2">
          {(data ?? []).map((a) => (
            <div key={a.id} className="card p-4 text-sm">
              <p><strong>{a.ref_no}</strong> · {a.runner_name} · <strong>{tzs(a.amount)}</strong> · {a.status}
                {a.status === "settled" && <span className="text-muted"> · {x.money.spent} {tzs(a.expense_amount ?? 0)} / {x.money.returned} {tzs(a.returned_amount ?? 0)}</span>}</p>
              {a.status === "outstanding" && (
                <form action={settleAdvance} className="mt-2 flex flex-wrap gap-2">
                  <input type="hidden" name="advance" value={a.id} /><input type="hidden" name="back" value={back} />
                  <input name="spent" inputMode="numeric" required placeholder={x.money.spent} className="input w-28" />
                  <input name="returned" inputMode="numeric" required placeholder={x.money.returned} className="input w-28" />
                  <select name="account" className="input w-auto">{payFrom.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select>
                  <input name="evidence" required placeholder={x.money.receiptNote} className="input min-w-48 flex-1" />
                  <button className="btn btn-primary">{x.money.settle}</button>
                </form>
              )}
            </div>
          ))}
        </div>
        <form action={issueAdvance} className="card h-fit space-y-2 p-4">
          <input type="hidden" name="back" value={back} /><input type="hidden" name="idem" value={crypto.randomUUID()} />
          <h2 className="font-semibold">{x.money.issue}</h2>
          <input name="runner" required placeholder={x.money.runner} className="input" />
          <input name="amount" inputMode="numeric" required placeholder={x.money.amount} className="input" />
          <select name="account" className="input">{payFrom.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select>
          <button className="btn btn-primary w-full">{x.money.issue}</button>
        </form>
      </div>
    );
  }

  async function Journal() {
    const { data: entries } = await supabase.from("journal_entries").select("id, ref_no, entry_date, source_type, memo").order("created_at", { ascending: false }).limit(100);
    const ids = (entries ?? []).map((e) => e.id);
    const { data: lines } = ids.length ? await supabase.from("journal_lines").select("entry_id, account_code, debit, credit, money_account_id").in("entry_id", ids) : { data: [] };
    return (
      <div className="card overflow-x-auto">
        <table className="w-full min-w-[720px] text-sm">
          <thead className="bg-ivory text-left text-muted"><tr><th className="px-4 py-2 font-medium">Ref</th><th className="px-4 py-2 font-medium">{x.money.date}</th>
            <th className="px-4 py-2 font-medium">Source</th><th className="px-4 py-2 font-medium">Account</th><th className="px-4 py-2 text-right font-medium">Dr</th><th className="px-4 py-2 text-right font-medium">Cr</th></tr></thead>
          <tbody>
            {(entries ?? []).map((e) => (lines ?? []).filter((l) => l.entry_id === e.id).map((l, i) => (
              <tr key={`${e.id}-${i}`} className={i === 0 ? "border-t border-line" : ""}>
                <td className="px-4 py-1 font-mono text-xs">{i === 0 ? e.ref_no : ""}</td><td className="px-4 py-1">{i === 0 ? e.entry_date : ""}</td>
                <td className="px-4 py-1 text-xs text-muted">{i === 0 ? `${e.source_type} ${e.memo ?? ""}` : ""}</td>
                <td className="px-4 py-1">{l.account_code}{l.money_account_id && <span className="text-xs text-muted"> {accName.get(l.money_account_id)}</span>}</td>
                <td className="px-4 py-1 text-right tabular-nums">{l.debit ? l.debit.toLocaleString("en-US") : ""}</td>
                <td className="px-4 py-1 text-right tabular-nums">{l.credit ? l.credit.toLocaleString("en-US") : ""}</td>
              </tr>
            )))}
          </tbody>
        </table>
      </div>
    );
  }
}
