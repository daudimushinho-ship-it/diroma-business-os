import { VariantMatrix } from "@/components/VariantMatrix";
import { DesignPicker } from "./DesignPicker";
import { db, getDesign } from "@/lib/stock";
import { receiveGoods } from "@/app/actions/stock";
import type { StockDict } from "@/lib/i18n-stock";

export async function Receive({ locationId, s, po, design, back }: { locationId: string; s: StockDict; po?: string; design?: string; back: string }) {
  const supabase = await db();
  const { data: pos } = await supabase.rpc("po_open_list");
  const { data: suppliers } = await supabase.from("suppliers").select("id, name").eq("is_active", true).order("name");
  const poLines = po ? ((await supabase.rpc("po_expected_lines", { p_po: po })).data ?? []) as
    { line_id: string; variant_id: string; design_code: string; design_name: string; color: string; size: string; qty_ordered: number; qty_received: number }[] : [];
  const d = design ? await getDesign(design) : null;
  const keep = { loc: locationId, tab: "receive" };
  return (
    <div className="space-y-5">
      <section className="card p-4">
        <h3 className="mb-2 font-semibold">{s.store.fromPo}</h3>
        {(pos ?? []).length === 0 ? <p className="text-sm text-muted">{s.noData}</p> : (
          <ul className="flex flex-wrap gap-2">
            {(pos as { po_id: string; ref_no: string; supplier: string; status: string }[]).map((p) => (
              <li key={p.po_id}><a href={`?loc=${locationId}&tab=receive&po=${p.po_id}`}
                className={`inline-block rounded-full border px-3 py-1 text-sm ${p.po_id === po ? "border-espresso bg-espresso text-ivory" : "border-line"}`}>
                {p.ref_no} · {p.supplier} <span className="opacity-70">({p.status})</span></a></li>
            ))}
          </ul>
        )}
      </section>
      {po && poLines.length > 0 && (
        <form action={receiveGoods} className="card p-4">
          <input type="hidden" name="idem" value={crypto.randomUUID()} /><input type="hidden" name="location" value={locationId} />
          <input type="hidden" name="po" value={po} /><input type="hidden" name="back" value={back} />
          <table className="w-full text-sm">
            <thead className="text-left text-muted"><tr><th className="py-1 font-medium">{s.variants}</th><th className="py-1 font-medium">{s.store.expected}</th><th className="py-1 font-medium">{s.store.received}</th></tr></thead>
            <tbody>
              {poLines.map((l) => {
                const remaining = l.qty_ordered - l.qty_received;
                return (
                  <tr key={l.line_id} className="border-t border-line">
                    <td className="py-1.5">{l.design_code} · {l.color} · {l.size}</td>
                    <td className="tabular-nums">{remaining} <span className="text-xs text-muted">/ {l.qty_ordered}</span><input type="hidden" name={`e_${l.variant_id}`} value={remaining} /></td>
                    <td><input name={`r_${l.variant_id}`} type="number" min={0} max={remaining} className="h-9 w-20 rounded-md border border-line px-2" aria-label={s.store.received} /></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <ReceiptFooter s={s} />
        </form>
      )}
      <section className="card space-y-3 p-4">
        <h3 className="font-semibold">{s.store.noPo}</h3>
        <DesignPicker label={s.choose} keep={keep} selected={design} />
        {d?.design && (
          <form action={receiveGoods} className="space-y-3">
            <input type="hidden" name="idem" value={crypto.randomUUID()} /><input type="hidden" name="location" value={locationId} />
            <input type="hidden" name="back" value={back} />
            <VariantMatrix variants={d.variants} inputPrefix="r_" />
            <label className="block max-w-sm"><span className="label">{s.supplier}</span>
              <select name="supplier" className="input" defaultValue={d.design.supplier_id ?? ""}>
                <option value="">—</option>
                {(suppliers ?? []).map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
              </select></label>
            <ReceiptFooter s={s} />
          </form>
        )}
      </section>
    </div>
  );
}

function ReceiptFooter({ s }: { s: StockDict }) {
  return (
    <div className="mt-3 flex flex-wrap items-end gap-2">
      <label className="min-w-48"><span className="label">{s.store.supplierRef}</span><input name="supplier_ref" className="input" /></label>
      <label className="min-w-48 flex-1"><span className="label">{s.notes}</span><input name="notes" className="input" /></label>
      <button className="btn btn-primary">{s.store.postReceipt}</button>
    </div>
  );
}
