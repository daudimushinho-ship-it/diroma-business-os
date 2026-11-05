import { notFound } from "next/navigation";
import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { getStockDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { db, variantLabels, variantText } from "@/lib/stock";
import { approveCosts } from "@/app/actions/stock";

export default async function ReceiptCostsPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ err?: string }> }) {
  await requireWorkspace("costs.approve");
  const { s } = await getStockDict();
  const { id } = await params;
  const { err } = await searchParams;
  const supabase = await db();
  const { data: g } = await supabase.from("goods_receipts").select("id, ref_no, po_id, supplier_ref, cost_status").eq("id", id).maybeSingle();
  if (!g) notFound();
  const { data: lines } = await supabase.from("goods_receipt_lines").select("id, variant_id, qty_received").eq("receipt_id", id);
  // Suggested unit cost from the PO price × fx rate (Owner confirms or edits).
  const suggestions = new Map<string, number>();
  if (g.po_id) {
    const [{ data: po }, { data: pol }] = await Promise.all([
      supabase.from("purchase_orders").select("fx_rate").eq("id", g.po_id).maybeSingle(),
      supabase.from("purchase_order_lines").select("variant_id, unit_price_fx").eq("po_id", g.po_id),
    ]);
    for (const l of pol ?? []) if (l.unit_price_fx != null && po) suggestions.set(l.variant_id, Math.round(Number(l.unit_price_fx) * Number(po.fx_rate)));
  }
  const labels = await variantLabels((lines ?? []).map((l) => l.variant_id));
  return (
    <div className="mx-auto max-w-4xl">
      <PageHeader title={`${s.purchasing.approveCosts} · ${g.ref_no}`} subtitle={g.supplier_ref ?? undefined} />
      <Flash err={err} />
      {g.cost_status === "approved" ? <p className="card p-6 text-sm">✓</p> : (
        <form action={approveCosts} className="card space-y-4 p-5">
          <input type="hidden" name="receipt" value={g.id} /><input type="hidden" name="back" value={`/purchasing/receipts/${g.id}`} />
          <p className="text-sm text-muted">{s.purchasing.costNote}</p>
          <table className="w-full text-sm">
            <thead className="text-left text-muted"><tr><th className="py-1 font-medium">{s.variants}</th><th className="py-1 font-medium">{s.store.received}</th><th className="py-1 font-medium">{s.purchasing.unitCost}</th></tr></thead>
            <tbody>
              {(lines ?? []).filter((l) => l.qty_received > 0).map((l) => (
                <tr key={l.id} className="border-t border-line">
                  <td className="py-1.5">{variantText(labels.get(l.variant_id))}</td><td className="tabular-nums">{l.qty_received}</td>
                  <td><input name={`c_${l.id}`} required inputMode="numeric" defaultValue={suggestions.get(l.variant_id) ?? ""} className="h-9 w-32 rounded-md border border-line px-2" /></td>
                </tr>
              ))}
            </tbody>
          </table>
          <fieldset className="space-y-2">
            <legend className="label">{s.purchasing.extras}</legend>
            {[0, 1, 2].map((i) => (
              <div key={i} className="flex flex-wrap gap-2">
                <input name={`xl_${i}`} placeholder={s.purchasing.label} className="input max-w-xs" defaultValue={["Freight", "Duty / TRA", "Clearing"][i]} />
                <input name={`xa_${i}`} placeholder={s.purchasing.amount} inputMode="numeric" className="input max-w-40" />
              </div>
            ))}
          </fieldset>
          <div className="flex flex-wrap items-end gap-3">
            <label><span className="label">{s.purchasing.allocation}</span>
              <select name="allocation" className="input"><option value="value">{s.purchasing.byValue}</option><option value="qty">{s.purchasing.byQty}</option></select></label>
            <label className="min-w-48 flex-1"><span className="label">{s.reason}</span><input name="reason" className="input" /></label>
            <button className="btn btn-primary">{s.purchasing.approveCosts}</button>
          </div>
        </form>
      )}
    </div>
  );
}
