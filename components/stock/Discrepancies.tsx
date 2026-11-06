import { db, locationDirectory, variantLabels, variantText } from "@/lib/stock";
import { resolveDiscrepancy } from "@/app/actions/stock";
import type { StockDict } from "@/lib/i18n-stock";
import type { Workspace } from "@/lib/roles";

export async function Discrepancies({ ws, s, back }: { ws: Workspace; s: StockDict; back: string }) {
  const supabase = await db();
  const { data: rows } = await supabase.from("transfer_discrepancies")
    .select("id, qty, status, resolution, reason, created_at, transfer_lines(variant_id, transfers(ref_no, from_location, to_location))")
    .order("created_at", { ascending: false }).limit(100);
  type R = { id: string; qty: number; status: string; resolution: string | null; reason: string | null;
    transfer_lines: { variant_id: string; transfers: { ref_no: string; from_location: string; to_location: string } } };
  const list = (rows ?? []) as unknown as R[];
  const labels = await variantLabels(list.map((r) => r.transfer_lines.variant_id));
  const locs = await locationDirectory();
  const canResolve = ws.permissions.includes("stock.approve");
  if (!list.length) return <p className="card p-6 text-sm text-muted">{s.noData}</p>;
  return (
    <div className="space-y-3">
      {list.map((d) => (
        <article key={d.id} className="card p-4">
          <p className="text-sm"><strong>{d.transfer_lines.transfers.ref_no}</strong> · {variantText(labels.get(d.transfer_lines.variant_id))} ·{" "}
            <span className="text-bad">−{d.qty} pcs</span> · {locs.get(d.transfer_lines.transfers.from_location)?.name} → {locs.get(d.transfer_lines.transfers.to_location)?.name}</p>
          {d.status === "resolved" ? (
            <p className="mt-1 text-xs text-muted">{d.resolution} — {d.reason}</p>
          ) : canResolve ? (
            <form action={resolveDiscrepancy} className="mt-3 flex flex-wrap items-end gap-2">
              <input type="hidden" name="disc" value={d.id} /><input type="hidden" name="back" value={back} />
              <label><span className="label">{s.store.resolve}</span>
                <select name="resolution" className="input">
                  <option value="found_delivered">{s.store.foundDelivered}</option>
                  <option value="returned_to_source">{s.store.returned}</option>
                  <option value="written_off">{s.store.writtenOff}</option>
                </select></label>
              <label className="min-w-48 flex-1"><span className="label">{s.reason}</span><input name="reason" required className="input" /></label>
              <button className="btn btn-primary">{s.store.resolve}</button>
            </form>
          ) : <p className="mt-1 text-xs text-warn">open</p>}
        </article>
      ))}
    </div>
  );
}
