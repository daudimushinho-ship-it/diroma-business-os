import { db, locationDirectory, variantLabels, variantText } from "@/lib/stock";
import { decideRequisition, dispatchRequisition } from "@/app/actions/stock";
import type { StockDict } from "@/lib/i18n-stock";
import type { Workspace } from "@/lib/roles";

const OPEN = ["submitted", "approved", "partially_dispatched"];

export async function Requisitions({ ws, locationId, side, s, back }: {
  ws: Workspace; locationId: string; side: "from" | "to"; s: StockDict; back: string;
}) {
  const supabase = await db();
  const { data: reqs } = await supabase.from("requisitions")
    .select("id, ref_no, status, from_location, to_location, requested_by, notes, created_at")
    .eq(side === "from" ? "from_location" : "to_location", locationId).order("created_at", { ascending: false }).limit(50);
  const ids = (reqs ?? []).map((r) => r.id);
  const { data: lines } = ids.length ? await supabase.from("requisition_lines").select("id, requisition_id, variant_id, qty_requested, qty_approved, qty_dispatched").in("requisition_id", ids) : { data: [] };
  const labels = await variantLabels((lines ?? []).map((l) => l.variant_id));
  const locs = await locationDirectory();
  const canApprove = ws.permissions.includes("stock.approve");
  const canDispatch = ws.permissions.includes("store.operate") && side === "from";
  if (!reqs?.length) return <p className="card p-6 text-sm text-muted">{s.noData}</p>;
  return (
    <div className="space-y-4">
      {reqs.map((r) => {
        const ls = (lines ?? []).filter((l) => l.requisition_id === r.id);
        const decide = canApprove && r.status === "submitted" && r.requested_by !== ws.membership_id;
        const dispatch = canDispatch && (r.status === "approved" || r.status === "partially_dispatched");
        return (
          <article key={r.id} className={`card p-4 ${OPEN.includes(r.status) ? "" : "opacity-75"}`}>
            <div className="mb-2 flex flex-wrap items-baseline justify-between gap-2">
              <p className="font-semibold">{r.ref_no} <span className="font-normal text-muted">· {locs.get(r.from_location)?.name} → {locs.get(r.to_location)?.name}</span></p>
              <span className="badge border border-line bg-ivory">{r.status}</span>
            </div>
            {r.notes && <p className="mb-2 text-sm text-muted">{r.notes}</p>}
            <form action={decide ? decideRequisition : dispatchRequisition}>
              <input type="hidden" name="req" value={r.id} /><input type="hidden" name="back" value={back} />
              <input type="hidden" name="idem" value={crypto.randomUUID()} />
              <table className="w-full text-sm">
                <thead className="text-left text-muted"><tr>
                  <th className="py-1 font-medium">{s.variants}</th><th className="py-1 font-medium">{s.store.requested}</th>
                  <th className="py-1 font-medium">{s.store.approved}</th><th className="py-1 font-medium">{s.store.dispatched}</th>
                  {(decide || dispatch) && <th className="py-1" />}</tr></thead>
                <tbody>
                  {ls.map((l) => (
                    <tr key={l.id} className="border-t border-line">
                      <td className="py-1.5">{variantText(labels.get(l.variant_id))}</td>
                      <td className="tabular-nums">{l.qty_requested}</td><td className="tabular-nums">{l.qty_approved}</td><td className="tabular-nums">{l.qty_dispatched}</td>
                      {decide && <td><input name={`a_${l.id}`} type="number" min={0} max={l.qty_requested} defaultValue={l.qty_requested} className="h-9 w-20 rounded-md border border-line px-2" aria-label={s.store.approved} /></td>}
                      {dispatch && <td>
                        <input type="hidden" name={`v_${l.id}`} value={l.variant_id} />
                        <input name={`d_${l.id}`} type="number" min={0} max={l.qty_approved - l.qty_dispatched} defaultValue={l.qty_approved - l.qty_dispatched} className="h-9 w-20 rounded-md border border-line px-2" aria-label={s.store.dispatch} />
                      </td>}
                    </tr>
                  ))}
                </tbody>
              </table>
              {decide && (
                <div className="mt-3 flex flex-wrap items-end gap-2">
                  <label className="min-w-48 flex-1"><span className="label">{s.reason}</span><input name="note" className="input" /></label>
                  <button name="decision" value="approve" className="btn btn-primary">{s.store.approve}</button>
                  <button name="decision" value="reject" className="btn btn-danger">{s.store.reject}</button>
                </div>
              )}
              {dispatch && <button className="btn btn-primary mt-3">{s.store.dispatch}</button>}
            </form>
          </article>
        );
      })}
    </div>
  );
}
