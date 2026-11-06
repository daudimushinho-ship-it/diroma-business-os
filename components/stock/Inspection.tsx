import { db, variantLabels, variantText } from "@/lib/stock";
import { releaseInspection } from "@/app/actions/sales";
import type { SalesDict } from "@/lib/i18n-sales";

/** Returned goods waiting in INSPECTION: restock to the selling shop, or quarantine as damaged. */
export async function Inspection({ x, back }: { x: SalesDict; back: string }) {
  const supabase = await db();
  const { data: rets } = await supabase.from("sale_returns").select("id, ref_no, reason").eq("status", "approved");
  const ids = (rets ?? []).map((r) => r.id);
  const { data: lines } = ids.length ? await supabase.from("sale_return_lines").select("id, return_id, variant_id, qty, released_qty").in("return_id", ids) : { data: [] };
  const open = (lines ?? []).filter((l) => l.qty > l.released_qty);
  const labels = await variantLabels(open.map((l) => l.variant_id));
  if (!open.length) return <p className="card p-6 text-sm text-muted">—</p>;
  return (
    <div className="space-y-3">
      {open.map((l) => {
        const r = (rets ?? []).find((y) => y.id === l.return_id);
        return (
          <form key={l.id} action={releaseInspection} className="card flex flex-wrap items-end gap-2 p-4 text-sm">
            <input type="hidden" name="line" value={l.id} /><input type="hidden" name="back" value={back} /><input type="hidden" name="idem" value={crypto.randomUUID()} />
            <p className="w-full"><strong>{r?.ref_no}</strong> · {variantText(labels.get(l.variant_id))} · {l.qty - l.released_qty} pcs · <span className="text-muted">{r?.reason}</span></p>
            <input name="qty" type="number" min={1} max={l.qty - l.released_qty} defaultValue={l.qty - l.released_qty} className="h-10 w-20 rounded-md border border-line px-2" />
            <select name="outcome" className="input w-auto"><option value="restock">{x.inspection.restock}</option><option value="quarantine">{x.inspection.quarantine}</option></select>
            <input name="reason" required placeholder={x.inspection.reason} className="input min-w-48 flex-1" />
            <button className="btn btn-primary">OK</button>
          </form>
        );
      })}
    </div>
  );
}
