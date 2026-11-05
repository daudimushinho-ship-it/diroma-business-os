import { VariantMatrix } from "@/components/VariantMatrix";
import { db, sortVariants } from "@/lib/stock";
import type { StockDict } from "@/lib/i18n-stock";

type Row = { variant_id: string; design_id: string; design_code: string; design_name: string; color: string; size: string; on_hand: number; reserved: number; available: number };

export async function StockBySize({ locationId, s, q }: { locationId: string; s: StockDict; q?: string }) {
  const supabase = await db();
  let query = supabase.from("v_stock").select("variant_id, design_id, design_code, design_name, color, size, on_hand, reserved, available")
    .eq("location_id", locationId).gt("on_hand", 0);
  if (q) query = query.or(`design_code.ilike.%${q.replace(/[%,()]/g, "")}%,design_name.ilike.%${q.replace(/[%,()]/g, "")}%`);
  const { data } = await query.limit(5000);
  const rows = (data ?? []) as Row[];
  const designs = new Map<string, { code: string; name: string; rows: Row[] }>();
  for (const r of rows) {
    const d = designs.get(r.design_id) ?? { code: r.design_code, name: r.design_name, rows: [] };
    d.rows.push(r); designs.set(r.design_id, d);
  }
  const total = rows.reduce((a, r) => a + r.on_hand, 0);
  return (
    <div className="space-y-4">
      <form className="flex flex-wrap items-center gap-3" role="search">
        <input type="hidden" name="loc" value={locationId} /><input type="hidden" name="tab" value="stock" />
        <input name="q" defaultValue={q} placeholder={s.search} className="input max-w-xs" />
        <p className="text-sm text-muted">{s.store.onHand}: <strong className="text-ink">{total} pcs</strong></p>
      </form>
      {designs.size === 0 && <p className="card p-6 text-sm text-muted">{s.noData}</p>}
      {[...designs.entries()].sort((a, b) => a[1].code.localeCompare(b[1].code)).map(([id, d]) => {
        const values: Record<string, string> = {};
        for (const r of d.rows) values[r.variant_id] = r.reserved ? `${r.on_hand} (${r.available})` : String(r.on_hand);
        return (
          <section key={id} className="card p-4">
            <h3 className="mb-2 text-sm"><span className="font-mono text-muted">{d.code}</span> · <strong>{d.name}</strong>
              <span className="ml-2 text-muted">{d.rows.reduce((a, r) => a + r.on_hand, 0)} pcs</span></h3>
            <VariantMatrix variants={sortVariants(d.rows.map((r) => ({ id: r.variant_id, color: r.color, size: r.size })))} values={values} />
          </section>
        );
      })}
      <p className="text-xs text-muted">n (m) = {s.store.onHand} ({s.store.available})</p>
    </div>
  );
}
