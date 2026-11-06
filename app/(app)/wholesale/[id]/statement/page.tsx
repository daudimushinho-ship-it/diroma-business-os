import { notFound } from "next/navigation";
import { PrintButton } from "@/components/PrintButton";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { db } from "@/lib/stock";
import { partnerOverview } from "@/lib/wholesale";
import { addDays, businessToday, tzs } from "@/lib/format";

type Row = { entry_date: string; ref_no: string | null; source_type: string; memo: string | null; debit: number; credit: number; balance: number; is_opening: boolean };

/** Printable partner statement (use the browser's "Save as PDF"). Server-generated PDF files come with Milestone E. */
export default async function StatementPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ from?: string; to?: string }> }) {
  const ws = await requireWorkspace("wholesale.manage");
  const { x } = await getSalesDict();
  const w = x.wholesale;
  const { id } = await params;
  const sp = await searchParams;
  const to = sp.to && /^\d{4}-\d{2}-\d{2}$/.test(sp.to) ? sp.to : businessToday();
  const from = sp.from && /^\d{4}-\d{2}-\d{2}$/.test(sp.from) ? sp.from : addDays(to, -30);
  const [p] = await partnerOverview(id);
  if (!p) notFound();
  const supabase = await db();
  const { data } = await supabase.rpc("customer_statement", { p_customer: id, p_from: from, p_to: to });
  const rows = ((data ?? []) as Row[]).map((r) => ({ ...r, debit: Number(r.debit), credit: Number(r.credit), balance: Number(r.balance) }))
    .sort((a, b) => (a.is_opening === b.is_opening ? 0 : a.is_opening ? -1 : 1));
  const closing = rows.length ? rows[rows.length - 1].balance : 0;
  return (
    <div className="mx-auto max-w-4xl">
      <form className="mb-4 flex flex-wrap items-end gap-2 print:hidden">
        <label><span className="label">{w.from}</span><input type="date" name="from" defaultValue={from} className="input" /></label>
        <label><span className="label">{w.to}</span><input type="date" name="to" defaultValue={to} className="input" /></label>
        <button className="btn btn-ghost">OK</button><PrintButton label="PDF / Print" />
      </form>
      <article className="card p-6 text-sm print:border-0 print:p-0">
        <header className="flex flex-wrap justify-between gap-4 border-b border-line pb-4">
          <div><p className="text-xl font-bold tracking-[0.3em]">DIROMA</p><p className="text-xs text-muted">Spirit of Fashion · Kariakoo, Dar es Salaam</p></div>
          <div className="text-right"><p className="font-semibold">{w.statement}</p><p>{p.name}</p><p className="text-xs text-muted">{p.phone} · {p.region}</p>
            <p className="text-xs">{from} → {to} · Africa/Dar_es_Salaam · TZS</p></div>
        </header>
        <table className="mt-4 w-full">
          <thead className="text-left text-muted"><tr><th className="py-1 font-medium">{x.sales.date}</th><th className="py-1 font-medium">Ref</th><th className="py-1 font-medium">—</th>
            <th className="py-1 text-right font-medium">{w.debit}</th><th className="py-1 text-right font-medium">{w.creditCol}</th><th className="py-1 text-right font-medium">{w.balance}</th></tr></thead>
          <tbody className="tabular-nums">
            {rows.map((r, i) => (
              <tr key={i} className="border-t border-line">
                <td className="py-1">{r.entry_date}</td><td className="py-1 font-mono text-xs">{r.ref_no ?? ""}</td>
                <td className="py-1 text-xs">{r.is_opening ? w.opening : `${r.source_type}${r.memo ? ` · ${r.memo}` : ""}`}</td>
                <td className="py-1 text-right">{r.debit ? r.debit.toLocaleString("en-US") : ""}</td>
                <td className="py-1 text-right">{r.credit ? r.credit.toLocaleString("en-US") : ""}</td>
                <td className="py-1 text-right font-semibold">{r.balance.toLocaleString("en-US")}</td>
              </tr>
            ))}
          </tbody>
          <tfoot><tr className="border-t-2 border-line font-bold"><td colSpan={5} className="py-2">{w.closing}</td><td className="py-2 text-right">{tzs(closing)}</td></tr></tfoot>
        </table>
        <p className="mt-4 text-xs text-muted">{w.held}: {p.held} pcs ({tzs(p.held_value)}) — {w.noRevenue}</p>
        <p className="mt-1 text-xs text-muted">Generated {new Date().toISOString()} by {ws.display_name}</p>
      </article>
    </div>
  );
}
