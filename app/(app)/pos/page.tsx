import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { getSalesDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { db } from "@/lib/stock";
import { moneyAccounts, myShift, posCatalogue } from "@/lib/sales";
import { openShift } from "@/app/actions/sales";
import { PosTerminal } from "./PosTerminal";

export default async function PosPage({ searchParams }: { searchParams: Promise<{ ok?: string; err?: string }> }) {
  const ws = await requireWorkspace("pos.sell");
  const { x } = await getSalesDict();
  const sp = await searchParams;
  const shift = await myShift();
  const accounts = await moneyAccounts();

  if (!shift) {
    const shops = ws.locations.filter((l) => l.kind === "shop");
    const drawers = accounts.filter((a) => a.kind === "cash" && shops.some((s) => s.id === a.location_id));
    return (
      <div className="mx-auto max-w-md">
        <PageHeader title={x.pos.openShift} subtitle={x.pos.openShiftIntro} />
        <Flash ok={sp.ok} err={sp.err} />
        {drawers.length === 0 ? <p className="card p-6 text-sm text-muted">{x.pos.noDrawer}</p> : (
          <form action={openShift} className="card space-y-4 p-5">
            <input type="hidden" name="back" value="/pos" />
            <label className="block"><span className="label">{x.pos.drawer}</span>
              <select name="drawer" className="input" required>
                {drawers.map((d) => <option key={d.id} value={d.id}>{d.name} · {shops.find((s) => s.id === d.location_id)?.name}</option>)}
              </select></label>
            <label className="block"><span className="label">{x.pos.float}</span><input name="float" inputMode="numeric" required className="input" placeholder="50000" /></label>
            <button className="btn btn-primary w-full">{x.pos.openShift}</button>
          </form>
        )}
      </div>
    );
  }

  const supabase = await db();
  const [items, { data: customers }] = await Promise.all([
    posCatalogue(shift.location_id),
    supabase.from("customers").select("id, name, phone_e164, kind").order("name").limit(2000),
  ]);
  const payAccounts = accounts.filter((a) => a.id === shift.cash_account_id || a.kind !== "cash");
  const shopName = ws.locations.find((l) => l.id === shift.location_id)?.name ?? "";
  return (
    <div className="mx-auto max-w-7xl">
      <PageHeader title={x.pos.title} subtitle={`${shopName} · ${shift.ref_no}`}>
        <Link href="/pos/shift" className="btn btn-ghost">{x.pos.myShift}</Link>
      </PageHeader>
      <PosTerminal x={x} items={items} customers={(customers ?? []) as never} accounts={payAccounts}
        shift={{ id: shift.id, location_id: shift.location_id, cash_account_id: shift.cash_account_id }} />
    </div>
  );
}
