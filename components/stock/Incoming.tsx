import { db, locationDirectory, variantLabels, variantText } from "@/lib/stock";
import { receiveTransfer } from "@/app/actions/stock";
import type { StockDict } from "@/lib/i18n-stock";
import type { Workspace } from "@/lib/roles";

/** Transfers on their way to this location; the receiver confirms actual quantities. */
export async function Incoming({ ws, locationId, s, back }: { ws: Workspace; locationId: string; s: StockDict; back: string }) {
  const supabase = await db();
  const { data: transfers } = await supabase.from("transfers").select("id, ref_no, from_location, dispatched_at, dispatched_by, notes")
    .eq("to_location", locationId).eq("status", "in_transit").order("dispatched_at");
  const ids = (transfers ?? []).map((t) => t.id);
  const { data: lines } = ids.length ? await supabase.from("transfer_lines").select("id, transfer_id, variant_id, qty_sent").in("transfer_id", ids) : { data: [] };
  const labels = await variantLabels((lines ?? []).map((l) => l.variant_id));
  const locs = await locationDirectory();
  const canConfirm = ws.permissions.includes("stock.confirm_receipt");
  if (!transfers?.length) return <p className="card p-6 text-sm text-muted">{s.noData}</p>;
  return (
    <div className="space-y-4">
      {transfers.map((t) => (
        <form key={t.id} action={receiveTransfer} className="card p-4">
          <input type="hidden" name="transfer" value={t.id} /><input type="hidden" name="idem" value={crypto.randomUUID()} />
          <input type="hidden" name="back" value={back} />
          <div className="mb-3 flex flex-wrap items-baseline justify-between gap-2">
            <p className="font-semibold">{t.ref_no} <span className="font-normal text-muted">· {s.store.fromLoc}: {locs.get(t.from_location)?.name ?? "—"}</span></p>
            <p className="text-xs text-muted">{new Date(t.dispatched_at).toLocaleString("en-GB", { timeZone: ws.business.timezone })}</p>
          </div>
          <table className="w-full text-sm">
            <thead className="text-left text-muted"><tr><th className="py-1 font-medium">{s.variants}</th><th className="py-1 font-medium">{s.store.dispatched}</th><th className="py-1 font-medium">{s.store.received}</th></tr></thead>
            <tbody>
              {(lines ?? []).filter((l) => l.transfer_id === t.id).map((l) => (
                <tr key={l.id} className="border-t border-line">
                  <td className="py-1.5">{variantText(labels.get(l.variant_id))}</td>
                  <td className="py-1.5 tabular-nums">{l.qty_sent}</td>
                  <td className="py-1.5">{canConfirm ? <input name={`rcv_${l.id}`} type="number" min={0} max={l.qty_sent} defaultValue={l.qty_sent} required className="h-9 w-20 rounded-md border border-line px-2" aria-label={s.store.received} /> : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {canConfirm && (
            <div className="mt-3 flex flex-wrap items-end gap-2">
              {t.dispatched_by === ws.membership_id && ws.role === "owner" && (
                <label className="min-w-56 flex-1"><span className="label">{s.store.overrideReason}</span><input name="override" className="input" /></label>
              )}
              <button className="btn btn-primary">{s.store.confirmReceipt}</button>
            </div>
          )}
        </form>
      ))}
    </div>
  );
}
