import { db } from "@/lib/stock";
import { addDays, businessDayStart, businessToday } from "@/lib/format";
import type { StockDict } from "@/lib/i18n-stock";

type Row = { variant_id: string; design_code: string; design_name: string; color: string; size: string; opening: number; inbound: number; outbound: number; closing: number };

export async function PeriodReport({ locationId, s, from, to, base }: { locationId: string; s: StockDict; from?: string; to?: string; base: string }) {
  const end = to && /^\d{4}-\d{2}-\d{2}$/.test(to) ? to : businessToday();
  const start = from && /^\d{4}-\d{2}-\d{2}$/.test(from) ? from : addDays(end, -6);
  const supabase = await db();
  const { data, error } = await supabase.rpc("stock_period_report", {
    p_location: locationId, p_from: businessDayStart(start), p_to: businessDayStart(addDays(end, 1)),
  });
  const rows = (data ?? []) as Row[];
  const sum = (k: keyof Row) => rows.reduce((a, r) => a + Number(r[k]), 0);
  return (
    <div className="space-y-4">
      <form className="flex flex-wrap items-end gap-2">
        <input type="hidden" name="loc" value={locationId} /><input type="hidden" name="tab" value="reports" />
        <label><span className="label">{s.store.period}</span><input type="date" name="from" defaultValue={start} className="input" /></label>
        <label><span className="label">&nbsp;</span><input type="date" name="to" defaultValue={end} className="input" /></label>
        <button className="btn btn-ghost">OK</button>
        <a className="btn btn-primary" href={`${base}/export?loc=${locationId}&from=${start}&to=${end}`}>{s.store.exportCsv}</a>
      </form>
      {error && <p className="text-sm text-bad">{error.message}</p>}
      <div className="card overflow-x-auto">
        <table className="w-full min-w-[640px] text-sm">
          <thead className="bg-ivory text-left text-muted"><tr>
            <th className="px-4 py-2 font-medium">{s.code}</th><th className="px-4 py-2 font-medium">{s.color}</th><th className="px-4 py-2 font-medium">{s.size}</th>
            <th className="px-4 py-2 text-right font-medium">{s.store.openingQty}</th><th className="px-4 py-2 text-right font-medium">{s.store.inbound}</th>
            <th className="px-4 py-2 text-right font-medium">{s.store.outbound}</th><th className="px-4 py-2 text-right font-medium">{s.store.closing}</th></tr></thead>
          <tbody className="divide-y divide-line tabular-nums">
            {rows.map((r) => (
              <tr key={r.variant_id}>
                <td className="px-4 py-1.5"><span className="font-mono text-xs">{r.design_code}</span> {r.design_name}</td>
                <td className="px-4 py-1.5">{r.color}</td><td className="px-4 py-1.5">{r.size}</td>
                <td className="px-4 py-1.5 text-right">{r.opening}</td><td className="px-4 py-1.5 text-right text-ok">{r.inbound}</td>
                <td className="px-4 py-1.5 text-right text-bad">{r.outbound}</td><td className="px-4 py-1.5 text-right font-semibold">{r.closing}</td>
              </tr>
            ))}
          </tbody>
          <tfoot className="border-t-2 border-line font-semibold tabular-nums"><tr>
            <td className="px-4 py-2" colSpan={3}>Σ</td><td className="px-4 py-2 text-right">{sum("opening")}</td>
            <td className="px-4 py-2 text-right">{sum("inbound")}</td><td className="px-4 py-2 text-right">{sum("outbound")}</td>
            <td className="px-4 py-2 text-right">{sum("closing")}</td></tr></tfoot>
        </table>
      </div>
      <p className="text-xs text-muted">{start} → {end} · Africa/Dar_es_Salaam · pcs</p>
    </div>
  );
}
