import { db, variantLabels, variantText } from "@/lib/stock";
import { dispatchConsignment } from "@/app/actions/wholesale";
import type { SalesDict } from "@/lib/i18n-sales";
import type { Workspace } from "@/lib/roles";

/** Store side: approved consignment orders from this location, handed over to the partner. */
export async function ConsignmentDispatch({ ws, x, locationId, back }: { ws: Workspace; x: SalesDict; locationId: string; back: string }) {
  const w = x.wholesale;
  const supabase = await db();
  const { data: orders } = await supabase.from("consignment_orders").select("id, ref_no, partner_id, status, created_by, notes")
    .eq("source_location", locationId).in("status", ["approved", "partially_dispatched"]).order("created_at");
  const ids = (orders ?? []).map((o) => o.id);
  const { data: lines } = ids.length ? await supabase.from("consignment_order_lines").select("id, order_id, variant_id, qty_ordered, qty_dispatched").in("order_id", ids) : { data: [] };
  const { data: names } = await supabase.from("customers").select("id, name").in("id", (orders ?? []).map((o) => o.partner_id));
  const pname = new Map((names ?? []).map((c) => [c.id, c.name]));
  const labels = await variantLabels((lines ?? []).map((l) => l.variant_id));
  if (!orders?.length) return <p className="card p-6 text-sm text-muted">—</p>;
  return (
    <div className="space-y-4">
      <p className="text-xs text-muted">{w.noRevenue}</p>
      {orders.map((o) => {
        const own = o.created_by === ws.membership_id;
        return (
          <form key={o.id} action={dispatchConsignment} className="card space-y-2 p-4 text-sm">
            <input type="hidden" name="order" value={o.id} /><input type="hidden" name="back" value={back} /><input type="hidden" name="idem" value={crypto.randomUUID()} />
            <p className="font-semibold">{o.ref_no} → {pname.get(o.partner_id) ?? w.partner} <span className="font-normal text-muted">{o.notes}</span></p>
            {(lines ?? []).filter((l) => l.order_id === o.id && l.qty_dispatched < l.qty_ordered).map((l) => (
              <label key={l.id} className="flex items-center justify-between gap-2 border-t border-line pt-1.5">
                <span>{variantText(labels.get(l.variant_id))} · {l.qty_ordered - l.qty_dispatched}</span>
                <input name={`d_${l.id}`} type="number" min={0} max={l.qty_ordered - l.qty_dispatched} defaultValue={l.qty_ordered - l.qty_dispatched}
                  className="h-9 w-20 rounded-md border border-line px-2" aria-label={w.dispatch} />
              </label>
            ))}
            <div className="flex flex-wrap items-end gap-2">
              <label className="min-w-40 flex-1"><span className="label">{w.recipient}</span><input name="recipient" required className="input" /></label>
              <label className="min-w-40 flex-1"><span className="label">{w.evidence}</span><input name="evidence" className="input" /></label>
              {own && ws.role === "owner" && <label className="min-w-40 flex-1"><span className="label">{w.override}</span><input name="override" className="input" /></label>}
              <button className="btn btn-primary" disabled={own && ws.role !== "owner"}>{w.dispatch}</button>
            </div>
          </form>
        );
      })}
    </div>
  );
}
