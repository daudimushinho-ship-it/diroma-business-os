import { db, variantLabels, variantText } from "@/lib/stock";
import { decideCount, startCount, submitCount } from "@/app/actions/stock";
import type { StockDict } from "@/lib/i18n-stock";
import type { Workspace } from "@/lib/roles";

export async function Counts({ ws, locationId, s, back }: { ws: Workspace; locationId: string; s: StockDict; back: string }) {
  const supabase = await db();
  const { data: counts } = await supabase.from("stock_counts").select("id, ref_no, status, started_by, submitted_by, started_at")
    .eq("location_id", locationId).order("started_at", { ascending: false }).limit(20);
  const open = (counts ?? []).find((c) => c.status === "open");
  const submitted = (counts ?? []).filter((c) => c.status === "submitted");
  const canApprove = ws.permissions.includes("stock.approve");
  const { data: sheet } = open ? await supabase.rpc("count_sheet", { p_count: open.id }) : { data: null };
  const approvable = canApprove ? submitted.filter((c) => c.started_by !== ws.membership_id && c.submitted_by !== ws.membership_id) : [];
  const { data: approverLines } = approvable.length
    ? await supabase.from("stock_count_lines").select("id, count_id, variant_id, snapshot_qty, counted_qty").in("count_id", approvable.map((c) => c.id))
    : { data: [] };
  const labels = await variantLabels((approverLines ?? []).map((l) => l.variant_id));

  return (
    <div className="space-y-5">
      {!open && (
        <form action={startCount} className="card flex flex-wrap items-center justify-between gap-3 p-4">
          <input type="hidden" name="location" value={locationId} /><input type="hidden" name="back" value={back} />
          <p className="text-sm text-muted">{s.store.blindNote}</p>
          <button className="btn btn-primary">{s.store.startCount}</button>
        </form>
      )}
      {open && (
        <form action={submitCount} className="card p-4">
          <input type="hidden" name="count" value={open.id} /><input type="hidden" name="back" value={back} />
          <h3 className="font-semibold">{s.store.countSheet} · {open.ref_no}</h3>
          <p className="mb-3 text-xs text-muted">{s.store.blindNote}</p>
          <table className="w-full text-sm">
            <thead className="text-left text-muted"><tr><th className="py-1 font-medium">{s.variants}</th><th className="py-1 font-medium">{s.barcode}</th><th className="py-1 font-medium">{s.store.counted}</th></tr></thead>
            <tbody>
              {((sheet ?? []) as { line_id: string; design_code: string; color: string; size: string; barcode: string; counted_qty: number | null }[]).map((l) => (
                <tr key={l.line_id} className="border-t border-line">
                  <td className="py-1.5">{l.design_code} · {l.color} · {l.size}</td>
                  <td className="font-mono text-xs">{l.barcode}</td>
                  <td><input name={`cnt_${l.line_id}`} type="number" min={0} required defaultValue={l.counted_qty ?? ""} className="h-9 w-20 rounded-md border border-line px-2" aria-label={s.store.counted} /></td>
                </tr>
              ))}
            </tbody>
          </table>
          <button className="btn btn-primary mt-3">{s.store.submitCount}</button>
        </form>
      )}
      {approvable.map((c) => (
        <form key={c.id} action={decideCount} className="card p-4">
          <input type="hidden" name="count" value={c.id} /><input type="hidden" name="back" value={back} />
          <h3 className="mb-2 font-semibold">{s.store.approveCount} · {c.ref_no}</h3>
          <table className="w-full text-sm">
            <thead className="text-left text-muted"><tr><th className="py-1 font-medium">{s.variants}</th><th className="py-1 font-medium">{s.store.system} (start)</th><th className="py-1 font-medium">{s.store.counted}</th></tr></thead>
            <tbody>
              {(approverLines ?? []).filter((l) => l.count_id === c.id).map((l) => (
                <tr key={l.id} className="border-t border-line">
                  <td className="py-1.5">{variantText(labels.get(l.variant_id))}</td>
                  <td className="tabular-nums">{l.snapshot_qty}</td>
                  <td className={`tabular-nums ${l.counted_qty !== l.snapshot_qty ? "font-semibold text-warn" : ""}`}>{l.counted_qty}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="mt-2 text-xs text-muted">Final variance accounts for movements during the count and is applied to the current balance.</p>
          <div className="mt-3 flex flex-wrap items-end gap-2">
            <label className="min-w-48 flex-1"><span className="label">{s.reason}</span><input name="reason" required className="input" /></label>
            <button name="decision" value="approve" className="btn btn-primary">{s.store.approve}</button>
            <button name="decision" value="reject" className="btn btn-danger">{s.store.reject}</button>
          </div>
        </form>
      ))}
      {submitted.length > approvable.length && <p className="text-sm text-muted">{submitted.length - approvable.length} × submitted — waiting for an independent approver.</p>}
    </div>
  );
}
