import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { Flash } from "@/components/Flash";
import { Tabs } from "@/components/Tabs";
import { VariantMatrix } from "@/components/VariantMatrix";
import { DesignPicker } from "@/components/stock/DesignPicker";
import { getStockDict } from "@/lib/lang";
import { requireWorkspace } from "@/lib/workspace";
import { can } from "@/lib/roles";
import { db, getDesign, locationDirectory } from "@/lib/stock";
import { createPo, saveSupplier } from "@/app/actions/stock";

type SP = { tab?: string; design?: string; ok?: string; err?: string };

export default async function PurchasingPage({ searchParams }: { searchParams: Promise<SP> }) {
  const ws = await requireWorkspace("purchasing.manage");
  const { s } = await getStockDict();
  const sp = await searchParams;
  const supabase = await db();
  const approver = can(ws, "costs.approve");
  const tabs = [
    { key: "pos", label: s.purchasing.pos }, { key: "new", label: s.purchasing.newPo },
    { key: "suppliers", label: s.purchasing.suppliers },
    ...(approver ? [{ key: "costs", label: s.purchasing.receipts }] : []),
  ];
  const tab = tabs.some((t) => t.key === sp.tab) ? sp.tab! : "pos";
  const back = `/purchasing?tab=${tab}`;
  const { data: suppliers } = await supabase.from("suppliers").select("id, name, phone, country").order("name");
  const supName = new Map((suppliers ?? []).map((x) => [x.id, x.name]));
  const d = tab === "new" && sp.design ? await getDesign(sp.design) : null;

  return (
    <div className="mx-auto max-w-6xl">
      <PageHeader title={s.purchasing.title} />
      <Tabs active={tab} items={tabs.map((t) => ({ ...t, href: `/purchasing?tab=${t.key}` }))} />
      <Flash ok={sp.ok} err={sp.err} />

      {tab === "pos" && <PoList />}

      {tab === "new" && (
        <section className="card space-y-3 p-4">
          <DesignPicker label={s.choose} keep={{ tab: "new" }} selected={sp.design} />
          {d?.design && (
            <form action={createPo} className="space-y-3">
              <input type="hidden" name="idem" value={crypto.randomUUID()} /><input type="hidden" name="back" value="/purchasing?tab=pos" />
              <VariantMatrix variants={d.variants} inputPrefix="q_" />
              <div className="grid gap-3 sm:grid-cols-3">
                <label><span className="label">{s.supplier}</span>
                  <select name="supplier" required className="input" defaultValue={d.design.supplier_id ?? ""}>
                    <option value="" disabled>—</option>{(suppliers ?? []).map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
                  </select></label>
                <label><span className="label">{s.purchasing.currency}</span>
                  <select name="currency" className="input"><option>TZS</option><option>USD</option><option>CNY</option></select></label>
                <label><span className="label">{s.purchasing.fx}</span><input name="fx" inputMode="decimal" defaultValue="1" className="input" /></label>
                <label><span className="label">{s.purchasing.unitPrice}</span><input name="unit_price" inputMode="decimal" className="input" /></label>
                <label><span className="label">{s.purchasing.expectedAt}</span><input type="date" name="expected" className="input" /></label>
                <label><span className="label">{s.notes}</span><input name="notes" className="input" /></label>
              </div>
              <button className="btn btn-primary">{s.purchasing.createPo}</button>
            </form>
          )}
        </section>
      )}

      {tab === "suppliers" && (
        <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
          <ul className="card divide-y divide-line">
            {(suppliers ?? []).length === 0 && <li className="p-5 text-sm text-muted">{s.noData}</li>}
            {(suppliers ?? []).map((x) => <li key={x.id} className="px-5 py-3 text-sm"><strong>{x.name}</strong> <span className="text-muted">{[x.country, x.phone].filter(Boolean).join(" · ")}</span></li>)}
          </ul>
          <form action={saveSupplier} className="card h-fit space-y-3 p-4">
            <input type="hidden" name="back" value={back} />
            <h2 className="font-semibold">{s.purchasing.newSupplier}</h2>
            <label className="block"><span className="label">{s.name}</span><input name="name" required className="input" /></label>
            <label className="block"><span className="label">{s.purchasing.phone}</span><input name="phone" className="input" /></label>
            <label className="block"><span className="label">{s.purchasing.country}</span><input name="country" className="input" /></label>
            <label className="block"><span className="label">{s.notes}</span><input name="notes" className="input" /></label>
            <button className="btn btn-primary w-full">{s.save}</button>
          </form>
        </div>
      )}

      {tab === "costs" && approver && <PendingCosts />}
    </div>
  );

  async function PoList() {
    const { data: pos } = await supabase.from("purchase_orders").select("id, ref_no, supplier_id, status, currency, expected_at, created_at").order("created_at", { ascending: false }).limit(100);
    if (!pos?.length) return <p className="card p-6 text-sm text-muted">{s.noData}</p>;
    return (
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-ivory text-left text-muted"><tr><th className="px-4 py-2 font-medium">Ref</th><th className="px-4 py-2 font-medium">{s.supplier}</th>
            <th className="px-4 py-2 font-medium">{s.store.status}</th><th className="px-4 py-2 font-medium">{s.purchasing.currency}</th><th className="px-4 py-2 font-medium">{s.purchasing.expectedAt}</th></tr></thead>
          <tbody className="divide-y divide-line">
            {pos.map((p) => <tr key={p.id}><td className="px-4 py-2 font-mono">{p.ref_no}</td><td className="px-4 py-2">{supName.get(p.supplier_id)}</td>
              <td className="px-4 py-2"><span className="badge border border-line bg-ivory">{p.status}</span></td><td className="px-4 py-2">{p.currency}</td><td className="px-4 py-2">{p.expected_at ?? "—"}</td></tr>)}
          </tbody>
        </table>
      </div>
    );
  }

  async function PendingCosts() {
    const { data: grs } = await supabase.from("goods_receipts").select("id, ref_no, location_id, supplier_id, supplier_ref, received_at")
      .eq("cost_status", "pending").order("received_at");
    const dir = await locationDirectory();
    if (!grs?.length) return <p className="card p-6 text-sm text-muted">{s.noData}</p>;
    return (
      <ul className="card divide-y divide-line">
        {grs.map((g) => (
          <li key={g.id}><Link href={`/purchasing/receipts/${g.id}`} className="flex flex-wrap justify-between gap-2 px-5 py-3 text-sm hover:bg-ivory">
            <span><strong className="font-mono">{g.ref_no}</strong> · {dir.get(g.location_id)?.name} · {g.supplier_id ? supName.get(g.supplier_id) : "—"} {g.supplier_ref && `· ${g.supplier_ref}`}</span>
            <span className="text-gold-ink">{s.purchasing.approveCosts} →</span></Link></li>
        ))}
      </ul>
    );
  }
}
