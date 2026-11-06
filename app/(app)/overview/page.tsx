import { PageHeader } from "@/components/PageHeader";
import { CapabilityTable } from "@/components/CapabilityTable";
import { Stat } from "@/components/Stat";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { db } from "@/lib/stock";
import { businessToday, tzs } from "@/lib/format";

type Ov = Record<string, number> & { cash_by_kind: Record<string, number> };

export default async function OverviewPage() {
  const ws = await requireWorkspace("overview.business");
  const { lang, t, x } = await getSalesDict();
  const supabase = await db();
  const today = businessToday();
  const monthStart = today.slice(0, 8) + "01";
  const [{ data: d }, { data: m }] = await Promise.all([
    supabase.rpc("business_overview", { p_from: today, p_to: today }),
    supabase.rpc("business_overview", { p_from: monthStart, p_to: today }),
  ]);
  const day = d as Ov | null, month = m as Ov | null;
  const o = x.overview;
  const gp = (v: Ov | null) => (v ? v.net_sales - v.cogs : 0);
  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader title={t.nav.overview} subtitle={`${t.welcome}, ${ws.display_name}`} />
      {[{ label: o.today, v: day }, { label: o.month, v: month }].map(({ label, v }) => v && (
        <section key={label}>
          <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-muted">{label}</h2>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <Stat label={o.netSales} value={tzs(v.net_sales)} note={o.netSalesNote} />
            <Stat label={o.collections} value={tzs(v.collections)} note={`${o.collectionsNote}${v.collections_old_debt ? ` · ${o.oldDebt} ${tzs(v.collections_old_debt)}` : ""}`} />
            <Stat label={o.grossProfit} value={tzs(gp(v))} note={v.units_cost_unknown ? `⚠ ${v.units_cost_unknown} ${o.costIncomplete}` : undefined} />
            <Stat label={o.expenses} value={tzs(v.expenses)} />
          </div>
        </section>
      ))}
      {month && (
        <section>
          <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-muted">{o.cash} · {o.stock}</h2>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <Stat label={o.cash} value={tzs(Object.values(month.cash_by_kind ?? {}).reduce((a, b) => a + Number(b), 0))}
              note={Object.entries(month.cash_by_kind ?? {}).map(([k, val]) => `${x.money[k as "cash"]} ${tzs(Number(val))}`).join(" · ")} />
            <Stat label={o.receivables} value={tzs(month.receivables)} note={`${o.credits} ${tzs(month.customer_credits)} · ${o.inTransit} ${tzs(month.funds_in_transit)}`} />
            <Stat label={o.stock} value={`${month.saleable_units} pcs`} note={`${month.units_not_saleable} ${o.notSaleable}`} />
            <Stat label={o.stockValue} value={tzs(month.inventory_value_known)} note={month.units_without_cost ? `+ ${month.units_without_cost} pcs ${o.noCost}` : undefined} />
            <Stat label={o.approvals} value={String(month.pending_approvals)} />
            <Stat label={o.shifts} value={String(month.shifts_open)} />
            <Stat label={o.reviews} value={String(month.shifts_pending_review)} />
          </div>
        </section>
      )}
      <CapabilityTable t={t} lang={lang} />
    </div>
  );
}
