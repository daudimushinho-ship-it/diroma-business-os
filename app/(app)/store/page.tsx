import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { Tabs } from "@/components/Tabs";
import { LocationPicker } from "@/components/LocationPicker";
import { Overview } from "@/components/stock/Overview";
import { Receive } from "@/components/stock/Receive";
import { StockBySize } from "@/components/stock/StockBySize";
import { Requisitions } from "@/components/stock/Requisitions";
import { Incoming } from "@/components/stock/Incoming";
import { Discrepancies } from "@/components/stock/Discrepancies";
import { Counts } from "@/components/stock/Counts";
import { Movements } from "@/components/stock/Movements";
import { PeriodReport } from "@/components/stock/PeriodReport";
import { Opening } from "@/components/stock/Opening";
import { Inspection } from "@/components/stock/Inspection";
import { ConsignmentDispatch } from "@/components/stock/ConsignmentDispatch";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { can } from "@/lib/roles";
import { pickLocation } from "@/lib/stock";

type SP = { loc?: string; tab?: string; po?: string; design?: string; q?: string; from?: string; to?: string; ok?: string; err?: string };

export default async function StorePage({ searchParams }: { searchParams: Promise<SP> }) {
  const ws = await requireWorkspace("store.operate");
  const { s, x } = await getSalesDict();
  const sp = await searchParams;
  const warehouses = ws.locations.filter((l) => l.kind === "warehouse");
  const loc = pickLocation(ws.locations, ["warehouse"], sp.loc);
  if (!loc) {
    return (
      <div className="mx-auto max-w-3xl"><PageHeader title={s.store.title} />
        <p className="card p-6 text-sm text-muted">No Store/warehouse location is assigned to you. The Owner can add one in Settings and assign it in Team.</p></div>
    );
  }
  const tabs = [
    { key: "overview", label: s.store.overview }, { key: "receive", label: s.store.receive },
    { key: "stock", label: s.store.stock }, { key: "requisitions", label: s.store.requisitions },
    { key: "transit", label: s.store.transit }, { key: "discrepancies", label: s.store.discrepancies },
    { key: "counts", label: s.store.counts }, { key: "movements", label: s.store.movements },
    { key: "reports", label: s.store.reports },
    ...(can(ws, "inspection.release") ? [{ key: "inspection", label: x.inspection.title }] : []),
    { key: "consignment", label: x.wholesale.dispatch },
    ...(can(ws, "stock.opening") ? [{ key: "opening", label: s.store.opening }] : []),
  ];
  const tab = tabs.some((t) => t.key === sp.tab) ? sp.tab! : "overview";
  const back = `/store?loc=${loc.id}&tab=${tab}`;
  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader title={s.store.title} subtitle={loc.name}>
        <LocationPicker locations={warehouses} active={loc.id} base={`/store?tab=${tab}`} />
      </PageHeader>
      <Tabs active={tab} items={tabs.map((t) => ({ ...t, href: `/store?loc=${loc.id}&tab=${t.key}` }))} />
      <Flash ok={sp.ok} err={sp.err} />
      {tab === "overview" && <Overview locationId={loc.id} s={s} />}
      {tab === "receive" && <Receive locationId={loc.id} s={s} po={sp.po} design={sp.design} back={back} />}
      {tab === "stock" && <StockBySize locationId={loc.id} s={s} q={sp.q} />}
      {tab === "requisitions" && <Requisitions ws={ws} locationId={loc.id} side="from" s={s} back={back} />}
      {tab === "transit" && (
        <div className="space-y-6">
          <section><h2 className="mb-3 font-semibold">{s.shop.incoming}</h2><Incoming ws={ws} locationId={loc.id} s={s} back={back} /></section>
        </div>
      )}
      {tab === "discrepancies" && <Discrepancies ws={ws} s={s} back={back} />}
      {tab === "counts" && <Counts ws={ws} locationId={loc.id} s={s} back={back} />}
      {tab === "movements" && <Movements locationId={loc.id} s={s} tz={ws.business.timezone} />}
      {tab === "reports" && <PeriodReport locationId={loc.id} s={s} from={sp.from} to={sp.to} base="/store" />}
      {tab === "opening" && <Opening locationId={loc.id} s={s} design={sp.design} back={back} />}
      {tab === "inspection" && <Inspection x={x} back={back} />}
      {tab === "consignment" && <ConsignmentDispatch ws={ws} x={x} locationId={loc.id} back={back} />}
    </div>
  );
}
