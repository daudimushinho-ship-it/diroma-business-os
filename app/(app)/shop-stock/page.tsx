import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { Tabs } from "@/components/Tabs";
import { LocationPicker } from "@/components/LocationPicker";
import { VariantMatrix } from "@/components/VariantMatrix";
import { StockBySize } from "@/components/stock/StockBySize";
import { Incoming } from "@/components/stock/Incoming";
import { Requisitions } from "@/components/stock/Requisitions";
import { Counts } from "@/components/stock/Counts";
import { Movements } from "@/components/stock/Movements";
import { PeriodReport } from "@/components/stock/PeriodReport";
import { Opening } from "@/components/stock/Opening";
import { DesignPicker } from "@/components/stock/DesignPicker";
import { getStockDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { can } from "@/lib/roles";
import { getDesign, locationDirectory, pickLocation } from "@/lib/stock";
import { createRequisition } from "@/app/actions/stock";

type SP = { loc?: string; tab?: string; design?: string; q?: string; from?: string; to?: string; ok?: string; err?: string };

export default async function ShopStockPage({ searchParams }: { searchParams: Promise<SP> }) {
  const ws = await requireWorkspace("shop_stock.view");
  const { s } = await getStockDict();
  const sp = await searchParams;
  const shops = ws.locations.filter((l) => l.kind === "shop");
  const loc = pickLocation(ws.locations, ["shop"], sp.loc);
  if (!loc) return <div className="mx-auto max-w-3xl"><PageHeader title={s.shop.title} /><p className="card p-6 text-sm text-muted">No shop location is assigned to you.</p></div>;
  const tabs = [
    { key: "stock", label: s.store.stock }, { key: "incoming", label: s.shop.incoming },
    ...(can(ws, "stock.request") ? [{ key: "request", label: s.store.newRequest }, { key: "mine", label: s.shop.myRequests }] : []),
    ...(can(ws, "store.operate") ? [{ key: "counts", label: s.store.counts }] : []),
    { key: "movements", label: s.store.movements }, { key: "reports", label: s.store.reports },
    ...(can(ws, "stock.opening") ? [{ key: "opening", label: s.store.opening }] : []),
  ];
  const tab = tabs.some((t) => t.key === sp.tab) ? sp.tab! : "stock";
  const back = `/shop-stock?loc=${loc.id}&tab=${tab}`;
  const dir = await locationDirectory();
  const sources = [...dir.values()].filter((l) => l.kind === "warehouse" || (l.kind === "shop" && l.id !== loc.id));
  const d = tab === "request" && sp.design ? await getDesign(sp.design) : null;
  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader title={s.shop.title} subtitle={loc.name}>
        <LocationPicker locations={shops} active={loc.id} base={`/shop-stock?tab=${tab}`} />
      </PageHeader>
      <Tabs active={tab} items={tabs.map((t) => ({ ...t, href: `/shop-stock?loc=${loc.id}&tab=${t.key}` }))} />
      <Flash ok={sp.ok} err={sp.err} />
      {tab === "stock" && <StockBySize locationId={loc.id} s={s} q={sp.q} />}
      {tab === "incoming" && <Incoming ws={ws} locationId={loc.id} s={s} back={back} />}
      {tab === "request" && (
        <section className="card space-y-3 p-4">
          <DesignPicker label={s.choose} keep={{ loc: loc.id, tab: "request" }} selected={sp.design} />
          {d?.design && (
            <form action={createRequisition} className="space-y-3">
              <input type="hidden" name="idem" value={crypto.randomUUID()} /><input type="hidden" name="to" value={loc.id} />
              <input type="hidden" name="back" value={`/shop-stock?loc=${loc.id}&tab=mine`} />
              <VariantMatrix variants={d.variants} inputPrefix="q_" />
              <div className="flex flex-wrap items-end gap-2">
                <label><span className="label">{s.store.fromLoc}</span>
                  <select name="from" className="input">{sources.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select></label>
                <label className="min-w-48 flex-1"><span className="label">{s.notes}</span><input name="notes" className="input" /></label>
                <button className="btn btn-primary">{s.store.requestStock}</button>
              </div>
            </form>
          )}
        </section>
      )}
      {tab === "mine" && <Requisitions ws={ws} locationId={loc.id} side="to" s={s} back={back} />}
      {tab === "counts" && <Counts ws={ws} locationId={loc.id} s={s} back={back} />}
      {tab === "movements" && <Movements locationId={loc.id} s={s} tz={ws.business.timezone} />}
      {tab === "reports" && <PeriodReport locationId={loc.id} s={s} from={sp.from} to={sp.to} base="/store" />}
      {tab === "opening" && <Opening locationId={loc.id} s={s} design={sp.design} back={back} tab="opening" />}
    </div>
  );
}
