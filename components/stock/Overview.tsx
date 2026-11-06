import { Stat } from "@/components/Stat";
import { db } from "@/lib/stock";
import type { StockDict } from "@/lib/i18n-stock";

export async function Overview({ locationId, s }: { locationId: string; s: StockDict }) {
  const supabase = await db();
  const { data, error } = await supabase.rpc("store_overview", { p_location: locationId });
  if (error || !data) return <p className="card p-6 text-sm text-bad">{error?.message}</p>;
  const o = data as Record<string, number> & { company: Record<string, number> };
  const pcs = (n: number) => `${n} pcs`;
  return (
    <div className="space-y-5">
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat label={s.store.onHand} value={pcs(o.on_hand)} />
        <Stat label={s.store.reserved} value={pcs(o.reserved)} />
        <Stat label={s.store.available} value={pcs(o.available)} />
        <Stat label={s.store.inTransitOut} value={pcs(o.in_transit_out)} />
      </div>
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
        <Stat label={s.store.pendingReq} value={String(o.pending_requisitions)} />
        <Stat label={s.store.incoming} value={String(o.incoming_unconfirmed)} />
        <Stat label={s.store.openDisc} value={String(o.open_discrepancies)} />
        <Stat label={s.store.openCounts} value={String(o.open_counts)} />
        <Stat label={s.store.pendingCosts} value={String(o.pending_cost_receipts)} />
      </div>
      <section className="card p-4">
        <h3 className="mb-3 font-semibold">{s.store.company}</h3>
        <dl className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
          <div><dt className="text-muted">{s.store.warehouse}</dt><dd className="text-lg font-semibold">{pcs(o.company.warehouse)}</dd></div>
          <div><dt className="text-muted">{s.store.shop}</dt><dd className="text-lg font-semibold">{pcs(o.company.shop)}</dd></div>
          <div><dt className="text-muted">{s.store.transitAll}</dt><dd className="text-lg font-semibold">{pcs(o.company.transit)}</dd></div>
          <div><dt className="text-muted">{s.store.inspection}</dt><dd className="text-lg font-semibold">{pcs(o.company.inspection_quarantine)}</dd></div>
        </dl>
      </section>
    </div>
  );
}
