import Link from "next/link";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { can } from "@/lib/roles";
import { db, variantLabels, variantText } from "@/lib/stock";
import { moneyAccounts, myShift } from "@/lib/sales";
import { tzs } from "@/lib/format";
import { payRefund, requestReturn, setFulfillment } from "@/app/actions/sales";

export default async function SaleDetail({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ ok?: string; err?: string }> }) {
  const ws = await requireWorkspace("sales.view");
  const { x } = await getSalesDict();
  const { id } = await params;
  const sp = await searchParams;
  const supabase = await db();
  const { data: sale } = await supabase.from("sales").select("id, ref_no, sold_at, entered_at, total, payment_status, fulfillment_status, customer_id, channel, note, source").eq("id", id).maybeSingle();
  if (!sale) notFound();
  const [{ data: lines }, { data: settl }, { data: returns }] = await Promise.all([
    supabase.from("sale_lines").select("id, variant_id, qty, list_price, discount, line_total").eq("sale_id", id),
    supabase.from("sale_settlements").select("id, kind, amount, created_at").eq("sale_id", id),
    supabase.from("sale_returns").select("id, ref_no, status, settlement, amount, credit_amount, refunded, reason").eq("sale_id", id),
  ]);
  const labels = await variantLabels((lines ?? []).map((l) => l.variant_id));
  const back = `/sales/${id}`;
  const shift = await myShift();
  const accounts = (await moneyAccounts()).filter((a) => a.kind !== "cash" || a.id === shift?.cash_account_id);
  const fmt = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeStyle: "short", timeZone: ws.business.timezone });
  return (
    <div className="mx-auto max-w-4xl space-y-5">
      <PageHeader title={`${x.sales.receipt} ${sale.ref_no}`} subtitle={`${fmt.format(new Date(sale.sold_at))} · ${sale.payment_status} · ${sale.fulfillment_status}`}>
        <Link href={`/pos/receipt/${id}`} className="btn btn-ghost">{x.pos.printReceipt}</Link>
      </PageHeader>
      <Flash ok={sp.ok} err={sp.err} />
      <section className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-ivory text-left text-muted"><tr><th className="px-4 py-2 font-medium">{x.sales.lines}</th><th className="px-4 py-2 font-medium">{x.sales.qty}</th>
            <th className="px-4 py-2 text-right font-medium">{x.sales.price}</th><th className="px-4 py-2 text-right font-medium">{x.sales.lineTotal}</th></tr></thead>
          <tbody className="divide-y divide-line">
            {(lines ?? []).map((l) => <tr key={l.id}><td className="px-4 py-2">{variantText(labels.get(l.variant_id))}</td><td className="px-4 py-2">{l.qty}</td>
              <td className="px-4 py-2 text-right">{tzs(l.list_price)}{l.discount > 0 && <span className="text-xs text-muted"> − {tzs(l.discount)}</span>}</td>
              <td className="px-4 py-2 text-right">{tzs(l.line_total)}</td></tr>)}
          </tbody>
          <tfoot className="border-t border-line font-semibold"><tr><td className="px-4 py-2" colSpan={3}>{x.pos.total}</td><td className="px-4 py-2 text-right">{tzs(sale.total)}</td></tr></tfoot>
        </table>
      </section>
      <section className="card p-4 text-sm">
        <h2 className="mb-2 font-semibold">{x.sales.settlements}</h2>
        <ul>{(settl ?? []).map((s) => <li key={s.id} className="flex justify-between py-1"><span>{s.kind}</span><span className="tabular-nums">{tzs(s.amount)}</span></li>)}</ul>
      </section>
      {(sale.fulfillment_status === "awaiting_delivery" || sale.fulfillment_status === "failed_delivery") && can(ws, "pos.sell") && (
        <form action={setFulfillment} className="card flex flex-wrap items-end gap-2 p-4">
          <input type="hidden" name="sale" value={id} /><input type="hidden" name="back" value={back} />
          <label className="min-w-48 flex-1"><span className="label">{x.sales.fulfilment}</span><input name="note" className="input" placeholder={x.sales.reason} /></label>
          <button name="status" value="delivered" className="btn btn-primary">{x.sales.markDelivered}</button>
          <button name="status" value="failed_delivery" className="btn btn-danger">{x.sales.markFailed}</button>
          <p className="w-full text-xs text-muted">{x.sales.deliveryNote}</p>
        </form>
      )}
      {(returns ?? []).length > 0 && (
        <section className="card p-4 text-sm">
          <h2 className="mb-2 font-semibold">{x.sales.returns}</h2>
          {(returns ?? []).map((r) => (
            <div key={r.id} className="border-t border-line py-2 first:border-0">
              <p><strong>{r.ref_no}</strong> · {r.status} · {tzs(r.amount)} · {r.reason}</p>
              {r.status === "approved" && r.credit_amount > r.refunded && r.settlement === "refund" && can(ws, "refunds.pay") && (
                <form action={payRefund} className="mt-2 flex flex-wrap items-end gap-2">
                  <input type="hidden" name="return" value={r.id} /><input type="hidden" name="back" value={back} /><input type="hidden" name="idem" value={crypto.randomUUID()} />
                  <select name="account" className="input w-auto">{accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select>
                  <input name="amount" inputMode="numeric" defaultValue={r.credit_amount - r.refunded} className="input w-36" />
                  <input name="ref" placeholder={x.pos.providerRef} className="input w-44" />
                  <button className="btn btn-primary">{x.sales.refund}</button>
                </form>
              )}
            </div>
          ))}
        </section>
      )}
      {can(ws, "returns.request") && (
        <form action={requestReturn} className="card space-y-3 p-4">
          <input type="hidden" name="sale" value={id} /><input type="hidden" name="back" value={back} /><input type="hidden" name="idem" value={crypto.randomUUID()} />
          <h2 className="font-semibold">{x.sales.requestReturn}</h2>
          {(lines ?? []).map((l) => (
            <label key={l.id} className="flex items-center justify-between gap-2 text-sm">
              <span>{variantText(labels.get(l.variant_id))} (≤ {l.qty})</span>
              <input name={`rq_${l.id}`} type="number" min={0} max={l.qty} className="h-9 w-20 rounded-md border border-line px-2" aria-label={x.sales.returnQty} />
            </label>
          ))}
          <div className="flex flex-wrap items-end gap-2">
            <label><span className="label">{x.sales.settlement}</span>
              <select name="settlement" className="input">{sale.customer_id && <option value="credit">{x.sales.credit}</option>}<option value="refund">{x.sales.refund}</option></select></label>
            <label className="min-w-48 flex-1"><span className="label">{x.sales.reason}</span><input name="reason" required className="input" /></label>
            <button className="btn btn-primary">{x.sales.requestReturn}</button>
          </div>
        </form>
      )}
    </div>
  );
}
