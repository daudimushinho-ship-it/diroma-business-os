import { db, variantLabels, variantText } from "@/lib/stock";
import type { StockDict } from "@/lib/i18n-stock";

export async function Movements({ locationId, s, tz }: { locationId: string; s: StockDict; tz: string }) {
  const supabase = await db();
  const { data } = await supabase.from("stock_movements").select("id, variant_id, qty_delta, created_at, stock_documents(ref_no, doc_type)")
    .eq("location_id", locationId).order("id", { ascending: false }).limit(200);
  type R = { id: number; variant_id: string; qty_delta: number; created_at: string; stock_documents: { ref_no: string; doc_type: string } };
  const rows = (data ?? []) as unknown as R[];
  const labels = await variantLabels(rows.map((r) => r.variant_id));
  if (!rows.length) return <p className="card p-6 text-sm text-muted">{s.noData}</p>;
  const fmt = new Intl.DateTimeFormat("en-GB", { dateStyle: "short", timeStyle: "short", timeZone: tz });
  return (
    <div className="card overflow-x-auto">
      <table className="w-full min-w-[640px] text-sm">
        <thead className="bg-ivory text-left text-muted"><tr>
          <th className="px-4 py-2 font-medium">{s.store.when}</th><th className="px-4 py-2 font-medium">{s.store.doc}</th>
          <th className="px-4 py-2 font-medium">{s.variants}</th><th className="px-4 py-2 text-right font-medium">{s.store.change}</th></tr></thead>
        <tbody className="divide-y divide-line">
          {rows.map((r) => (
            <tr key={r.id}>
              <td className="whitespace-nowrap px-4 py-2">{fmt.format(new Date(r.created_at))}</td>
              <td className="px-4 py-2"><span className="font-mono text-xs">{r.stock_documents.ref_no}</span> <span className="text-xs text-muted">{r.stock_documents.doc_type}</span></td>
              <td className="px-4 py-2">{variantText(labels.get(r.variant_id))}</td>
              <td className={`px-4 py-2 text-right font-semibold tabular-nums ${r.qty_delta < 0 ? "text-bad" : "text-ok"}`}>{r.qty_delta > 0 ? "+" : ""}{r.qty_delta}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
